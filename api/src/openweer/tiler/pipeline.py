"""Reproject KNMI radar HDF5 sub-images to EPSG:3857 PNG XYZ tiles.

Per sub-image:
1. Reproject the `mm/h` array from KNMI stereographic to Web Mercator (EPSG:3857)
   over the Netherlands bounding box (see `tiler/tiling.py`).
2. Apply the rain colormap (RGBA uint8).
3. Write 256x256 PNG tiles for zoom levels 6..10 inside `data/tiles_staging/<frame_id>/`.
4. Atomic-rename staging dir into `data/tiles/<frame_id>/`.
5. Update `data/manifests/frames.json`.

This keeps tile generation a pure function of the HDF5 file path; no globals,
no shared state — perfect for concurrent execution and unit testing.
"""

from __future__ import annotations

import os
import shutil
import tempfile
from collections.abc import Iterable, Iterator
from dataclasses import dataclass, field
from datetime import datetime
from pathlib import Path

from openweer._logging import get_logger
from openweer.tiler.colormap import apply_rain_colormap
from openweer.tiler.harmonie_grib import read_harmonie_tar
from openweer.tiler.manifest import Frame, FrameKind, ManifestStore
from openweer.tiler.radar_hdf5 import RadarSubImage, read_radar_hdf5
from openweer.tiler.tiling import reproject_to_3857, write_zoom

log = get_logger(__name__)

# NL bounding box (lon_min, lat_min, lon_max, lat_max).
NL_BBOX_LL: tuple[float, float, float, float] = (3.0, 50.6, 7.4, 53.7)
DEFAULT_ZOOMS: tuple[int, ...] = (6, 7, 8, 9, 10)

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
            warped, dst_transform, dst_bounds = reproject_to_3857(sub, self.bbox)
            rgba = apply_rain_colormap(warped)
            staging_root = Path(work_dir) / plan.frame_id
            staging_root.mkdir(parents=True, exist_ok=True)
            for z in self.zoom_levels:
                write_zoom(rgba, dst_transform, dst_bounds, z, staging_root, self.bbox)
            target = self.tiles_dir / plan.frame_id
            if target.exists() or target.is_symlink():
                if target.is_symlink() or target.is_file():
                    target.unlink()
                else:
                    shutil.rmtree(target)
            os.replace(staging_root, target)


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
