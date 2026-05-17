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
from openweer.tiler.harmonie_grib import read_harmonie_tar
from openweer.tiler.manifest import Frame, FrameKind, ManifestStore
from openweer.tiler.radar_hdf5 import RadarSubImage, read_radar_hdf5

log = get_logger(__name__)

# NL bounding box (lon_min, lat_min, lon_max, lat_max).
NL_BBOX_LL: tuple[float, float, float, float] = (3.0, 50.6, 7.4, 53.7)
DEFAULT_ZOOMS: tuple[int, ...] = (6, 7, 8, 9, 10)
TILE_SIZE: int = 256
WEB_MERCATOR = CRS.from_epsg(3857)

# Forecast hours of KNMI HARMONIE total precipitation to read from the tarball.
# We always read a range wider than strictly needed because HARMONIE model runs
# every 3 h: depending on how stale the latest run is vs the latest radar, the
# "useful" forecast hours that land *after* the nowcast horizon move around.
# Manifest dedup in `_plan_harmonie_tar` discards any HARMONIE frame whose
# valid_at is already covered by an observed/nowcast entry, so emitting a
# slightly-too-wide range is cheap and self-correcting.
HARMONIE_FORECAST_HOURS: tuple[int, ...] = tuple(range(3, 25))
# HARMONIE-AROME's KNMI Open Data feed (`harmonie_arome_cy43_p1` v1.0) only
# resolves hourly precipitation totals; no sub-hourly precipitation product is
# published. We therefore emit one slider frame per forecast hour. The iOS map
# layer uses MapLibre opacity transitions to cross-fade between consecutive
# hourly frames during playback, so the seam past +2h reads as a smooth slow-
# down rather than a jump.
HARMONIE_CADENCE_MINUTES: int = 60
_HDF5_SUFFIXES: frozenset[str] = frozenset({".h5", ".hdf5"})
_HARMONIE_TAR_SUFFIXES: frozenset[str] = frozenset({".tar"})


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

    def render_file(self, source_path: Path) -> list[Frame]:
        suffix = source_path.suffix.lower()
        if suffix in _HDF5_SUFFIXES:
            plans = self._plan_radar_hdf5(source_path)
        elif suffix in _HARMONIE_TAR_SUFFIXES:
            plans = self._plan_harmonie_tar(source_path)
        else:
            log.warning("tiler.unknown_format", path=str(source_path), suffix=suffix)
            return []

        if not plans:
            log.warning("tiler.no_sub_images", path=str(source_path))
            return []

        new_frames: list[Frame] = []
        pending: list[Frame] = []
        for plan in plans:
            try:
                frame = self._render_one(plan)
            except Exception:
                log.exception("tiler.render_failed", frame_id=plan.frame_id)
                continue
            new_frames.append(frame)
            pending.append(frame)
            # Upsert in small batches so the frontend sees new frames trickle
            # in during long HARMONIE renders rather than waiting minutes for
            # the whole run to finish.
            if len(pending) >= 6:
                self.manifest.upsert(pending)
                pending.clear()
        if pending:
            self.manifest.upsert(pending)
        log.info(
            "tiler.file_done",
            path=str(source_path),
            frames=len(new_frames),
        )
        return new_frames

    # ---- planning ----

    def _plan_radar_hdf5(self, path: Path) -> list[FramePlan]:
        sub_images = read_radar_hdf5(path)
        if not sub_images:
            return []
        analysis_ts = sub_images[0].valid_at
        return list(self._plan_frames(sub_images, analysis_ts))

    def _plan_harmonie_tar(self, path: Path) -> list[FramePlan]:
        sub_images = read_harmonie_tar(path, forecast_hours=HARMONIE_FORECAST_HOURS)
        # Skip any HARMONIE frame whose timestamp is already covered by a
        # higher-fidelity observed or nowcast frame. The radar nowcast is the
        # ground truth out to +2 h; HARMONIE is only useful past that horizon.
        existing_radar_ids = {
            f.id for f in self.manifest.read().frames if f.kind in ("observed", "nowcast")
        }
        plans: list[FramePlan] = []
        for sub in sub_images:
            frame_id = sub.valid_at.strftime("%Y%m%dT%H%M") + "Z"
            if frame_id in existing_radar_ids:
                continue
            plans.append(
                FramePlan(
                    sub_image=sub,
                    frame_id=frame_id,
                    kind="hourly",
                    cadence_minutes=HARMONIE_CADENCE_MINUTES,
                )
            )
        return plans

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
        self._render_tiles(plan)
        return Frame(
            id=plan.frame_id,
            ts=sub.valid_at,
            kind=plan.kind,
            cadence_minutes=plan.cadence_minutes,
            max_zoom=max(self.zoom_levels),
        )

    def _render_tiles(self, plan: FramePlan) -> None:
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
            if target.exists() or target.is_symlink():
                if target.is_symlink() or target.is_file():
                    target.unlink()
                else:
                    shutil.rmtree(target)
            os.replace(staging_root, target)


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
        dst_width=int((dst_bounds_3857[2] - dst_bounds_3857[0]) / 125),
        dst_height=int((dst_bounds_3857[3] - dst_bounds_3857[1]) / 125),
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
        resampling=Resampling.bilinear,
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
