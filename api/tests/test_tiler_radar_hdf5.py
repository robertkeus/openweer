"""Radar HDF5 reader — synthetic file fixture covers the full schema."""

from __future__ import annotations

from datetime import UTC, datetime
from pathlib import Path

import h5py
import numpy as np
import pytest

from openweer.tiler.radar_hdf5 import read_radar_hdf5


def _make_synthetic_radar(
    path: Path, *, num_images: int = 2, missing_at: tuple[int, int] | None = None
) -> None:
    """Write a tiny KNMI-shaped HDF5 file to `path`."""
    with h5py.File(path, "w") as f:
        geo = f.create_group("geographic")
        geo.attrs["geo_pixel_size_x"] = np.float32(1.0)
        geo.attrs["geo_pixel_size_y"] = np.float32(-1.0)
        geo.attrs["geo_column_offset"] = np.float32(0.0)
        geo.attrs["geo_row_offset"] = np.float32(3650.0)
        geo.create_group("map_projection")

        base_minute = 0
        for i in range(1, num_images + 1):
            grp = f.create_group(f"image{i}")
            data = np.full((4, 5), 100, dtype=np.uint16)  # 100 PV → 1.0 mm → 12 mm/h
            if missing_at and i == 1:
                data[missing_at] = 65534
            grp.create_dataset("image_data", data=data)
            grp.attrs["image_datetime_valid"] = (
                f"03-MAY-2026;{(6 + (base_minute + (i - 1) * 5) // 60):02d}:"
                f"{(base_minute + (i - 1) * 5) % 60:02d}:00.000"
            ).encode("ascii")

            cal = grp.create_group("calibration")
            cal.attrs["calibration_formulas"] = b"GEO=0.010000*PV+0.000000"
            cal.attrs["calibration_missing_data"] = np.int32(65534)
            cal.attrs["calibration_out_of_image"] = np.int32(65535)


def test_reads_all_images_in_natural_order(tmp_path: Path) -> None:
    path = tmp_path / "rad.h5"
    _make_synthetic_radar(path, num_images=12)
    sub = read_radar_hdf5(path)
    names = [s.name for s in sub]
    assert names == [f"image{i}" for i in range(1, 13)]
    # Confirms image10 is sorted *after* image2, not lexically before.


def test_calibration_and_unit_conversion_to_mm_per_h(tmp_path: Path) -> None:
    path = tmp_path / "rad.h5"
    _make_synthetic_radar(path, num_images=1)
    [sub] = read_radar_hdf5(path)
    # PV=100 → GEO=0.01*100 = 1.0 mm in 5min → 12.0 mm/h.
    assert pytest.approx(sub.mm_per_h.flatten()[0], rel=1e-5) == 12.0


def test_missing_pixels_become_nan(tmp_path: Path) -> None:
    path = tmp_path / "rad.h5"
    _make_synthetic_radar(path, num_images=1, missing_at=(2, 2))
    [sub] = read_radar_hdf5(path)
    assert np.isnan(sub.mm_per_h[2, 2])


def test_timestamp_is_utc_aware(tmp_path: Path) -> None:
    path = tmp_path / "rad.h5"
    _make_synthetic_radar(path, num_images=1)
    [sub] = read_radar_hdf5(path)
    assert sub.valid_at == datetime(2026, 5, 3, 6, 0, 0, tzinfo=UTC)


def test_transform_uses_metres_not_kilometres(tmp_path: Path) -> None:
    path = tmp_path / "rad.h5"
    _make_synthetic_radar(path, num_images=1)
    [sub] = read_radar_hdf5(path)
    # KNMI ships km; we convert to m. So pixel_size_x of 1 km → 1000 m.
    # Row offset's sign is flipped so the y-axis matches standard north-pole
    # stereographic (NL is south of the pole → y < 0).
    assert sub.transform.a == pytest.approx(1000.0, rel=1e-4)
    assert sub.transform.e == pytest.approx(-1000.0, rel=1e-4)
    assert sub.transform.f == pytest.approx(-3_650_000.0, rel=1e-4)


def test_crs_is_stereographic_north_pole(tmp_path: Path) -> None:
    path = tmp_path / "rad.h5"
    _make_synthetic_radar(path, num_images=1)
    [sub] = read_radar_hdf5(path)
    proj = sub.crs.to_proj4()
    assert "stere" in proj
    assert "+lat_0=90" in proj
