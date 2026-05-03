"""GET /api/rain/{lat}/{lon} — input validation + 503 when no data."""

from __future__ import annotations

from collections.abc import AsyncIterator
from pathlib import Path

import httpx
import pytest
from asgi_lifespan import LifespanManager

from openweer.api.app import create_app
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


async def test_rain_503_when_no_radar_file_yet(client: httpx.AsyncClient) -> None:
    r = await client.get("/api/rain/52.37/4.89")
    assert r.status_code == 503
    assert "radar_forecast" in r.text.lower()


@pytest.mark.parametrize(
    "lat, lon",
    [
        (49.99, 4.89),  # too far south
        (54.01, 4.89),  # too far north
        (52.37, 2.99),  # too far west
        (52.37, 8.01),  # too far east
        (-91, 0),  # nonsense
    ],
)
async def test_rain_rejects_out_of_bbox_coordinates(
    client: httpx.AsyncClient, lat: float, lon: float
) -> None:
    r = await client.get(f"/api/rain/{lat}/{lon}")
    assert r.status_code == 422  # FastAPI validation error


async def test_rain_rejects_non_numeric_path(client: httpx.AsyncClient) -> None:
    r = await client.get("/api/rain/abc/def")
    assert r.status_code == 422
