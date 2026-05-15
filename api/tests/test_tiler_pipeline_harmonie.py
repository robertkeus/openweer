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


def test_emits_one_frame_per_harmonie_forecast_hour(tmp_path: Path) -> None:
    """KNMI's HARMONIE-AROME open-data feed only resolves hourly precipitation,
    so we emit exactly one slider frame per forecast hour rather than fan it
    out into identical sub-minute slots — the user can tell adjacent ticks apart
    instead of seeing the same rain field repeated 6 times per hour."""
    tar_path = _write_harmonie_tar(tmp_path)
    pipeline = _build_pipeline(tmp_path)

    frames = pipeline.render_file(tar_path)

    assert {f.kind for f in frames} == {"hourly"}
    assert {f.cadence_minutes for f in frames} == {60}
    # 6 forecast hours (HARMONIE_FORECAST_HOURS = range(3, 25), clipped to the
    # synthetic tar's hours 3..8) → 6 frames, no fan-out.
    assert len(frames) == 6
    # Every frame timestamp must fall on the hour boundary.
    for f in frames:
        assert f.ts.minute == 0, f"{f.id} not on the hour"


def test_skips_harmonie_hour_already_covered_by_nowcast(tmp_path: Path) -> None:
    """If the manifest already has nowcast/observed for a wall-clock hour,
    the HARMONIE frame at that same hour must not be emitted — radar wins."""
    from datetime import UTC, datetime

    from openweer.tiler.manifest import Frame

    tar_path = _write_harmonie_tar(tmp_path)
    pipeline = _build_pipeline(tmp_path)

    # Pre-seed a nowcast frame at HARMONIE forecast hour 3 (REF_TIME + 3h).
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
    # One of the 6 hourly frames got dropped; 5 remain.
    assert len(frames) == 5


def test_manifest_contains_hourly_frame(tmp_path: Path) -> None:
    tar_path = _write_harmonie_tar(tmp_path)
    pipeline = _build_pipeline(tmp_path)
    pipeline.render_file(tar_path)

    manifest = pipeline.manifest.read()
    hourly = [f for f in manifest.frames if f.kind == "hourly"]
    assert hourly
    assert all(f.cadence_minutes == 60 for f in hourly)


def test_tile_dirs_written_for_every_zoom(tmp_path: Path) -> None:
    tar_path = _write_harmonie_tar(tmp_path)
    pipeline = _build_pipeline(tmp_path)
    frames = pipeline.render_file(tar_path)

    assert frames
    for frame in frames:
        frame_dir = pipeline.tiles_dir / frame.id
        # Must be a real directory now — the symlink-clone fan-out is gone.
        assert frame_dir.is_dir(), f"missing tile dir for {frame.id}"
        assert not frame_dir.is_symlink(), (
            f"{frame.id} is a symlink; HARMONIE frames must be unique tile sets"
        )
        for zoom in pipeline.zoom_levels:
            pngs = list((frame_dir / str(zoom)).rglob("*.png"))
            assert pngs, f"no tiles at zoom {zoom} for frame {frame.id}"


def test_consecutive_harmonie_frames_render_to_distinct_tile_bytes(
    tmp_path: Path,
) -> None:
    """Adjacent HARMONIE frames must have different tile bytes — the user
    feedback that prompted this change was that adjacent slider ticks past +2 h
    showed the identical PNG (because the old fan-out symlinked them all)."""
    import hashlib

    work = tmp_path / "steps"
    work.mkdir()
    # Hours 0..4 chosen so consecutive per-hour mm/h diffs land in *different*
    # colormap buckets (so the rendered PNGs must differ byte-for-byte):
    #   h3 mm/h = 30 - 5  = 25  → red bucket (20–50)
    #   h4 mm/h = 150 - 30 = 120 → magenta bucket (≥50)
    accs = [0.0, 0.5, 5.0, 30.0, 150.0]
    paths = [_write_step(work, h, accs[h]) for h in range(len(accs))]
    tar = tmp_path / "harmonie.tar"
    with tarfile.open(tar, "w") as tf:
        for p in paths:
            tf.add(p, arcname=p.name)

    pipeline = _build_pipeline(tmp_path)
    frames = pipeline.render_file(tar)

    # Two consecutive hourly frames; pick any tile that's present in both.
    assert len(frames) >= 2
    a, b = frames[0], frames[1]

    def _first_png(frame_id: str) -> bytes:
        for png in (pipeline.tiles_dir / frame_id).rglob("*.png"):
            return png.read_bytes()
        raise AssertionError(f"no tile png for {frame_id}")

    assert hashlib.sha256(_first_png(a.id)).digest() != hashlib.sha256(
        _first_png(b.id)
    ).digest(), "adjacent HARMONIE frames must render to different bytes"


def test_unknown_file_suffix_returns_empty_and_does_not_raise(tmp_path: Path) -> None:
    pipeline = _build_pipeline(tmp_path)
    bogus = tmp_path / "mystery.bin"
    bogus.write_bytes(b"\x00\x01\x02")
    assert pipeline.render_file(bogus) == []
