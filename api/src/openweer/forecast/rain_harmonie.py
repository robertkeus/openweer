"""Per-point HARMONIE rain samples — extends the slider's intensity bars
beyond the 2 h radar nowcast horizon.

Reads the same per-step GRIBs out of the HARMONIE tar that the tiler already
consumes; samples the APCP band at the requested (lat, lon) at every requested
forecast hour and differences successive accumulations to mm/h.

Emits one sample per forecast hour. The KNMI Open Data feed only resolves
hourly precipitation; the slider's bar graph past +2 h therefore shows one
bar per hour rather than synthesising sub-hourly intermediates.
"""

from __future__ import annotations

import re
import tarfile
import tempfile
from collections.abc import Iterable
from dataclasses import dataclass
from datetime import UTC, datetime
from pathlib import Path

import numpy as np
import rasterio  # type: ignore[import-untyped]
from rasterio.warp import transform as warp_transform  # type: ignore[import-untyped]

from openweer._logging import get_logger

log = get_logger(__name__)

# Match per-step GRIBs inside the HARMONIE tar: e.g. `HA43_N20_YYYYMMDDhhmm_NNNNN_GB`.
_STEP_RE = re.compile(r"_(\d{5})_GB$")
_PRECIP_ELEMENTS = frozenset({"APCP", "TP"})
_INT_RE = re.compile(r"-?\d+")


@dataclass(frozen=True, slots=True)
class HarmonieSample:
    """One forecast hour's mm/h at a single (lat, lon)."""

    minutes_ahead: int
    mm_per_h: float
    valid_at: datetime


def sample_harmonie_at_point(
    tar_path: Path,
    *,
    lat: float,
    lon: float,
    analysis_at: datetime,
    forecast_hours: Iterable[int],
) -> list[HarmonieSample]:
    """Read per-step HARMONIE GRIBs and return point-rain samples.

    `analysis_at` is the wall-clock time the slider treats as t=0 (i.e. the
    radar nowcast analysis time); we compute `minutes_ahead` relative to it
    so the frontend can bucket the result alongside nowcast samples.
    """
    wanted = sorted({int(h) for h in forecast_hours if int(h) >= 1})
    if not wanted:
        return []
    needed_hours = sorted({h for hour in wanted for h in (hour, hour - 1)})

    samples: list[HarmonieSample] = []
    with tempfile.TemporaryDirectory(prefix="harmonie-pt-") as work_dir:
        extracted = _extract_steps(tar_path, needed_hours, Path(work_dir))
        if not extracted:
            log.warning("harmonie.pt.no_steps", tar=str(tar_path))
            return []
        # Read APCP at the point for every extracted step.
        accumulations: dict[int, tuple[datetime, float]] = {}
        for hour, step_path in extracted.items():
            entry = _read_apcp_point(step_path, lat=lat, lon=lon)
            if entry is None:
                continue
            accumulations[hour] = entry
        for hour in wanted:
            current = accumulations.get(hour)
            previous = accumulations.get(hour - 1)
            if current is None or previous is None:
                continue
            mm = max(0.0, current[1] - previous[1])
            minutes = round((current[0] - analysis_at).total_seconds() / 60.0)
            samples.append(
                HarmonieSample(
                    minutes_ahead=minutes,
                    mm_per_h=mm,
                    valid_at=current[0],
                )
            )
    return samples


def _extract_steps(
    tar_path: Path, hours: list[int], out_dir: Path
) -> dict[int, Path]:
    wanted_steps: dict[int, int] = {hour * 100: hour for hour in hours}
    out: dict[int, Path] = {}
    with tarfile.open(tar_path, mode="r") as tf:
        for member in tf:
            if not member.isfile():
                continue
            m = _STEP_RE.search(member.name)
            if not m:
                continue
            step = int(m.group(1))
            hour = wanted_steps.get(step)
            if hour is None:
                continue
            target = out_dir / Path(member.name).name
            src_fp = tf.extractfile(member)
            if src_fp is None:
                continue
            with src_fp:
                target.write_bytes(src_fp.read())
            out[hour] = target
    return out


def _read_apcp_point(
    path: Path, *, lat: float, lon: float
) -> tuple[datetime, float] | None:
    """Find the APCP band, project (lat, lon) into the GRIB's CRS, return
    the cell value at that point + the band's valid_at."""
    with rasterio.open(path) as src:
        crs = src.crs
        if crs is None:
            return None
        for i in range(1, src.count + 1):
            tags = src.tags(i)
            element = (tags.get("GRIB_ELEMENT") or "").strip().upper()
            comment = (tags.get("GRIB_COMMENT") or "").lower()
            if element not in _PRECIP_ELEMENTS and "precipitation" not in comment:
                continue
            fcst_s = _parse_int(tags.get("GRIB_FORECAST_SECONDS"))
            valid = _parse_unix(tags.get("GRIB_VALID_TIME"))
            if fcst_s is None or valid is None or fcst_s % 3600 != 0:
                continue
            xs, ys = warp_transform("EPSG:4326", crs, [lon], [lat])
            col = round((xs[0] - src.transform.c) / src.transform.a)
            row = round((ys[0] - src.transform.f) / src.transform.e)
            h, w = src.height, src.width
            if not (0 <= row < h and 0 <= col < w):
                return valid, 0.0
            arr = src.read(i, window=((row, row + 1), (col, col + 1)))
            value = float(arr[0, 0])
            nodata = src.nodatavals[i - 1]
            if nodata is not None and value == nodata:
                value = 0.0
            if np.isnan(value):
                value = 0.0
            return valid, max(0.0, value)
    return None


def _parse_int(text: str | None) -> int | None:
    if not text:
        return None
    m = _INT_RE.search(text)
    return int(m.group(0)) if m else None


def _parse_unix(text: str | None) -> datetime | None:
    if not text:
        return None
    seconds = _parse_int(text)
    if seconds is None:
        return None
    return datetime.fromtimestamp(seconds, tz=UTC)


__all__ = ["HarmonieSample", "sample_harmonie_at_point"]
