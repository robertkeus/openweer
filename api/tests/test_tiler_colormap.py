"""Rain colormap tests — bounds, NaN handling, output shape."""

from __future__ import annotations

import numpy as np
import pytest

from openweer.tiler.colormap import RAIN_COLORMAP, apply_rain_colormap


def test_below_threshold_is_transparent() -> None:
    rgba = apply_rain_colormap(np.array([[0.0, 0.05, 0.099]], dtype=np.float32))
    assert (rgba[..., 3] == 0).all()


def test_nan_is_fully_transparent() -> None:
    rgba = apply_rain_colormap(np.array([[np.nan, 1.0]], dtype=np.float32))
    assert tuple(rgba[0, 0]) == (0, 0, 0, 0)
    assert rgba[0, 1, 3] > 0  # the 1.0 mm/h pixel is opaque enough to be visible


@pytest.mark.parametrize(
    "value, expected_rgb",
    [
        (0.2, (155, 195, 241)),
        (0.7, (92, 142, 232)),
        (1.5, (31, 93, 208)),
        (3.0, (45, 184, 74)),
        (8.0, (245, 213, 45)),
        (15.0, (245, 159, 45)),
        (30.0, (230, 53, 61)),
        (75.0, (192, 38, 211)),
    ],
)
def test_each_band_gets_its_color(value: float, expected_rgb: tuple[int, int, int]) -> None:
    rgba = apply_rain_colormap(np.array([[value]], dtype=np.float32))
    assert tuple(rgba[0, 0, :3]) == expected_rgb


def test_2d_shape_in_2d_shape_out() -> None:
    src = np.zeros((10, 12), dtype=np.float32)
    out = apply_rain_colormap(src)
    assert out.shape == (10, 12, 4)
    assert out.dtype == np.uint8


def test_3d_input_rejected() -> None:
    with pytest.raises(ValueError, match="2D"):
        apply_rain_colormap(np.zeros((4, 4, 1), dtype=np.float32))


def test_negative_values_clamp_to_zero() -> None:
    rgba = apply_rain_colormap(np.array([[-3.0, -0.001]], dtype=np.float32))
    assert (rgba[..., 3] == 0).all()


def test_colormap_constant_is_immutable_view() -> None:
    # We expose RAIN_COLORMAP for documentation; ensure tuples-of-tuples (immutable).
    assert isinstance(RAIN_COLORMAP, tuple)
    assert all(isinstance(s, tuple) for s in RAIN_COLORMAP)
