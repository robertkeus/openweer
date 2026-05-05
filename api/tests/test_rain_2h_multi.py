"""Multi-point variant of `sample_rain_nowcast` — opens HDF5 once for N points."""

from __future__ import annotations

from datetime import UTC, datetime
from pathlib import Path

import h5py
import numpy as np

from openweer.forecast.rain_2h import sample_rain_nowcasts


def _make_radar(path: Path) -> None:
    """Synthetic KNMI-shaped radar HDF5 with three time-steps, all dry."""
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
            grp.create_dataset("image_data", data=data)
            valid = f"03-MAY-2026;06:{(30 + (i - 1) * 5):02d}:00.000"
            grp.attrs["image_datetime_valid"] = valid.encode("ascii")
            cal = grp.create_group("calibration")
            cal.attrs["calibration_formulas"] = b"GEO=0.010000*PV+0.000000"
            cal.attrs["calibration_missing_data"] = np.int32(65534)
            cal.attrs["calibration_out_of_image"] = np.int32(65535)


def test_returns_one_nowcast_per_point(tmp_path: Path) -> None:
    path = tmp_path / "rad.h5"
    _make_radar(path)

    points = [(52.37, 4.89), (51.92, 4.48), (52.09, 5.12)]
    out = sample_rain_nowcasts(path, points)
    assert len(out) == 3
    for nc, (lat, lon) in zip(out, points, strict=True):
        assert nc.lat == lat
        assert nc.lon == lon


def test_all_nowcasts_share_the_same_analysis_at(tmp_path: Path) -> None:
    path = tmp_path / "rad.h5"
    _make_radar(path)

    out = sample_rain_nowcasts(path, [(52.37, 4.89), (51.92, 4.48)])
    analyses = {nc.analysis_at for nc in out}
    assert analyses == {datetime(2026, 5, 3, 6, 30, tzinfo=UTC)}


def test_dry_pixels_resolve_to_zero(tmp_path: Path) -> None:
    path = tmp_path / "rad.h5"
    _make_radar(path)
    out = sample_rain_nowcasts(path, [(52.37, 4.89)])
    assert all(s.mm_per_h == 0.0 for s in out[0].samples)


def test_empty_points_returns_empty_list(tmp_path: Path) -> None:
    path = tmp_path / "rad.h5"
    _make_radar(path)
    assert sample_rain_nowcasts(path, []) == []
