"""End-to-end: HARMONIE tar → tiles + manifest entry of kind='hourly'.

Stands in synthetic single-band GeoTIFFs (one per forecast hour) packed in a
tar with the real KNMI HARMONIE member-naming convention.
"""

from __future__ import annotations

import tarfile
from pathlib import Path

import numpy as np
import rasterio
from rasterio.crs import CRS
from rasterio.transform import from_origin

from openweer.tiler.manifest import ManifestStore
from openweer.tiler.pipeline import RadarTilePipeline

REF_TIME = 1_715_558_400  # 2024-05-13 00:00:00Z
_NL_W, _NL_E = 3.0, 7.4
_NL_S, _NL_N = 50.6, 53.7


def _write_step(work: Path, hour: int, accumulated_mm: float) -> Path:
    name = f"HA43_N20_202405130000_{hour * 100:05d}_GB"
    path = work / name
    width, height = 16, 12
    pixel_w = (_NL_E - _NL_W) / width
    pixel_h = (_NL_N - _NL_S) / height
    profile: dict[str, object] = {
        "driver": "GTiff",
        "height": height,
        "width": width,
        "count": 1,
        "dtype": "float32",
        "crs": CRS.from_epsg(4326),
        "transform": from_origin(_NL_W, _NL_N, pixel_w, pixel_h),
    }
    with rasterio.open(path, "w", **profile) as dst:
        dst.write(np.full((height, width), accumulated_mm, dtype="float32"), 1)
        valid = REF_TIME + hour * 3600
        dst.update_tags(
            1,
            GRIB_ELEMENT="APCP",
            GRIB_FORECAST_SECONDS=f"{hour * 3600} sec",
            GRIB_REF_TIME=f"{REF_TIME} sec UTC",
            GRIB_VALID_TIME=f"{valid} sec UTC",
            GRIB_COMMENT="Total Precipitation [kg/(m^2)]",
            GRIB_UNIT="[kg/(m^2)]",
        )
    return path


def _write_harmonie_tar(tmp_path: Path) -> Path:
    work = tmp_path / "steps"
    work.mkdir()
    # Cover hours 0..8 so HARMONIE_FORECAST_HOURS = (3..8) all resolve with a
    # predecessor band. Monotone-increasing accumulation: hourly mm/h = 1.
    paths = [_write_step(work, h, float(h)) for h in range(0, 9)]
    tar = tmp_path / "harmonie.tar"
    with tarfile.open(tar, "w") as tf:
        for p in paths:
            tf.add(p, arcname=p.name)
    return tar


def _build_pipeline(tmp_path: Path) -> RadarTilePipeline:
    tiles_dir = tmp_path / "tiles"
    staging_dir = tmp_path / "tiles_staging"
    manifest = ManifestStore(tmp_path / "frames.json")
    return RadarTilePipeline(
        tiles_dir=tiles_dir,
        staging_dir=staging_dir,
        manifest=manifest,
        zoom_levels=(6, 7),
    )


def test_renders_hourly_frames_fanned_to_10_min_cadence(tmp_path: Path) -> None:
    """HARMONIE delivers hourly forecasts; we fan each out into six 10-min
    sub-frames sharing the same rain field so the slider's cadence stays
    uniform with the radar nowcast portion."""
    tar_path = _write_harmonie_tar(tmp_path)
    pipeline = _build_pipeline(tmp_path)

    frames = pipeline.render_file(tar_path)

    assert {f.kind for f in frames} == {"hourly"}
    assert {f.cadence_minutes for f in frames} == {10}
    # 6 forecast hours × 6 slots per hour = 36 sub-frames.
    assert len(frames) == 36
    # Every slot timestamp must fall on a 10-min boundary.
    for f in frames:
        assert f.ts.minute % 10 == 0, f"{f.id} not on a 10-min boundary"


def test_skips_harmonie_slots_already_covered_by_nowcast(tmp_path: Path) -> None:
    """If the manifest already has nowcast/observed for a wall-clock minute,
    the HARMONIE slot at that same minute must not be emitted — radar wins."""
    from datetime import UTC, datetime

    from openweer.tiler.manifest import Frame

    tar_path = _write_harmonie_tar(tmp_path)
    pipeline = _build_pipeline(tmp_path)

    # Pre-seed a nowcast frame at the HARMONIE hour-3 end slot (REF_TIME + 3h).
    nowcast_ts = datetime.fromtimestamp(REF_TIME + 3 * 3600, tz=UTC)
    nowcast_id = nowcast_ts.strftime("%Y%m%dT%H%M") + "Z"
    pipeline.manifest.upsert(
        [
            Frame(
                id=nowcast_id,
                ts=nowcast_ts,
                kind="nowcast",
                cadence_minutes=5,
                max_zoom=10,
            )
        ]
    )

    frames = pipeline.render_file(tar_path)

    written_ids = {f.id for f in frames}
    assert nowcast_id not in written_ids, "HARMONIE must defer to existing nowcast"
    # One of the 36 slots got dropped; 35 remain.
    assert len(frames) == 35


def test_manifest_contains_hourly_frame(tmp_path: Path) -> None:
    tar_path = _write_harmonie_tar(tmp_path)
    pipeline = _build_pipeline(tmp_path)
    pipeline.render_file(tar_path)

    manifest = pipeline.manifest.read()
    hourly = [f for f in manifest.frames if f.kind == "hourly"]
    assert hourly
    assert all(f.cadence_minutes == 10 for f in hourly)


def test_tile_dirs_written_for_every_zoom(tmp_path: Path) -> None:
    tar_path = _write_harmonie_tar(tmp_path)
    pipeline = _build_pipeline(tmp_path)
    frames = pipeline.render_file(tar_path)

    assert frames
    for frame in frames:
        frame_dir = pipeline.tiles_dir / frame.id
        assert frame_dir.is_dir(), f"missing tile dir for {frame.id}"
        for zoom in pipeline.zoom_levels:
            pngs = list((frame_dir / str(zoom)).rglob("*.png"))
            assert pngs, f"no tiles at zoom {zoom} for frame {frame.id}"


def test_unknown_file_suffix_returns_empty_and_does_not_raise(tmp_path: Path) -> None:
    pipeline = _build_pipeline(tmp_path)
    bogus = tmp_path / "mystery.bin"
    bogus.write_bytes(b"\x00\x01\x02")
    assert pipeline.render_file(bogus) == []
