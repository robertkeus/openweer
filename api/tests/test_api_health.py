"""GET /api/health — basic shape + freshness reporting."""

from __future__ import annotations

from collections.abc import AsyncIterator
from datetime import UTC, datetime
from pathlib import Path

import httpx
import pytest
from asgi_lifespan import LifespanManager

from openweer.api.app import create_app
from openweer.ingest.storage import IngestStorage, ManifestEntry
from openweer.knmi.datasets import get_dataset
from openweer.settings import Settings


@pytest.fixture
async def client(tmp_path: Path) -> AsyncIterator[httpx.AsyncClient]:
    settings = Settings(_env_file=None, OPENWEER_DATA_DIR=tmp_path)  # type: ignore[call-arg]
    app = create_app(settings=settings)
    async with LifespanManager(app):
        async with httpx.AsyncClient(
            transport=httpx.ASGITransport(app=app), base_url="http://test"
        ) as c:
            yield c


async def test_health_ok_with_no_data(client: httpx.AsyncClient) -> None:
    r = await client.get("/api/health")
    assert r.status_code == 200
    body = r.json()
    assert body["ok"] is True
    assert body["version"]
    # Each configured dataset has an entry, all currently empty.
    keys = {ds["dataset"] for ds in body["datasets"]}
    assert keys == {"radar_forecast", "radar_observed", "obs_10min", "harmonie"}
    assert all(ds["filename"] is None for ds in body["datasets"])


async def test_health_reflects_ingested_radar_forecast(
    client: httpx.AsyncClient, tmp_path: Path
) -> None:
    storage = IngestStorage(tmp_path)
    radar = get_dataset("radar_forecast")
    storage.write_manifest(
        radar,
        ManifestEntry(
            dataset_name=radar.name,
            dataset_version=radar.version,
            filename="RAD_NL25_RAC_FM_test.h5",
            bytes_written=12345,
            ingested_at=datetime(2026, 5, 3, 6, 30, tzinfo=UTC),
        ),
    )

    r = await client.get("/api/health")
    body = r.json()
    radar_entry = next(ds for ds in body["datasets"] if ds["dataset"] == "radar_forecast")
    assert radar_entry["filename"] == "RAD_NL25_RAC_FM_test.h5"
    assert radar_entry["ingested_at"].startswith("2026-05-03T06:30")
