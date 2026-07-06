"""Raster → Web Mercator XYZ PNG tiles.

Takes one radar sub-image (any source CRS), reprojects the mm/h array to
EPSG:3857 pinned to a fixed bounding box, and cuts 256-px PNG tiles per zoom.
Pure functions of their inputs — no globals, no I/O beyond the tile PNGs.
"""

from __future__ import annotations

import math
from pathlib import Path

import numpy as np
from affine import Affine
from PIL import Image
from rasterio.crs import CRS
from rasterio.warp import Resampling, calculate_default_transform, reproject

from openweer.tiler.radar_hdf5 import RadarSubImage

TILE_SIZE: int = 256
WEB_MERCATOR = CRS.from_epsg(3857)


def reproject_to_3857(
    sub: RadarSubImage,
    bbox_ll: tuple[float, float, float, float],
) -> tuple[np.ndarray, Affine, tuple[float, float, float, float]]:
    from rasterio.warp import transform_bounds

    src_h, src_w = sub.mm_per_h.shape
    dst_bounds_3857 = transform_bounds("EPSG:4326", WEB_MERCATOR, *bbox_ll)
    _, dst_w, dst_h = calculate_default_transform(
        sub.crs,
        WEB_MERCATOR,
        src_w,
        src_h,
        *_src_bounds_from(sub.transform, src_w, src_h),
        dst_width=int((dst_bounds_3857[2] - dst_bounds_3857[0]) / 125),
        dst_height=int((dst_bounds_3857[3] - dst_bounds_3857[1]) / 125),
    )
    # We pin the destination grid to NL bbox so every frame shares an exact extent.
    px_x = (dst_bounds_3857[2] - dst_bounds_3857[0]) / dst_w
    px_y = (dst_bounds_3857[3] - dst_bounds_3857[1]) / dst_h
    pinned_transform = Affine(px_x, 0, dst_bounds_3857[0], 0, -px_y, dst_bounds_3857[3])

    dst = np.full((dst_h, dst_w), np.nan, dtype=np.float32)
    reproject(
        source=sub.mm_per_h,
        destination=dst,
        src_transform=sub.transform,
        src_crs=sub.crs,
        dst_transform=pinned_transform,
        dst_crs=WEB_MERCATOR,
        resampling=Resampling.bilinear,
        src_nodata=np.nan,
        dst_nodata=np.nan,
    )
    return dst, pinned_transform, dst_bounds_3857


def _src_bounds_from(transform: Affine, w: int, h: int) -> tuple[float, float, float, float]:
    """Source bbox (left, bottom, right, top) in source CRS units."""
    left, top = transform * (0, 0)
    right, bottom = transform * (w, h)
    return (left, bottom, right, top)


def write_zoom(
    rgba: np.ndarray,
    transform: Affine,
    dst_bounds_3857: tuple[float, float, float, float],
    zoom: int,
    staging_root: Path,
    bbox_ll: tuple[float, float, float, float],
) -> int:
    """Write 256-px PNG tiles for `zoom` covering `bbox_ll`."""
    x_min_t, y_max_t = _lonlat_to_tile(bbox_ll[0], bbox_ll[3], zoom)
    x_max_t, y_min_t = _lonlat_to_tile(bbox_ll[2], bbox_ll[1], zoom)
    written = 0
    for x in range(x_min_t, x_max_t + 1):
        for y in range(y_max_t, y_min_t + 1):
            tile = _read_tile(rgba, transform, dst_bounds_3857, zoom, x, y)
            if tile is None:
                continue
            tile_dir = staging_root / str(zoom) / str(x)
            tile_dir.mkdir(parents=True, exist_ok=True)
            path = tile_dir / f"{y}.png"
            Image.fromarray(tile, mode="RGBA").save(path, "PNG", optimize=True)
            written += 1
    return written


