"""Reproject KNMI radar HDF5 sub-images to EPSG:3857 PNG XYZ tiles.

Per sub-image:
1. Reproject the `mm/h` array from KNMI stereographic to Web Mercator (EPSG:3857)
   over the Netherlands bounding box.
2. Apply the rain colormap (RGBA uint8).
3. Write 256x256 PNG tiles for zoom levels 6..10 inside `data/tiles_staging/<frame_id>/`.
4. Atomic-rename staging dir into `data/tiles/<frame_id>/`.
5. Update `data/manifests/frames.json`.

This keeps tile generation a pure function of the HDF5 file path; no globals,
no shared state — perfect for concurrent execution and unit testing.
"""

from __future__ import annotations

import math
import os
import shutil
import tempfile
from collections.abc import Iterable, Iterator
from dataclasses import dataclass, field
from datetime import datetime
from pathlib import Path

import numpy as np
from PIL import Image
from rasterio.crs import CRS
from rasterio.warp import Resampling, calculate_default_transform, reproject

from openweer._logging import get_logger
from openweer.tiler.colormap import apply_rain_colormap
from openweer.tiler.manifest import Frame, FrameKind, ManifestStore
from openweer.tiler.radar_hdf5 import RadarSubImage, read_radar_hdf5

log = get_logger(__name__)

# NL bounding box (lon_min, lat_min, lon_max, lat_max).
NL_BBOX_LL: tuple[float, float, float, float] = (3.0, 50.6, 7.4, 53.7)
DEFAULT_ZOOMS: tuple[int, ...] = (6, 7, 8, 9, 10)
TILE_SIZE: int = 256
WEB_MERCATOR = CRS.from_epsg(3857)


@dataclass(slots=True)
class FramePlan:
    """Pre-computed metadata for one frame about to be written."""

    sub_image: RadarSubImage
    frame_id: str
    kind: FrameKind
    cadence_minutes: int


@dataclass(slots=True)
class RadarTilePipeline:
    """Render KNMI radar HDF5 files to XYZ PNG tiles + update the frames manifest."""

    tiles_dir: Path
    staging_dir: Path
    manifest: ManifestStore
    nowcast_window_minutes: int = 120
    zoom_levels: tuple[int, ...] = DEFAULT_ZOOMS
    bbox: tuple[float, float, float, float] = NL_BBOX_LL
    cadence_minutes: int = 5
    written_frames: list[Frame] = field(default_factory=list)

    def __post_init__(self) -> None:
        # Resolve to absolute paths so atomic-rename never depends on cwd.
        self.tiles_dir = self.tiles_dir.resolve()
        self.staging_dir = self.staging_dir.resolve()

    def render_file(self, hdf5_path: Path) -> list[Frame]:
        sub_images = read_radar_hdf5(hdf5_path)
        if not sub_images:
            log.warning("tiler.no_sub_images", path=str(hdf5_path))
            return []

        analysis_ts = sub_images[0].valid_at
        plans = list(self._plan_frames(sub_images, analysis_ts))
        new_frames: list[Frame] = []
        for plan in plans:
            try:
                frame = self._render_one(plan)
            except Exception:
                log.exception("tiler.render_failed", frame_id=plan.frame_id)
                continue
            new_frames.append(frame)
        if new_frames:
            self.manifest.upsert(new_frames)
        log.info(
            "tiler.file_done",
            path=str(hdf5_path),
            frames=len(new_frames),
            analysis_ts=analysis_ts.isoformat(),
        )
        return new_frames

    # ---- planning ----

    def _plan_frames(
        self, sub_images: Iterable[RadarSubImage], analysis_ts: datetime
    ) -> Iterator[FramePlan]:
        for sub in sub_images:
            offset = (sub.valid_at - analysis_ts).total_seconds() / 60.0
            kind: FrameKind
            if offset <= 0:
                kind = "observed"
            elif offset <= self.nowcast_window_minutes:
                kind = "nowcast"
            else:
                kind = "hourly"
            frame_id = sub.valid_at.strftime("%Y%m%dT%H%M") + "Z"
            yield FramePlan(
                sub_image=sub,
                frame_id=frame_id,
                kind=kind,
                cadence_minutes=self.cadence_minutes,
            )

    # ---- one frame ----

    def _render_one(self, plan: FramePlan) -> Frame:
        sub = plan.sub_image
        self.staging_dir.mkdir(parents=True, exist_ok=True)
        self.tiles_dir.mkdir(parents=True, exist_ok=True)
        with tempfile.TemporaryDirectory(
            dir=self.staging_dir, prefix=f"{plan.frame_id}-"
        ) as work_dir:
            warped, dst_transform, dst_bounds = _reproject_to_3857(sub, self.bbox)
            rgba = apply_rain_colormap(warped)
            staging_root = Path(work_dir) / plan.frame_id
            staging_root.mkdir(parents=True, exist_ok=True)
            for z in self.zoom_levels:
                _write_zoom(rgba, dst_transform, dst_bounds, z, staging_root, self.bbox)
            target = self.tiles_dir / plan.frame_id
            if target.exists():
                shutil.rmtree(target)
            os.replace(staging_root, target)
        return Frame(
            id=plan.frame_id,
            ts=sub.valid_at,
            kind=plan.kind,
            cadence_minutes=plan.cadence_minutes,
            max_zoom=max(self.zoom_levels),
        )


