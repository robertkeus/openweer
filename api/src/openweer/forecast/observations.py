"""Parser for KNMI's 10-min in-situ observation NetCDF files.

Each ingested file (`KMDS__OPER_P___10M_OBS_L2_<YYYYMMDDHHMM>.nc`) contains
one timestep of observations from ~55 NL stations. We open it with h5py
(NetCDF4 is a thin wrapper around HDF5) so we don't add a new dependency.
"""

from __future__ import annotations

import math
from dataclasses import dataclass
from datetime import UTC, datetime
from pathlib import Path

import h5py
import numpy as np

# Time origin used by KNMI in the `time` variable.
_TIME_ORIGIN_S = datetime(1950, 1, 1, tzinfo=UTC).timestamp()


@dataclass(frozen=True, slots=True)
class StationObservation:
    station_id: str
    station_name: str
    lat: float
    lon: float
    height_m: float
    distance_km: float
    observed_at: datetime
    temperature_c: float | None
    wind_speed_mps: float | None
    wind_gust_mps: float | None
    wind_direction_deg: float | None
    humidity_pct: float | None
    pressure_hpa: float | None
    rainfall_1h_mm: float | None
    rainfall_24h_mm: float | None
    cloud_cover_octas: float | None
    visibility_m: float | None
    weather_code: int | None


def _decode_ascii(arr: np.ndarray, idx: int) -> str:
    """Pull the per-station ASCII string at `idx` from a fixed-length char array."""
    raw = arr[idx]
    if isinstance(raw, np.bytes_):
        return raw.decode("ascii", errors="ignore").strip()
    if isinstance(raw, bytes):
        return raw.decode("ascii", errors="ignore").strip()
    return str(raw).strip()


def _maybe_scalar(arr: np.ndarray, idx: int) -> float | None:
    """Read element idx, return None for NaN / fill values."""
    if arr.size == 0:
        return None
    if arr.ndim >= 2:
        v = arr[idx, 0]
    else:
        v = arr[idx]
    if v is None:
        return None
    f = float(v)
    if math.isnan(f) or math.isinf(f):
        return None
    return f


def _haversine_km(lat1: float, lon1: float, lat2: float, lon2: float) -> float:
    rlat1, rlat2 = math.radians(lat1), math.radians(lat2)
    dlat = math.radians(lat2 - lat1)
    dlon = math.radians(lon2 - lon1)
    a = math.sin(dlat / 2) ** 2 + math.cos(rlat1) * math.cos(rlat2) * math.sin(dlon / 2) ** 2
    return 2 * 6371.0 * math.asin(math.sqrt(a))


def latest_observation_path(raw_dir: Path) -> Path | None:
    """Return the most recently-modified KMDS .nc file in `raw_dir`, or None."""
    if not raw_dir.is_dir():
        return None
    candidates = sorted(
        raw_dir.glob("KMDS__OPER_P___10M_OBS_L2_*.nc"),
        key=lambda p: p.stat().st_mtime,
    )
    return candidates[-1] if candidates else None


def nearest_station_observation(
    nc_path: Path,
    lat: float,
    lon: float,
) -> StationObservation:
    """Open `nc_path` and return the observation row whose station is closest
    to (lat, lon). Land stations only — offshore platforms (lat>54.5) are
    excluded so the result feels relevant to the user."""
    with h5py.File(nc_path, "r") as f:
        lats = np.asarray(f["lat"][:], dtype=float)
        lons = np.asarray(f["lon"][:], dtype=float)
        # Mask offshore platforms — they sit far north of the Wadden Sea
        # (lat > 54.5) and skew "nearest" results from coastal cities.
        mask = lats <= 54.5

        distances = np.array(
            [_haversine_km(lat, lon, la, lo) for la, lo in zip(lats, lons, strict=True)]
        )
        # Penalise masked-out indices so they're never closest.
        distances[~mask] = math.inf
        idx = int(np.argmin(distances))

        time_s = float(f["time"][0]) if "time" in f else 0.0
        observed_at = datetime.fromtimestamp(_TIME_ORIGIN_S + time_s, tz=UTC)

        station_id = _decode_ascii(f["station"][:], idx)
        station_name = (
            _decode_ascii(f["stationname"][:], idx) if "stationname" in f else station_id
        )

        return StationObservation(
            station_id=station_id,
            station_name=station_name,
            lat=float(lats[idx]),
            lon=float(lons[idx]),
            height_m=_maybe_scalar(np.asarray(f["height"][:]), idx) or 0.0,
            distance_km=float(distances[idx]),
            observed_at=observed_at,
            temperature_c=_maybe_scalar(np.asarray(f["ta"][:]), idx),
            wind_speed_mps=_maybe_scalar(np.asarray(f["ff"][:]), idx),
            wind_gust_mps=_maybe_scalar(np.asarray(f["gff"][:]), idx) if "gff" in f else None,
            wind_direction_deg=_maybe_scalar(np.asarray(f["dd"][:]), idx),
            humidity_pct=_maybe_scalar(np.asarray(f["rh"][:]), idx),
            pressure_hpa=_maybe_scalar(np.asarray(f["pp"][:]), idx) if "pp" in f else None,
            rainfall_1h_mm=_maybe_scalar(np.asarray(f["R1H"][:]), idx) if "R1H" in f else None,
            rainfall_24h_mm=_maybe_scalar(np.asarray(f["R24H"][:]), idx) if "R24H" in f else None,
            cloud_cover_octas=_maybe_scalar(np.asarray(f["n"][:]), idx) if "n" in f else None,
            visibility_m=_maybe_scalar(np.asarray(f["vv"][:]), idx) if "vv" in f else None,
            weather_code=_weather_code(np.asarray(f["ww"][:]), idx) if "ww" in f else None,
        )


def _weather_code(arr: np.ndarray, idx: int) -> int | None:
    v = _maybe_scalar(arr, idx)
    return None if v is None else round(v)
