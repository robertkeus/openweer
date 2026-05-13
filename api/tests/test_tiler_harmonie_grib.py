"""HARMONIE tarball reader tests.

A real KNMI HARMONIE tar packs ~61 per-step GRIB files; each per-step GRIB has
~49 parameter bands including APCP (total precipitation, accumulated mm since
model start). Differencing successive accumulations yields the mm/h frame for
one forecast hour.

Building a synthetic eccodes-encoded GRIB in tests is impractical; rasterio's
GeoTIFF writer round-trips the GRIB_* band tags we depend on at runtime, so we
fake per-step "GRIBs" with single-band GeoTIFFs and pack them into a tar with
the real HARMONIE member-naming convention.
"""

from __future__ import annotations

import tarfile
from datetime import UTC, datetime
from pathlib import Path

import numpy as np
import pytest
import rasterio
from rasterio.crs import CRS
from rasterio.transform import from_origin

from openweer.tiler.harmonie_grib import read_harmonie_tar

REF_TIME = 1_715_558_400  # 2024-05-13 00:00:00Z
HEIGHT, WIDTH = 4, 5


def _write_step_geotiff(
    path: Path,
    *,
    hour: int,
    accumulated_mm: float,
    nodata: float | None = None,
    nodata_mask: np.ndarray | None = None,
    element: str = "APCP",
    comment: str = "Total Precipitation [kg/(m^2)]",
) -> None:
    """Write a single-band GeoTIFF mimicking one per-step HARMONIE GRIB."""
    profile: dict[str, object] = {
        "driver": "GTiff",
        "height": HEIGHT,
        "width": WIDTH,
        "count": 1,
        "dtype": "float32",
        "crs": CRS.from_epsg(4326),
        "transform": from_origin(3.0, 53.7, 0.88, 0.775),
    }
    if nodata is not None:
        profile["nodata"] = nodata
    band = np.full((HEIGHT, WIDTH), accumulated_mm, dtype="float32")
    if nodata is not None and nodata_mask is not None:
        band[nodata_mask] = nodata
    with rasterio.open(path, "w", **profile) as dst:
        dst.write(band, 1)
        valid = REF_TIME + hour * 3600
        dst.update_tags(
            1,
            GRIB_ELEMENT=element,
            GRIB_FORECAST_SECONDS=f"{hour * 3600} sec",
            GRIB_REF_TIME=f"{REF_TIME} sec UTC",
            GRIB_VALID_TIME=f"{valid} sec UTC",
            GRIB_COMMENT=comment,
            GRIB_UNIT="[kg/(m^2)]",
        )


def _build_tar(
    tar_path: Path,
    steps: list[tuple[int, float]],
    *,
    work: Path,
    element: str = "APCP",
    comment: str = "Total Precipitation [kg/(m^2)]",
    nodata: float | None = None,
    nodata_hour: int | None = None,
    nodata_mask: np.ndarray | None = None,
    extra_member_at_step: int | None = None,
) -> None:
    """Pack per-step single-band GeoTIFFs into a tar with HARMONIE naming."""
    work.mkdir(parents=True, exist_ok=True)
    paths: list[tuple[str, Path]] = []
    for hour, acc in steps:
        name = f"HA43_N20_202405130000_{hour * 100:05d}_GB"
        path = work / name
        _write_step_geotiff(
            path,
            hour=hour,
            accumulated_mm=acc,
            nodata=nodata,
            nodata_mask=nodata_mask if nodata_hour == hour else None,
            element=element,
            comment=comment,
        )
        paths.append((name, path))
    with tarfile.open(tar_path, "w") as tf:
        for name, p in paths:
            tf.add(p, arcname=name)
        if extra_member_at_step is not None:
            unrelated = work / "UNRELATED.txt"
            unrelated.write_text("ignore me")
            tf.add(unrelated, arcname="UNRELATED.txt")


def test_returns_hourly_differences_in_mm_per_h(tmp_path: Path) -> None:
    tar = tmp_path / "harm.tar"
    _build_tar(tar, [(0, 0.0), (1, 0.5), (2, 1.7), (3, 4.0)], work=tmp_path / "w")

    frames = read_harmonie_tar(tar, forecast_hours=(2, 3))
    assert [f.name for f in frames] == ["harmonie_h02", "harmonie_h03"]
    # h2 mm/h = 1.7 - 0.5 = 1.2 ; h3 mm/h = 4.0 - 1.7 = 2.3
    assert frames[0].mm_per_h[0, 0] == pytest.approx(1.2, rel=1e-5)
    assert frames[1].mm_per_h[0, 0] == pytest.approx(2.3, rel=1e-5)


