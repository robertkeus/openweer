"""Read KNMI HARMONIE-AROME tarballs into mm/h numpy arrays + an affine.

KNMI ships HARMONIE-AROME CY43 P1 as one `.tar` per model run; the tar contains
~61 per-step GRIB files named `HA43_N{nn}_{YYYYMMDDHHMM}_{step:05d}_GB`, where
`step = forecast_hour * 100`. Each per-step GRIB carries ~49 parameter bands;
band labelled `APCP` is total precipitation accumulated since model start
(kg/m² ≡ mm). Per-hour mm/h is therefore `APCP[hour N] - APCP[hour N-1]`.

We emit `RadarSubImage` instances reusing the same dataclass the radar HDF5
reader produces, so the downstream tile pipeline is format-agnostic.

GRIB reading goes through rasterio's GDAL driver (no new dependency).
"""

from __future__ import annotations

import re
import tarfile
import tempfile
from collections.abc import Iterable, Iterator
from dataclasses import dataclass
from datetime import UTC, datetime
from pathlib import Path
from typing import cast

import numpy as np
import rasterio  # type: ignore[import-untyped]
from rasterio.io import DatasetReader  # type: ignore[import-untyped]

from openweer._logging import get_logger
from openweer.tiler.radar_hdf5 import RadarSubImage

log = get_logger(__name__)

_PRECIP_ELEMENTS: frozenset[str] = frozenset({"APCP", "TP"})
_INT_RE = re.compile(r"-?\d+")
# Per-step filename in the HARMONIE tar: e.g. `HA43_N20_202605080200_00300_GB`.
_STEP_RE = re.compile(r"_(\d{5})_GB$")


@dataclass(frozen=True, slots=True)
class _Accumulation:
    """APCP read from one per-step HARMONIE GRIB — mm accumulated since model start."""

    forecast_hour: int
    valid_at: datetime
    mm: np.ndarray  # (H, W) float32, NaN for missing
    transform: object
    crs: object


def read_harmonie_tar(
    tar_path: Path,
    *,
    forecast_hours: Iterable[int],
) -> list[RadarSubImage]:
    """Read HARMONIE tarball and return one mm/h frame per requested hour.

    Each frame H is the difference `APCP[H] - APCP[H-1]`, so we always need
    the predecessor step too. Hours whose predecessor is missing are skipped
    with a warning rather than raising.
    """
    wanted = tuple(sorted({int(h) for h in forecast_hours if int(h) >= 1}))
    if not wanted:
        return []
    needed_hours = sorted({h for hour in wanted for h in (hour, hour - 1)})
    with tempfile.TemporaryDirectory(prefix="harmonie-") as work:
        extracted = _extract_steps(tar_path, needed_hours, Path(work))
        if not extracted:
            log.warning("harmonie.tar.no_matching_members", tar=str(tar_path))
            return []
        accumulations: dict[int, _Accumulation] = {}
        for _hour, step_path in extracted.items():
            try:
                acc = _read_step_accumulation(step_path)
            except Exception:
                log.exception("harmonie.read_step_failed", step=str(step_path))
                continue
            if acc is not None:
                accumulations[acc.forecast_hour] = acc
        return _diff_accumulations(accumulations, wanted)


def _extract_steps(
    tar_path: Path, hours: list[int], out_dir: Path
) -> dict[int, Path]:
    """Extract just the per-step GRIBs for the requested forecast hours.

    Members are matched by the `_NNNNN_GB$` suffix (5-digit step encodes
    `hour * 100`). Each extracted file is written to a flat path inside
    `out_dir`; we deliberately strip any nested directory structure so a
    malicious tar cannot escape into the host filesystem.
    """
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


def _read_step_accumulation(path: Path) -> _Accumulation | None:
    """Open a per-step HARMONIE GRIB and read its APCP band as accumulated mm."""
    with rasterio.open(path) as src:
        crs = src.crs
        if crs is None:
            raise ValueError(f"{path}: GRIB has no CRS metadata — cannot tile")
        for meta in _iter_precip_bands(src):
            arr = src.read(meta.band_index).astype(np.float32)
            nodata = src.nodatavals[meta.band_index - 1]
            if nodata is not None:
                arr = np.where(arr == nodata, np.float32("nan"), arr)
            return _Accumulation(
                forecast_hour=meta.forecast_seconds // 3600,
                valid_at=meta.valid_at,
                mm=arr,
                transform=src.transform,
                crs=crs,
            )
    return None


def _diff_accumulations(
    accumulations: dict[int, _Accumulation], wanted: tuple[int, ...]
) -> list[RadarSubImage]:
    frames: list[RadarSubImage] = []
    for hour in wanted:
        current = accumulations.get(hour)
        previous = accumulations.get(hour - 1)
        if current is None or previous is None:
            log.warning(
                "harmonie.skip_hour",
                hour=hour,
                has_current=current is not None,
                has_previous=previous is not None,
            )
            continue
        mm = current.mm - previous.mm
        # Accumulated fields are monotone non-decreasing; tiny negatives from
        # numerical noise would otherwise paint stray colormap pixels.
        mm = np.where(mm < 0, np.float32(0.0), mm)
        # NaN propagation: any pixel missing in either step becomes NaN.
        nan_mask = np.isnan(current.mm) | np.isnan(previous.mm)
        mm = np.where(nan_mask, np.float32("nan"), mm)
        frames.append(
            RadarSubImage(
                name=f"harmonie_h{current.forecast_hour:02d}",
                valid_at=current.valid_at,
                mm_per_h=mm.astype(np.float32),
                transform=cast("object", current.transform),  # type: ignore[redundant-cast]
                crs=cast("object", current.crs),  # type: ignore[redundant-cast]
            )
        )
    return frames


# ---- per-band metadata extraction (reusable across single-step files) ----


@dataclass(frozen=True, slots=True)
class _BandMeta:
    band_index: int
    forecast_seconds: int
    valid_at: datetime


def _iter_precip_bands(src: DatasetReader) -> Iterator[_BandMeta]:
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
        yield _BandMeta(band_index=i, forecast_seconds=fcst_s, valid_at=valid)


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


__all__ = ["read_harmonie_tar"]