def _read_tile(
    rgba: np.ndarray,
    transform: Affine,
    dst_bounds_3857: tuple[float, float, float, float],
    z: int,
    x: int,
    y: int,
) -> np.ndarray | None:
    """Vectorised bilinear resample from `rgba` (in 3857) into a 256-px tile."""
    tile_bounds = _tile_bounds_3857(z, x, y)
    src_left, src_bottom, src_right, src_top = dst_bounds_3857
    # Tile entirely outside source raster → nothing to do.
    if (
        tile_bounds[2] < src_left
        or tile_bounds[0] > src_right
        or tile_bounds[1] > src_top
        or tile_bounds[3] < src_bottom
    ):
        return None

    src_h, src_w = rgba.shape[:2]
    pixel_w = (tile_bounds[2] - tile_bounds[0]) / TILE_SIZE
    pixel_h = (tile_bounds[3] - tile_bounds[1]) / TILE_SIZE
    inv_src_x = 1.0 / transform.a
    inv_src_y = 1.0 / -transform.e

    # 256-element coordinate vectors in projected space (centres of each output px).
    xs = tile_bounds[0] + (np.arange(TILE_SIZE, dtype=np.float64) + 0.5) * pixel_w
    ys = tile_bounds[3] - (np.arange(TILE_SIZE, dtype=np.float64) + 0.5) * pixel_h

    # Continuous source-pixel coordinates (top-left convention: shift by -0.5 from centres).
    src_cols_f = (xs - src_left) * inv_src_x - 0.5
    src_rows_f = (src_top - ys) * inv_src_y - 0.5

    c0 = np.floor(src_cols_f).astype(np.int32)
    r0 = np.floor(src_rows_f).astype(np.int32)
    c1 = c0 + 1
    r1 = r0 + 1
    fx = (src_cols_f - c0).astype(np.float32)
    fy = (src_rows_f - r0).astype(np.float32)

    col_mask = (c1 >= 0) & (c0 < src_w)
    row_mask = (r1 >= 0) & (r0 < src_h)
    if not col_mask.any() or not row_mask.any():
        return None

    c0c = np.clip(c0, 0, src_w - 1)
    c1c = np.clip(c1, 0, src_w - 1)
    r0c = np.clip(r0, 0, src_h - 1)
    r1c = np.clip(r1, 0, src_h - 1)

    # Four pre-coloured RGBA corner samples. Naïvely bilinear-blending all four
    # channels mixes adjacent palette colours — e.g. dark-blue (31,93,208) next
    # to yellow (245,213,45) averages to olive (138,153,126), painting green on
    # rain-band boundaries that have no green in the palette. So we keep alpha
    # bilinear (rain edges still feather instead of cliff-edging) but pick the
    # nearest corner's RGB so bands stay crisp palette colours.
    tl = rgba[np.ix_(r0c, c0c)]
    tr = rgba[np.ix_(r0c, c1c)]
    bl = rgba[np.ix_(r1c, c0c)]
    br = rgba[np.ix_(r1c, c1c)]

    # Nearest-corner RGB. Vectorised via per-axis "is left half / top half" masks.
    use_left = (fx < 0.5)[None, :, None]
    use_top = (fy < 0.5)[:, None, None]
    top_row_rgb = np.where(use_left, tl[..., :3], tr[..., :3])
    bot_row_rgb = np.where(use_left, bl[..., :3], br[..., :3])
    rgb = np.where(use_top, top_row_rgb, bot_row_rgb)

    # Bilinear alpha so the rain edge still feathers smoothly.
    wx = fx[None, :]
    wy = fy[:, None]
    a_top = tl[..., 3].astype(np.float32) * (1 - wx) + tr[..., 3].astype(np.float32) * wx
    a_bot = bl[..., 3].astype(np.float32) * (1 - wx) + br[..., 3].astype(np.float32) * wx
    a = a_top * (1 - wy) + a_bot * wy

    tile = np.empty((TILE_SIZE, TILE_SIZE, 4), dtype=np.uint8)
    tile[..., :3] = rgb
    tile[..., 3] = (a + 0.5).astype(np.uint8)

    full_mask = row_mask[:, None] & col_mask[None, :]
    tile[~full_mask] = 0

    if not tile[..., 3].any():
        return None
    return tile


# Tile math (Web Mercator XYZ) — small, dependency-free helpers.


def _lonlat_to_tile(lon: float, lat: float, z: int) -> tuple[int, int]:
    n = 2**z
    x = int((lon + 180.0) / 360.0 * n)
    lat_rad = math.radians(max(min(lat, 85.05112878), -85.05112878))
    y = int((1.0 - math.asinh(math.tan(lat_rad)) / math.pi) / 2.0 * n)
    return x, y


def _tile_bounds_3857(z: int, x: int, y: int) -> tuple[float, float, float, float]:
    n = 2**z
    extent = 20037508.342789244
    pixel = 2 * extent / n
    left = -extent + x * pixel
    right = left + pixel
    top = extent - y * pixel
    bottom = top - pixel
    return (left, bottom, right, top)


__all__ = ["TILE_SIZE", "WEB_MERCATOR", "reproject_to_3857", "write_zoom"]
