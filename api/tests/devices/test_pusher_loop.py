"""PusherLoop._tick — happy path with stubbed evaluator + APNs."""

from __future__ import annotations

from collections.abc import AsyncIterator
from dataclasses import dataclass, field
from datetime import UTC, datetime
from pathlib import Path

import pytest

from openweer.devices import evaluator
from openweer.devices.evaluator import Alert
from openweer.devices.models import AlertPrefs, FavoriteIn
from openweer.devices.repository import DeviceRepository
from openweer.devices.worker import PusherLoop
from openweer.forecast.rain_2h import RainNowcast, RainSample
from openweer.ingest.storage import IngestStorage, ManifestEntry
from openweer.knmi.datasets import get_dataset

RADAR = get_dataset("radar_forecast")
NOW = datetime(2026, 5, 16, 14, 0, tzinfo=UTC)


@dataclass
class FakeApns:
    sent: list[Alert] = field(default_factory=list)
    response: bool = True

    @property
    def configured(self) -> bool:
        return True

    async def send(self, alert: Alert, *, on_terminal) -> bool:  # type: ignore[no-untyped-def]
        self.sent.append(alert)
        return self.response


@pytest.fixture
async def repo(tmp_path: Path) -> AsyncIterator[DeviceRepository]:
    r = DeviceRepository.open(tmp_path / "devices.db")
    yield r
    r.close()


def _stub_nowcast(monkeypatch: pytest.MonkeyPatch, mm_per_h: list[float]) -> None:
    def fake(_path: Path, points):  # type: ignore[no-untyped-def]
        return [
            RainNowcast(
                lat=lat,
                lon=lon,
                analysis_at=NOW,
                samples=tuple(
                    RainSample(
                        minutes_ahead=i * 5,
                        mm_per_h=mm,
                        valid_at=NOW.replace(minute=(NOW.minute + i * 5) % 60),
                    )
                    for i, mm in enumerate(mm_per_h)
                ),
            )
            for lat, lon in points
        ]

    monkeypatch.setattr(evaluator, "sample_rain_nowcasts", fake)


def _seed_radar_manifest(storage: IngestStorage) -> Path:
    """Create an empty radar HDF5 file + manifest so PusherLoop finds something."""
    filename = "RAD_NL25_RAP_FM_202605161400.h5"
    raw = storage.raw_path(RADAR, filename)
    raw.parent.mkdir(parents=True, exist_ok=True)
    raw.write_bytes(b"")  # contents don't matter — sampler is stubbed
    storage.write_manifest(
        RADAR,
        ManifestEntry(
            dataset_name=RADAR.name,
            dataset_version=RADAR.version,
            filename=filename,
            bytes_written=0,
        ),
    )
    return raw


async def test_tick_sends_pushes_for_matching_favorites(
    tmp_path: Path, repo: DeviceRepository, monkeypatch: pytest.MonkeyPatch
) -> None:
    storage = IngestStorage(tmp_path)
    _seed_radar_manifest(storage)
    _stub_nowcast(monkeypatch, [0, 0, 2.0, 2.0])

    token = "a" * 64
    await repo.upsert_device(device_id=token, platform="ios", language="nl", app_version=None)
    await repo.replace_favorites(
        device_id=token,
        favorites=[
            FavoriteIn(
                label="Home",
                latitude=52.37,
                longitude=4.89,
                alert_prefs=AlertPrefs(lead_time_min=30, threshold="moderate"),
            )
        ],
    )

    apns = FakeApns()
    loop = PusherLoop(repository=repo, apns=apns, storage=storage)  # type: ignore[arg-type]
    await loop._tick()

    assert len(apns.sent) == 1
    assert apns.sent[0].device_id == token


async def test_tick_dedupes_within_window(
    tmp_path: Path, repo: DeviceRepository, monkeypatch: pytest.MonkeyPatch
) -> None:
    storage = IngestStorage(tmp_path)
    _seed_radar_manifest(storage)
    _stub_nowcast(monkeypatch, [0, 0, 2.0, 2.0])

    token = "b" * 64
    await repo.upsert_device(device_id=token, platform="ios", language="nl", app_version=None)
    await repo.replace_favorites(
        device_id=token,
        favorites=[FavoriteIn(label="Home", latitude=52.37, longitude=4.89)],
    )

    apns = FakeApns()
    loop = PusherLoop(repository=repo, apns=apns, storage=storage)  # type: ignore[arg-type]
    await loop._tick()
    await loop._tick()  # second tick should not re-send

    assert len(apns.sent) == 1


async def test_tick_skips_when_no_nowcast(
    tmp_path: Path, repo: DeviceRepository
) -> None:
    storage = IngestStorage(tmp_path)  # no manifest seeded
    apns = FakeApns()
    loop = PusherLoop(repository=repo, apns=apns, storage=storage)  # type: ignore[arg-type]
    await loop._tick()
    assert apns.sent == []


async def test_tick_skips_when_no_favorites(
    tmp_path: Path, repo: DeviceRepository, monkeypatch: pytest.MonkeyPatch
) -> None:
    storage = IngestStorage(tmp_path)
    _seed_radar_manifest(storage)
    _stub_nowcast(monkeypatch, [0, 0, 2.0])

    token = "c" * 64
    await repo.upsert_device(device_id=token, platform="ios", language="nl", app_version=None)

    apns = FakeApns()
    loop = PusherLoop(repository=repo, apns=apns, storage=storage)  # type: ignore[arg-type]
    await loop._tick()
    assert apns.sent == []
