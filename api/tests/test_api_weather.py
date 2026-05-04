"""GET /api/weather/{lat}/{lon} — input validation + 503 when no data yet."""

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


async def test_weather_503_when_no_observations_yet(
    client: httpx.AsyncClient,
) -> None:
    r = await client.get("/api/weather/52.37/4.89")
    assert r.status_code == 503
    assert "waarnemingen" in r.text.lower()


@pytest.mark.parametrize(
    "lat, lon",
    [
        (49.99, 4.89),  # too far south
        (54.01, 4.89),  # too far north
        (52.37, 2.99),  # too far west
        (52.37, 8.01),  # too far east
    ],
)
async def test_weather_rejects_out_of_bbox(
    client: httpx.AsyncClient, lat: float, lon: float
) -> None:
    r = await client.get(f"/api/weather/{lat}/{lon}")
    assert r.status_code == 422
