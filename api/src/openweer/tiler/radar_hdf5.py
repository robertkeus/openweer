"""Read KNMI radar HDF5 files into mm/h numpy arrays + a georeferenced affine.

KNMI radar HDF5 layout (verified against `radar_forecast` v2.0):
- /geographic                — grid + projection metadata (km units).
- /geographic/map_projection — proj4 string (`+proj=stere +lat_0=90 +lon_0=0 ...`).
- /imageN/image_data         — 2D uint16 raw pixel values (one or more sub-images).
- /imageN/calibration        — formula `GEO = 0.01*PV + 0` → mm of accumulation /5min.
- /imageN.attrs.image_datetime_valid — 'DD-MMM-YYYY;HH:MM:SS.fff' (UTC).
- Missing values: 65534 (no obs); out-of-grid: 65535.
"""

from __future__ import annotations

import re
from dataclasses import dataclass
from datetime import UTC, datetime
from pathlib import Path

import h5py
import numpy as np
from affine import Affine
from rasterio.crs import CRS

# 5-min accumulation values are mm; multiply by 12 to get mm/h.
_ACCUMULATION_TO_MM_PER_H = 12.0
_MISSING = 65534
_OUT_OF_GRID = 65535
# KNMI ships km units; rasterio reprojection wants metres. Scale by 1000.
_KNMI_PROJ4_M = (
    "+proj=stere +lat_0=90 +lon_0=0 +lat_ts=60 "
    "+a=6378140 +b=6356750 +x_0=0 +y_0=0 +units=m +no_defs"
)
_DATETIME_RE = re.compile(
    r"(?P<day>\d{2})-(?P<mon>[A-Z]{3})-(?P<year>\d{4});(?P<h>\d{2}):(?P<m>\d{2}):(?P<s>\d{2})"
)
_MONTHS = {
    "JAN": 1,
    "FEB": 2,
    "MAR": 3,
    "APR": 4,
    "MAY": 5,
    "JUN": 6,
    "JUL": 7,
    "AUG": 8,
    "SEP": 9,
    "OCT": 10,
    "NOV": 11,
    "DEC": 12,
}


@dataclass(frozen=True, slots=True)
class RadarSubImage:
    """One time-step parsed from a KNMI radar HDF5 file."""

    name: str  # e.g. "image1"
    valid_at: datetime
    mm_per_h: np.ndarray  # (H, W) float32 with NaN for missing/out-of-grid
    transform: Affine
    crs: CRS


def read_radar_hdf5(path: Path) -> list[RadarSubImage]:
    """Read every `imageN` sub-image from a KNMI radar HDF5 file."""
    sub_images: list[RadarSubImage] = []
    with h5py.File(path, "r") as f:
        transform = _read_transform(f)
        crs = CRS.from_proj4(_KNMI_PROJ4_M)
        for name in sorted(f.keys(), key=_image_sort_key):
            if not name.startswith("image"):
                continue
            grp = f[name]
            if not isinstance(grp, h5py.Group) or "image_data" not in grp:
                continue
            sub_images.append(_read_sub_image(name, grp, transform=transform, crs=crs))
    return sub_images


def _image_sort_key(name: str) -> tuple[int, str]:
    """`image2` should sort before `image10` — natural numeric order."""
    m = re.match(r"image(\d+)$", name)
    return (int(m.group(1)) if m else 1_000_000, name)


def _read_transform(f: h5py.File) -> Affine:
    """Build the source affine in metres, anchored at the grid's top-left corner.

    KNMI stores `geo_row_offset` as a positive magnitude (distance from the pole),
    but standard north-pole stereographic places NL at *negative* y (south of the
    pole). We flip the sign so the affine matches the proj4 we hand to rasterio.
    Verified against the published `geo_product_corners` to within ~30 m.
    """
    geo = f["geographic"].attrs
    pixel_size_x_km = float(np.asarray(geo["geo_pixel_size_x"]).item())
    pixel_size_y_km = float(np.asarray(geo["geo_pixel_size_y"]).item())
    column_offset_km = float(np.asarray(geo["geo_column_offset"]).item())
    row_offset_km = float(np.asarray(geo["geo_row_offset"]).item())
    return Affine(
        pixel_size_x_km * 1000.0,
        0.0,
        column_offset_km * 1000.0,
        0.0,
        pixel_size_y_km * 1000.0,
        -row_offset_km * 1000.0,
    )


def _read_sub_image(
    name: str,
    grp: h5py.Group,
    *,
    transform: Affine,
    crs: CRS,
) -> RadarSubImage:
    raw = grp["image_data"][...]
    cal = grp.get("calibration")
    scale, offset = _read_calibration(cal)
    valid_at = _parse_valid_at(grp)

    # mm of accumulation in this 5-min slot:
    mm = raw.astype(np.float32) * scale + offset
    # Missing/out-of-grid → NaN.
    mm = np.where(
        (raw == _MISSING) | (raw == _OUT_OF_GRID),
        np.float32("nan"),
        mm,
    )
    mm_per_h = mm * _ACCUMULATION_TO_MM_PER_H

    return RadarSubImage(
        name=name,
        valid_at=valid_at,
        mm_per_h=mm_per_h,
        transform=transform,
        crs=crs,
    )


def _attr_text(value: object) -> str:
    """Decode an h5py attribute (bytes / np.bytes_ / str / np.ndarray) to str."""
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


def _read_calibration(cal: h5py.Group | None) -> tuple[float, float]:
    """Parse `GEO = scale * PV + offset` from the calibration formula."""
    if cal is None:
        return (0.01, 0.0)
    formula = _attr_text(cal.attrs.get("calibration_formulas"))
    m = re.search(
        r"GEO\s*=\s*(?P<scale>[+-]?\d+(?:\.\d+)?)\s*\*\s*PV\s*"
        r"(?P<sign>[+-])\s*(?P<offset>\d+(?:\.\d+)?)",
        formula,
    )
    if not m:
        return (0.01, 0.0)
    sign = -1.0 if m.group("sign") == "-" else 1.0
    return (float(m.group("scale")), sign * float(m.group("offset")))


def _parse_valid_at(grp: h5py.Group) -> datetime:
    text = _attr_text(grp.attrs.get("image_datetime_valid"))
    if not text:
        raise ValueError(f"{grp.name}: missing image_datetime_valid attribute")
    m = _DATETIME_RE.search(text)
    if not m:
        raise ValueError(f"{grp.name}: cannot parse image_datetime_valid={text!r}")
    return datetime(
        year=int(m.group("year")),
        month=_MONTHS[m.group("mon")],
        day=int(m.group("day")),
        hour=int(m.group("h")),
        minute=int(m.group("m")),
        second=int(m.group("s")),
        tzinfo=UTC,
    )
