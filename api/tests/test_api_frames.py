"""GET /api/frames — manifest passthrough + caching headers."""

from __future__ import annotations

from collections.abc import AsyncIterator
from datetime import UTC, datetime, timedelta
from pathlib import Path

import httpx
import pytest
from asgi_lifespan import LifespanManager

from openweer.api.app import create_app
from openweer.settings import Settings
from openweer.tiler.manifest import Frame, ManifestStore


@pytest.fixture
async def client(tmp_path: Path) -> AsyncIterator[httpx.AsyncClient]:
    settings = Settings(_env_file=None, OPENWEER_DATA_DIR=tmp_path)  # type: ignore[call-arg]
    app = create_app(settings=settings)
    async with LifespanManager(app):
        async with httpx.AsyncClient(
            transport=httpx.ASGITransport(app=app), base_url="http://test"
        ) as c:
            yield c


async def test_frames_empty_when_no_manifest(client: httpx.AsyncClient) -> None:
    r = await client.get("/api/frames")
    assert r.status_code == 200
    body = r.json()
    assert body["frames"] == []
    assert "generated_at" in body


async def test_frames_returns_written_manifest(client: httpx.AsyncClient, tmp_path: Path) -> None:
    store = ManifestStore(tmp_path / "manifests" / "frames.json")
    base = datetime(2026, 5, 3, 6, 0, tzinfo=UTC)
    frames = [
        Frame(
            id=(base + timedelta(minutes=i * 5)).strftime("%Y%m%dT%H%M") + "Z",
            ts=base + timedelta(minutes=i * 5),
            kind="nowcast",
            cadence_minutes=5,
            max_zoom=10,
        )
        for i in range(3)
    ]
    store.write(frames)

    r = await client.get("/api/frames")
    assert r.status_code == 200
    body = r.json()
    assert len(body["frames"]) == 3
    assert body["frames"][0]["id"] == "20260503T0600Z"
    assert r.headers["cache-control"].startswith("public, max-age=")
