"""GET /api/forecast/{lat}/{lon} — Open-Meteo proxy + cache."""

from __future__ import annotations

from collections.abc import AsyncIterator
from pathlib import Path

import httpx
import pytest
import respx
from asgi_lifespan import LifespanManager

from openweer.api.app import create_app
from openweer.api.routes.forecast import _reset_cache_for_tests
from openweer.settings import Settings


@pytest.fixture(autouse=True)
def _clear_cache() -> None:
    _reset_cache_for_tests()


@pytest.fixture
async def client(tmp_path: Path) -> AsyncIterator[httpx.AsyncClient]:
    settings = Settings(_env_file=None, OPENWEER_DATA_DIR=tmp_path)  # type: ignore[call-arg]
    app = create_app(settings=settings)
    async with LifespanManager(app):
        async with httpx.AsyncClient(
            transport=httpx.ASGITransport(app=app), base_url="http://test"
        ) as c:
            yield c


def _open_meteo_payload() -> dict:
    return {
        "daily": {
            "time": ["2026-05-04", "2026-05-05", "2026-05-06"],
            "weathercode": [3, 61, 95],
            "temperature_2m_max": [18.4, 16.0, 14.2],
            "temperature_2m_min": [9.1, 8.7, 7.0],
            "precipitation_sum": [0.0, 4.2, 11.5],
            "precipitation_probability_max": [10, 70, 95],
            "windspeed_10m_max": [18.5, 24.1, 35.0],
            "winddirection_10m_dominant": [270, 230, 180],
            "sunrise": [
                "2026-05-04T06:05",
                "2026-05-05T06:03",
                "2026-05-06T06:01",
            ],
            "sunset": [
                "2026-05-04T21:00",
                "2026-05-05T21:01",
                "2026-05-06T21:03",
            ],
        }
    }


@respx.mock
async def test_forecast_returns_8_days_from_open_meteo(
    client: httpx.AsyncClient,
) -> None:
    route = respx.get("https://api.open-meteo.com/v1/forecast").mock(
        return_value=httpx.Response(200, json=_open_meteo_payload())
    )
    r = await client.get("/api/forecast/52.37/4.89")
    assert r.status_code == 200
    data = r.json()
    assert data["source"] == "open-meteo"
    assert len(data["days"]) == 3
    assert data["days"][0]["temperature_max_c"] == 18.4
    assert data["days"][1]["precipitation_probability_pct"] == 70
    assert data["days"][2]["weather_code"] == 95
    # Coordinates were rounded to 2dp in the request.
    last = route.calls.last.request
    assert "latitude=52.37" in str(last.url)
    assert "forecast_days=8" in str(last.url)


@respx.mock
async def test_forecast_caches_15_minutes(
    client: httpx.AsyncClient,
) -> None:
    route = respx.get("https://api.open-meteo.com/v1/forecast").mock(
        return_value=httpx.Response(200, json=_open_meteo_payload())
    )
    r1 = await client.get("/api/forecast/52.37/4.89")
    r2 = await client.get("/api/forecast/52.37/4.89")
    assert r1.status_code == 200 and r2.status_code == 200
    # Second hit served from cache → upstream called once.
    assert route.call_count == 1


@respx.mock
async def test_forecast_503_when_upstream_fails(
    client: httpx.AsyncClient,
) -> None:
    respx.get("https://api.open-meteo.com/v1/forecast").mock(
        return_value=httpx.Response(502)
    )
    r = await client.get("/api/forecast/52.37/4.89")
    assert r.status_code == 503
    assert "verwachting" in r.text.lower()


@pytest.mark.parametrize(
    "lat, lon",
    [
        (49.99, 4.89),  # too far south
        (54.01, 4.89),  # too far north
        (52.37, 2.99),  # too far west
        (52.37, 8.01),  # too far east
    ],
)
async def test_forecast_rejects_out_of_bbox(
    client: httpx.AsyncClient, lat: float, lon: float
) -> None:
    r = await client.get(f"/api/forecast/{lat}/{lon}")
    assert r.status_code == 422
