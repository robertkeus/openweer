"""Historical point-rain samples — the past 2 h of observed radar at a (lat, lon).

The radar nowcast endpoint already returns forward-looking samples (the latest
file's 25 sub-images at +0..+120 min). For the slider's intensity bars to
fill in to the LEFT of "Nu" too, we walk recent ingested radar files on disk
and pluck each one's `image1` (the analysis-time observation) at the user's
point — one historical sample per radar file (5-min cadence, kept for 3 h by
the ingest retention policy).
"""

from __future__ import annotations

from collections.abc import Iterable
from datetime import datetime, timedelta
from pathlib import Path

import h5py
import numpy as np
from rasterio.warp import transform as warp_transform  # type: ignore[import-untyped]

from openweer._logging import get_logger
from openweer.forecast.rain_2h import RainSample
from openweer.tiler.radar_hdf5 import read_radar_hdf5

log = get_logger(__name__)


def sample_rain_history(
    radar_dir: Path,
    *,
    lat: float,
    lon: float,
    analysis_at: datetime,
    history: timedelta = timedelta(hours=2),
    exclude_filenames: Iterable[str] = (),
) -> list[RainSample]:
    """Scan recent radar HDF5 files and return one point-rain sample per file.

    Files whose `image1` timestamp falls outside `[analysis_at - history,
    analysis_at)` are skipped — the caller already has the latest analysis
    sample from the forward nowcast, and we don't want to duplicate it.
    """
    if not radar_dir.is_dir():
        return []
    earliest = analysis_at - history
    skip = set(exclude_filenames)
    samples: list[RainSample] = []
    # h5 files only; sorted oldest → newest so the resulting list is
    # chronological.
    for path in sorted(radar_dir.glob("*.h5")):
        if path.name in skip:
            continue
        try:
            ts = _peek_image1_timestamp(path)
        except Exception:
            log.exception("rain_history.peek_failed", path=str(path))
            continue
        if ts is None or ts < earliest or ts >= analysis_at:
            continue
        try:
            mm_per_h = _sample_image1_at_point(path, lat=lat, lon=lon)
        except Exception:
            log.exception("rain_history.sample_failed", path=str(path))
            continue
        minutes = round((ts - analysis_at).total_seconds() / 60.0)
        samples.append(
            RainSample(minutes_ahead=minutes, mm_per_h=mm_per_h, valid_at=ts)
        )
    return samples


def _peek_image1_timestamp(path: Path) -> datetime | None:
    """Cheap-ish: open the file just to read image1's valid-at attribute.

    Used to filter the file list by time before doing the (much more
    expensive) full image1 read + point projection.
    """
    # `read_radar_hdf5` parses the whole file; for the time-filter pass we
    # only need image1's attribute so we read it directly.
    with h5py.File(path, "r") as f:
        grp = f.get("image1")
        if grp is None:
            return None
        raw = grp.attrs.get("image_datetime_valid")
        text = _decode_attr(raw)
        if not text:
            return None
        return _parse_knmi_datetime(text)


def _sample_image1_at_point(path: Path, *, lat: float, lon: float) -> float:
    """Full image1 read + point projection. Returns 0.0 outside the grid."""
    subs = read_radar_hdf5(path)
    if not subs:
        return 0.0
    first = subs[0]
    xs, ys = warp_transform("EPSG:4326", first.crs, [lon], [lat])
    col = round((xs[0] - first.transform.c) / first.transform.a)
    row = round((ys[0] - first.transform.f) / first.transform.e)
    h, w = first.mm_per_h.shape
    if not (0 <= row < h and 0 <= col < w):
        return 0.0
    value = float(first.mm_per_h[row, col])
    if np.isnan(value):
        return 0.0
    return max(0.0, value)


# ---- KNMI HDF5 attribute parsing (mirrors radar_hdf5.py) ----

_MONTHS = {
    "JAN": 1, "FEB": 2, "MAR": 3, "APR": 4, "MAY": 5, "JUN": 6,
    "JUL": 7, "AUG": 8, "SEP": 9, "OCT": 10, "NOV": 11, "DEC": 12,
}


def _decode_attr(value: object) -> str:
    if value is None:
        return ""
    if isinstance(value, str):
        return value
    if isinstance(value, (bytes, bytearray)):
        return value.decode("ascii", "ignore")
    if hasattr(value, "tobytes"):
        try:
            return value.tobytes().decode("ascii", "ignore")
        except (AttributeError, UnicodeDecodeError):
            pass
    return str(value)


def _parse_knmi_datetime(text: str) -> datetime | None:
    import re
    from datetime import UTC

    m = re.search(
        r"(\d{2})-([A-Z]{3})-(\d{4});(\d{2}):(\d{2}):(\d{2})",
        text,
    )
    if not m:
        return None
    day, mon, year, hh, mm, ss = m.groups()
    if mon not in _MONTHS:
        return None
    return datetime(
        year=int(year),
        month=_MONTHS[mon],
        day=int(day),
        hour=int(hh),
        minute=int(mm),
        second=int(ss),
        tzinfo=UTC,
    )


__all__ = ["sample_rain_history"]