def test_valid_at_is_utc_aware_and_matches_forecast_hour(tmp_path: Path) -> None:
    tar = tmp_path / "harm.tar"
    _build_tar(tar, [(0, 0.0), (1, 0.0), (2, 0.0), (3, 1.0)], work=tmp_path / "w")

    [frame] = read_harmonie_tar(tar, forecast_hours=(3,))
    assert frame.valid_at == datetime(2024, 5, 13, 3, 0, 0, tzinfo=UTC)


def test_skips_hour_without_predecessor_step(tmp_path: Path) -> None:
    tar = tmp_path / "harm.tar"
    # Hour 0 missing → hour 1 cannot be differenced; 2 and 3 still resolvable.
    _build_tar(tar, [(1, 0.5), (2, 1.7), (3, 4.0)], work=tmp_path / "w")

    frames = read_harmonie_tar(tar, forecast_hours=(1, 2, 3))
    assert [f.name for f in frames] == ["harmonie_h02", "harmonie_h03"]


def test_clamps_tiny_negative_drift_to_zero(tmp_path: Path) -> None:
    tar = tmp_path / "harm.tar"
    # h3 accumulation < h2 by numerical-noise margin.
    _build_tar(tar, [(0, 0.0), (1, 0.0), (2, 0.501), (3, 0.500)], work=tmp_path / "w")

    [frame] = read_harmonie_tar(tar, forecast_hours=(3,))
    assert frame.mm_per_h[0, 0] == pytest.approx(0.0, abs=1e-6)


def test_nodata_pixel_becomes_nan(tmp_path: Path) -> None:
    tar = tmp_path / "harm.tar"
    mask = np.zeros((HEIGHT, WIDTH), dtype=bool)
    mask[0, 0] = True
    _build_tar(
        tar,
        [(0, 0.0), (1, 0.5), (2, 1.7), (3, 4.0)],
        work=tmp_path / "w",
        nodata=-9999.0,
        nodata_hour=3,
        nodata_mask=mask,
    )

    [frame] = read_harmonie_tar(tar, forecast_hours=(3,))
    assert np.isnan(frame.mm_per_h[0, 0])
    assert frame.mm_per_h[1, 1] == pytest.approx(2.3, rel=1e-5)


def test_ignores_unrelated_tar_members(tmp_path: Path) -> None:
    tar = tmp_path / "harm.tar"
    _build_tar(
        tar,
        [(0, 0.0), (1, 0.5), (2, 1.7), (3, 4.0)],
        work=tmp_path / "w",
        extra_member_at_step=999,
    )
    [frame] = read_harmonie_tar(tar, forecast_hours=(3,))
    assert frame.mm_per_h[0, 0] == pytest.approx(2.3, rel=1e-5)


def test_ignores_non_precipitation_bands(tmp_path: Path) -> None:
    tar = tmp_path / "harm.tar"
    _build_tar(
        tar,
        [(0, 280.0), (1, 281.0), (2, 282.0), (3, 283.0)],
        work=tmp_path / "w",
        element="TMP",
        comment="Temperature [K]",
    )
    assert read_harmonie_tar(tar, forecast_hours=(3,)) == []


def test_no_requested_hours_returns_empty(tmp_path: Path) -> None:
    tar = tmp_path / "harm.tar"
    _build_tar(tar, [(0, 0.0), (1, 0.0)], work=tmp_path / "w")
    assert read_harmonie_tar(tar, forecast_hours=()) == []


def test_strips_nested_paths_in_member_names(tmp_path: Path) -> None:
    """A malicious tar with `..` in member names must not escape the temp dir."""
    work = tmp_path / "w"
    work.mkdir()
    _write_step_geotiff(work / "hour0", hour=0, accumulated_mm=0.0)
    _write_step_geotiff(work / "hour3", hour=3, accumulated_mm=4.0)
    _write_step_geotiff(work / "hour2", hour=2, accumulated_mm=1.7)

    tar = tmp_path / "evil.tar"
    with tarfile.open(tar, "w") as tf:
        # Path-traversal attempt in the archive member name.
        tf.add(work / "hour0", arcname="../../escape/HA43_N20_X_00000_GB")
        tf.add(work / "hour2", arcname="../../escape/HA43_N20_X_00200_GB")
        tf.add(work / "hour3", arcname="../../escape/HA43_N20_X_00300_GB")

    # Reader must still resolve hours 2 and 3 (it strips the nested path),
    # and crucially must not write outside its temp dir.
    frames = read_harmonie_tar(tar, forecast_hours=(3,))
    assert frames
    assert frames[0].mm_per_h[0, 0] == pytest.approx(2.3, rel=1e-5)
