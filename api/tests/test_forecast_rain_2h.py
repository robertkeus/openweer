"""Per-location rain sampling — synthetic HDF5 covers the full path."""

from __future__ import annotations

from datetime import UTC, datetime
from pathlib import Path

import h5py
import numpy as np

from openweer.forecast.rain_2h import sample_rain_nowcast


def _make_radar_with_rain_at(path: Path, *, col: int, row: int, pv: int = 200) -> None:
    """Synthetic KNMI-shaped radar HDF5 with one rainy pixel."""
    with h5py.File(path, "w") as f:
        geo = f.create_group("geographic")
        geo.attrs["geo_pixel_size_x"] = np.float32(1.0)
        geo.attrs["geo_pixel_size_y"] = np.float32(-1.0)
        geo.attrs["geo_column_offset"] = np.float32(0.0)
        geo.attrs["geo_row_offset"] = np.float32(3650.0)
        geo.create_group("map_projection")

        for i in range(1, 4):
            grp = f.create_group(f"image{i}")
            data = np.zeros((765, 700), dtype=np.uint16)
            data[row, col] = pv  # PV*0.01*12 mm/h
            grp.create_dataset("image_data", data=data)
            valid = f"03-MAY-2026;06:{(30 + (i - 1) * 5):02d}:00.000"
            grp.attrs["image_datetime_valid"] = valid.encode("ascii")
            cal = grp.create_group("calibration")
            cal.attrs["calibration_formulas"] = b"GEO=0.010000*PV+0.000000"
            cal.attrs["calibration_missing_data"] = np.int32(65534)
            cal.attrs["calibration_out_of_image"] = np.int32(65535)


def test_sample_returns_one_entry_per_sub_image(tmp_path: Path) -> None:
    path = tmp_path / "rad.h5"
    _make_radar_with_rain_at(path, col=350, row=400)

    nc = sample_rain_nowcast(path, lat=52.0, lon=5.0)
    assert len(nc.samples) == 3
    assert nc.samples[0].minutes_ahead == 0
    assert nc.samples[1].minutes_ahead == 5
    assert nc.samples[2].minutes_ahead == 10
    assert nc.analysis_at == datetime(2026, 5, 3, 6, 30, tzinfo=UTC)


def test_sample_returns_zero_for_dry_point(tmp_path: Path) -> None:
    """A point where the array is 0 should serialise as 0.0 mm/h, not NaN."""
    path = tmp_path / "rad.h5"
    _make_radar_with_rain_at(path, col=10, row=10)
    nc = sample_rain_nowcast(path, lat=52.0, lon=5.0)
    # Random NL location won't hit pixel (10, 10), so samples should be 0.0.
    assert all(s.mm_per_h == 0.0 for s in nc.samples)


def test_dict_serialisation_round_trip(tmp_path: Path) -> None:
    path = tmp_path / "rad.h5"
    _make_radar_with_rain_at(path, col=100, row=200)
    nc = sample_rain_nowcast(path, lat=52.0, lon=5.0)
    d = nc.as_dict()
    assert d["lat"] == 52.0
    assert d["lon"] == 5.0
    assert isinstance(d["samples"], list)
    assert {"minutes_ahead", "mm_per_h", "valid_at"} <= set(d["samples"][0])