# ---- reprojection + tiling helpers ----


def _reproject_to_3857(
    sub: RadarSubImage,
    bbox_ll: tuple[float, float, float, float],
) -> tuple[np.ndarray, "Affine", tuple[float, float, float, float]]:  # type: ignore[name-defined]  # noqa
    from rasterio.warp import transform_bounds

    src_h, src_w = sub.mm_per_h.shape
    dst_bounds_3857 = transform_bounds("EPSG:4326", WEB_MERCATOR, *bbox_ll)
    _, dst_w, dst_h = calculate_default_transform(
        sub.crs,
        WEB_MERCATOR,
        src_w,
        src_h,
        *_src_bounds_from(sub.transform, src_w, src_h),
        dst_width=int((dst_bounds_3857[2] - dst_bounds_3857[0]) / 250),
        dst_height=int((dst_bounds_3857[3] - dst_bounds_3857[1]) / 250),
    )
    # We pin the destination grid to NL bbox so every frame shares an exact extent.
    px_x = (dst_bounds_3857[2] - dst_bounds_3857[0]) / dst_w
    px_y = (dst_bounds_3857[3] - dst_bounds_3857[1]) / dst_h
    from affine import Affine as _Aff

    pinned_transform = _Aff(px_x, 0, dst_bounds_3857[0], 0, -px_y, dst_bounds_3857[3])

    dst = np.full((dst_h, dst_w), np.nan, dtype=np.float32)
    reproject(
        source=sub.mm_per_h,
        destination=dst,
        src_transform=sub.transform,
        src_crs=sub.crs,
        dst_transform=pinned_transform,
        dst_crs=WEB_MERCATOR,
        resampling=Resampling.nearest,
        src_nodata=np.nan,
        dst_nodata=np.nan,
    )
    return dst, pinned_transform, dst_bounds_3857


def _src_bounds_from(transform, w: int, h: int) -> tuple[float, float, float, float]:
    """Source bbox (left, bottom, right, top) in source CRS units."""
    left, top = transform * (0, 0)
    right, bottom = transform * (w, h)
    return (left, bottom, right, top)


def _write_zoom(
    rgba: np.ndarray,
    transform,
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
    transform,
    dst_bounds_3857: tuple[float, float, float, float],
    z: int,
    x: int,
    y: int,
) -> np.ndarray | None:
    """Vectorised nearest-neighbour resample from `rgba` (in 3857) into a 256-px tile."""
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

    # Fractional source-pixel indices for every output column / row.
    src_cols = ((xs - src_left) * inv_src_x).astype(np.int32)
    src_rows = ((src_top - ys) * inv_src_y).astype(np.int32)

    col_mask = (src_cols >= 0) & (src_cols < src_w)
    row_mask = (src_rows >= 0) & (src_rows < src_h)
    if not col_mask.any() or not row_mask.any():
        return None

    # Clamp to a valid range so fancy-indexing won't out-of-bounds; we'll mask alpha after.
    safe_cols = np.clip(src_cols, 0, src_w - 1)
    safe_rows = np.clip(src_rows, 0, src_h - 1)

    tile = rgba[np.ix_(safe_rows, safe_cols)].copy()  # shape (256, 256, 4)
    # Zero-out pixels that fell outside the source extent.
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


# ---- thin top-level helpers ----


def render_radar_file(
    hdf5_path: Path,
    *,
    tiles_dir: Path,
    staging_dir: Path,
    manifest_path: Path,
    zoom_levels: tuple[int, ...] = DEFAULT_ZOOMS,
) -> list[Frame]:
    tiles_dir.mkdir(parents=True, exist_ok=True)
    staging_dir.mkdir(parents=True, exist_ok=True)
    pipeline = RadarTilePipeline(
        tiles_dir=tiles_dir,
        staging_dir=staging_dir,
        manifest=ManifestStore(manifest_path),
        zoom_levels=zoom_levels,
    )
    return pipeline.render_file(hdf5_path)


__all__ = ["DEFAULT_ZOOMS", "NL_BBOX_LL", "RadarTilePipeline", "render_radar_file"]
