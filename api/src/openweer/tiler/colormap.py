"""Rain-rate colormap (mm/h → RGBA).

Reads monotonically from "barely raining" to "exceptional": three blue
tiers for the light end (water = blue), then yellow / orange / red for
the heavy bands, and magenta for exceptional. Green is deliberately
absent because mid-spectrum green pops perceptually and misleads users
into reading it as the peak. Below 0.1 mm/h is fully transparent so the
basemap shines through dry pixels (NaN is treated the same as dry).
"""

from __future__ import annotations

from typing import Final

import numpy as np

# (lower_bound_mm_per_h, R, G, B, A). The first row's lower bound is the cutoff
# below which pixels are fully transparent.
_STOPS: Final[tuple[tuple[float, int, int, int, int], ...]] = (
    (0.0, 0, 0, 0, 0),
    (0.1, 155, 195, 241, 130),
    (0.5, 92, 142, 232, 180),
    (1.0, 31, 93, 208, 220),
    (2.0, 245, 213, 45, 240),
    (5.0, 245, 159, 45, 250),
    (10.0, 230, 53, 61, 255),
    (20.0, 163, 21, 31, 255),
    (50.0, 192, 38, 211, 255),
)

#: Public, read-only view of the colormap stops for documentation/inspection.
RAIN_COLORMAP: Final = _STOPS


def apply_rain_colormap(mm_per_h: np.ndarray) -> np.ndarray:
    """Map an (H, W) float array of mm/h into an (H, W, 4) uint8 RGBA image.

    NaN values are rendered fully transparent. Negative values are clamped to 0.
    """
    if mm_per_h.ndim != 2:
        raise ValueError(f"Expected 2D array, got shape {mm_per_h.shape}")

    height, width = mm_per_h.shape
    rgba = np.zeros((height, width, 4), dtype=np.uint8)

    safe = np.where(np.isnan(mm_per_h), 0.0, mm_per_h)
    safe = np.clip(safe, 0.0, np.inf)

    bounds = np.array([s[0] for s in _STOPS], dtype=np.float32)
    colors = np.array([s[1:] for s in _STOPS], dtype=np.uint8)

    # `np.searchsorted` returns the index where `safe` would be inserted; using
    # side="right" then subtracting 1 gives us the largest stop ≤ safe.
    idx = np.searchsorted(bounds, safe, side="right") - 1
    idx = np.clip(idx, 0, len(_STOPS) - 1)
    rgba[:] = colors[idx]

    # NaNs are forced transparent.
    rgba[np.isnan(mm_per_h)] = (0, 0, 0, 0)
    return rgba
