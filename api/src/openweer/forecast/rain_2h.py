"""2-hour minute-by-minute rain forecast at a (lat, lon).

Given the latest `radar_forecast` HDF5 file (25 sub-images at 5-min cadence
from t=0 to t=+120 min), sample the mm/h value at the requested point in
each sub-image. Returns a typed result; the API layer just serialises.
"""

from __future__ import annotations

from dataclasses import dataclass
from datetime import datetime
from pathlib import Path

import numpy as np
from rasterio.warp import transform as warp_transform

from openweer.tiler.radar_hdf5 import RadarSubImage, read_radar_hdf5


@dataclass(frozen=True, slots=True)
class RainSample:
    """One time-step of the per-location rain forecast."""

    minutes_ahead: int
    mm_per_h: float
    valid_at: datetime


@dataclass(frozen=True, slots=True)
class RainNowcast:
    """The 2-hour forecast at one (lat, lon) point."""

    lat: float
    lon: float
    analysis_at: datetime
    samples: tuple[RainSample, ...]

    def as_dict(self) -> dict[str, object]:
        return {
            "lat": self.lat,
            "lon": self.lon,
            "analysis_at": self.analysis_at.isoformat(),
            "samples": [
                {
                    "minutes_ahead": s.minutes_ahead,
                    "mm_per_h": s.mm_per_h,
                    "valid_at": s.valid_at.isoformat(),
                }
                for s in self.samples
            ],
        }


def sample_rain_nowcast(hdf5_path: Path, *, lat: float, lon: float) -> RainNowcast:
    """Read the radar_forecast file and sample mm/h at (lat, lon) for every sub-image."""
    sub_images = read_radar_hdf5(hdf5_path)
    if not sub_images:
        raise ValueError(f"No sub-images in {hdf5_path}")

    analysis = sub_images[0].valid_at
    samples = tuple(_sample_one(sub, lat, lon, analysis) for sub in sub_images)
    return RainNowcast(lat=lat, lon=lon, analysis_at=analysis, samples=samples)


def _sample_one(sub: RadarSubImage, lat: float, lon: float, analysis_at: datetime) -> RainSample:
    src_x, src_y = warp_transform("EPSG:4326", sub.crs, [lon], [lat])
    col = round((src_x[0] - sub.transform.c) / sub.transform.a)
    row = round((src_y[0] - sub.transform.f) / sub.transform.e)

    h, w = sub.mm_per_h.shape
    if 0 <= row < h and 0 <= col < w:
        value = float(sub.mm_per_h[row, col])
    else:
        value = float("nan")
    if np.isnan(value):
        value = 0.0

    minutes = round((sub.valid_at - analysis_at).total_seconds() / 60.0)
    return RainSample(minutes_ahead=minutes, mm_per_h=value, valid_at=sub.valid_at)
