"""GET /api/forecast/{lat}/{lon} — hybrid HARMONIE + ECMWF forecast."""

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


def _harmonie_payload() -> dict:
    return {
        "daily": {
            "time": ["2026-05-04", "2026-05-05", "2026-05-06"],
            "weathercode": [3, 61, None],
            "temperature_2m_max": [18.4, 16.0, None],
            "temperature_2m_min": [9.1, 8.7, None],
            "precipitation_sum": [0.0, 4.2, None],
            "precipitation_probability_max": [None, None, None],
            "windspeed_10m_max": [18.5, 24.1, None],
            "winddirection_10m_dominant": [270, 230, None],
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


def _ecmwf_payload() -> dict:
    return {
        "daily": {
            "time": ["2026-05-04", "2026-05-05", "2026-05-06"],
            "weathercode": [2, 60, 95],
            "temperature_2m_max": [17.0, 15.0, 14.2],
            "temperature_2m_min": [8.0, 7.5, 7.0],
            "precipitation_sum": [0.0, 3.0, 11.5],
            "precipitation_probability_max": [10, 70, 95],
            "windspeed_10m_max": [17.0, 22.0, 35.0],
            "winddirection_10m_dominant": [260, 220, 180],
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


def _mock_both() -> respx.Route:
    """Mock the Open-Meteo endpoint for both HARMONIE and ECMWF requests."""

    def _side_effect(request: httpx.Request) -> httpx.Response:
        model = request.url.params.get("models", "")
        if "harmonie" in model:
            return httpx.Response(200, json=_harmonie_payload())
        return httpx.Response(200, json=_ecmwf_payload())

    return respx.get("https://api.open-meteo.com/v1/forecast").mock(
        side_effect=_side_effect
    )


@respx.mock
async def test_forecast_uses_harmonie_for_short_range(
    client: httpx.AsyncClient,
) -> None:
    route = _mock_both()
    r = await client.get("/api/forecast/52.37/4.89")
    assert r.status_code == 200
    data = r.json()
    assert data["source"] == "knmi-harmonie+ecmwf"
    assert len(data["days"]) == 3
    # Day 1-2: HARMONIE values (higher than ECMWF mock).
    assert data["days"][0]["temperature_max_c"] == 18.4
    assert data["days"][0]["source"] == "knmi-harmonie"
    assert data["days"][1]["temperature_max_c"] == 16.0
    assert data["days"][1]["source"] == "knmi-harmonie"
    # Day 3: HARMONIE is null → ECMWF fallback.
    assert data["days"][2]["temperature_max_c"] == 14.2
    assert data["days"][2]["source"] == "ecmwf"
    # Precipitation probability always from ECMWF.
    assert data["days"][0]["precipitation_probability_pct"] == 10
    assert data["days"][1]["precipitation_probability_pct"] == 70
    # Two upstream calls: HARMONIE + ECMWF.
    assert route.call_count == 2


@respx.mock
async def test_forecast_caches_merged_result(
    client: httpx.AsyncClient,
) -> None:
    route = _mock_both()
    r1 = await client.get("/api/forecast/52.37/4.89")
    r2 = await client.get("/api/forecast/52.37/4.89")
    assert r1.status_code == 200 and r2.status_code == 200
    # Second hit served from cache → upstream called twice total (once per model).
    assert route.call_count == 2


@respx.mock
async def test_forecast_falls_back_to_ecmwf_only(
    client: httpx.AsyncClient,
) -> None:
    """If HARMONIE fails, all days come from ECMWF."""

    def _side_effect(request: httpx.Request) -> httpx.Response:
        model = request.url.params.get("models", "")
        if "harmonie" in model:
            return httpx.Response(502)
        return httpx.Response(200, json=_ecmwf_payload())

    respx.get("https://api.open-meteo.com/v1/forecast").mock(
        side_effect=_side_effect
    )
    r = await client.get("/api/forecast/52.37/4.89")
    assert r.status_code == 200
    data = r.json()
    assert all(d["source"] == "ecmwf" for d in data["days"])
    assert data["days"][0]["temperature_max_c"] == 17.0


@respx.mock
async def test_forecast_503_when_ecmwf_fails(
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
