"""Rain alert evaluator — pure logic tests with stubbed nowcast samples."""

from __future__ import annotations

from collections.abc import Sequence
from datetime import UTC, datetime
from pathlib import Path

import pytest

from openweer.devices import evaluator
from openweer.devices.evaluator import evaluate
from openweer.devices.models import AlertPrefs, Favorite
from openweer.devices.repository import DeviceWithFavorites
from openweer.forecast.rain_2h import RainNowcast, RainSample

NOW = datetime(2026, 5, 16, 14, 0, tzinfo=UTC)


def _favorite(
    *,
    favorite_id: int = 1,
    label: str = "Home",
    lat: float = 52.37,
    lon: float = 4.89,
    lead: int = 30,
    threshold: str = "moderate",
    quiet_start: int | None = None,
    quiet_end: int | None = None,
) -> Favorite:
    return Favorite(
        favorite_id=favorite_id,
        label=label,
        latitude=lat,
        longitude=lon,
        alert_prefs=AlertPrefs(
            lead_time_min=lead,
            threshold=threshold,  # type: ignore[arg-type]
            quiet_hours_start=quiet_start,
            quiet_hours_end=quiet_end,
        ),
        created_at=NOW,
    )


def _device(*, device_id: str = "dev", favorites: list[Favorite]) -> DeviceWithFavorites:
    return DeviceWithFavorites(device_id=device_id, language="nl", favorites=tuple(favorites))


def _samples(intensities: Sequence[float]) -> tuple[RainSample, ...]:
    """Build a nowcast from a sequence of mm/h values, one per 5-min sample."""
    return tuple(
        RainSample(
            minutes_ahead=i * 5,
            mm_per_h=mm,
            valid_at=NOW.replace(minute=(NOW.minute + i * 5) % 60),
        )
        for i, mm in enumerate(intensities)
    )


def _patch_nowcast(
    monkeypatch: pytest.MonkeyPatch,
    points_to_samples: dict[tuple[float, float], Sequence[float]],
) -> None:
    def fake(_path: Path, points: Sequence[tuple[float, float]]) -> list[RainNowcast]:
        result: list[RainNowcast] = []
        for lat, lon in points:
            mm = points_to_samples[(round(lat, 2), round(lon, 2))]
            result.append(
                RainNowcast(
                    lat=lat, lon=lon, analysis_at=NOW, samples=_samples(mm),
                )
            )
        return result

    monkeypatch.setattr(evaluator, "sample_rain_nowcasts", fake)


def test_alert_fires_when_threshold_met_within_lead_window(
    monkeypatch: pytest.MonkeyPatch, tmp_path: Path
) -> None:
    # 30 min lead → samples 0,5,10,15,20,25,30. Rain at 15 min crosses moderate.
    _patch_nowcast(monkeypatch, {(52.37, 4.89): [0, 0, 0, 1.5, 2.0, 2.0, 1.0]})
    alerts = evaluate(
        hdf5_path=tmp_path / "x.h5",
        devices=[_device(favorites=[_favorite(lead=30, threshold="moderate")])],
        now=NOW,
    )
    assert len(alerts) == 1
    assert alerts[0].lead_minutes == 15
    assert alerts[0].intensity == "moderate"


def test_no_alert_below_threshold(
    monkeypatch: pytest.MonkeyPatch, tmp_path: Path
) -> None:
    _patch_nowcast(monkeypatch, {(52.37, 4.89): [0, 0.05, 0.05, 0.08, 0.05, 0, 0]})
    alerts = evaluate(
        hdf5_path=tmp_path / "x.h5",
        devices=[_device(favorites=[_favorite(lead=30, threshold="light")])],
        now=NOW,
    )
    assert alerts == []


def test_alert_ignores_samples_past_lead_window(
    monkeypatch: pytest.MonkeyPatch, tmp_path: Path
) -> None:
    # Threshold met at +45 min but lead window is 30. No alert.
    _patch_nowcast(
        monkeypatch,
        {(52.37, 4.89): [0, 0, 0, 0, 0, 0, 0, 0, 0, 5.0]},
    )
    alerts = evaluate(
        hdf5_path=tmp_path / "x.h5",
        devices=[_device(favorites=[_favorite(lead=30, threshold="moderate")])],
        now=NOW,
    )
    assert alerts == []


def test_heavy_intensity_classification(
    monkeypatch: pytest.MonkeyPatch, tmp_path: Path
) -> None:
    _patch_nowcast(monkeypatch, {(52.37, 4.89): [0, 0, 5.0, 5.0]})
    alerts = evaluate(
        hdf5_path=tmp_path / "x.h5",
        devices=[_device(favorites=[_favorite(lead=15, threshold="light")])],
        now=NOW,
    )
    assert alerts[0].intensity == "heavy"


def test_quiet_hours_suppress_alert(
    monkeypatch: pytest.MonkeyPatch, tmp_path: Path
) -> None:
    _patch_nowcast(monkeypatch, {(52.37, 4.89): [0, 0, 2.0, 2.0]})
    # NOW is 14:00 UTC; quiet hours 13–15 cover it.
    fav = _favorite(quiet_start=13, quiet_end=15)
    alerts = evaluate(
        hdf5_path=tmp_path / "x.h5",
        devices=[_device(favorites=[fav])],
        now=NOW,
    )
    assert alerts == []


def test_quiet_hours_wrap_midnight(
    monkeypatch: pytest.MonkeyPatch, tmp_path: Path
) -> None:
    _patch_nowcast(monkeypatch, {(52.37, 4.89): [0, 0, 2.0, 2.0]})
    midnight = NOW.replace(hour=2)
    fav = _favorite(quiet_start=22, quiet_end=7)
    alerts = evaluate(
        hdf5_path=tmp_path / "x.h5",
        devices=[_device(favorites=[fav])],
        now=midnight,
    )
    assert alerts == []


def test_dedupe_key_is_stable_for_same_bucket(
    monkeypatch: pytest.MonkeyPatch, tmp_path: Path
) -> None:
    _patch_nowcast(monkeypatch, {(52.37, 4.89): [0, 0, 2.0, 2.0, 2.0]})
    a = evaluate(
        hdf5_path=tmp_path / "x.h5",
        devices=[_device(favorites=[_favorite()])],
        now=NOW,
    )
    b = evaluate(
        hdf5_path=tmp_path / "x.h5",
        devices=[_device(favorites=[_favorite()])],
        now=NOW,
    )
    assert a[0].dedupe_key == b[0].dedupe_key


def test_multi_device_batched_sampling(
    monkeypatch: pytest.MonkeyPatch, tmp_path: Path
) -> None:
    _patch_nowcast(
        monkeypatch,
        {
            (52.37, 4.89): [0, 0, 3.0],
            (52.09, 5.12): [0, 0, 0],
        },
    )
    devices = [
        _device(device_id="a", favorites=[_favorite(favorite_id=1, lat=52.37, lon=4.89)]),
        _device(
            device_id="b",
            favorites=[_favorite(favorite_id=2, lat=52.09, lon=5.12, label="Werk")],
        ),
    ]
    alerts = evaluate(hdf5_path=tmp_path / "x.h5", devices=devices, now=NOW)
    assert len(alerts) == 1
    assert alerts[0].device_id == "a"
