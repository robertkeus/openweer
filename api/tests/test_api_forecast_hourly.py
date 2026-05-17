"""GET /api/forecast/{lat}/{lon}/hourly — hybrid HARMONIE + ECMWF hourly forecast."""

from __future__ import annotations

from collections.abc import AsyncIterator
from pathlib import Path

import httpx
import pytest
import respx
from asgi_lifespan import LifespanManager

from openweer.api.app import create_app
from openweer.api.routes.forecast_hourly import _reset_hourly_cache_for_tests
from openweer.settings import Settings


@pytest.fixture(autouse=True)
def _clear_cache() -> None:
    _reset_hourly_cache_for_tests()


@pytest.fixture
async def client(tmp_path: Path) -> AsyncIterator[httpx.AsyncClient]:
    settings = Settings(_env_file=None, OPENWEER_DATA_DIR=tmp_path)  # type: ignore[call-arg]
    app = create_app(settings=settings)
    async with LifespanManager(app):
        async with httpx.AsyncClient(
            transport=httpx.ASGITransport(app=app), base_url="http://test"
        ) as c:
            yield c


def _iso_hours(start_date: str, count: int) -> list[str]:
    """Return `count` ISO-8601 hour-strings starting at `start_date`T00:00."""
    from datetime import datetime, timedelta

    base = datetime.fromisoformat(f"{start_date}T00:00")
    return [(base + timedelta(hours=h)).isoformat(timespec="minutes") for h in range(count)]


def _harmonie_payload(start: str = "2026-05-04", hours: int = 72) -> dict:
    return {
        "hourly": {
            "time": _iso_hours(start, hours),
            "temperature_2m": [10.0 + (h % 12) for h in range(hours)],
            "apparent_temperature": [9.0 + (h % 12) for h in range(hours)],
            "weathercode": [3 if h % 5 else 61 for h in range(hours)],
            "precipitation": [0.0 if h % 5 else 0.4 for h in range(hours)],
            "precipitation_probability": [None] * hours,
            "windspeed_10m": [12.0 + (h % 8) for h in range(hours)],
            "winddirection_10m": [240 + (h % 30) for h in range(hours)],
            "windgusts_10m": [20.0 + (h % 10) for h in range(hours)],
            "relative_humidity_2m": [70 + (h % 20) for h in range(hours)],
            "cloudcover": [50 + (h % 40) for h in range(hours)],
            "uv_index": [max(0.0, 5.0 - abs(12 - (h % 24)) / 2.5) for h in range(hours)],
            "is_day": [1 if 6 <= (h % 24) < 21 else 0 for h in range(hours)],
        }
    }


def _ecmwf_payload(start: str = "2026-05-04", hours: int = 192) -> dict:
    return {
        "hourly": {
            "time": _iso_hours(start, hours),
            "temperature_2m": [8.0 + (h % 10) for h in range(hours)],
            "apparent_temperature": [7.0 + (h % 10) for h in range(hours)],
            "weathercode": [2 for _ in range(hours)],
            "precipitation": [0.0 for _ in range(hours)],
            "precipitation_probability": [10 + (h % 60) for h in range(hours)],
            "windspeed_10m": [10.0 + (h % 12) for h in range(hours)],
            "winddirection_10m": [220 + (h % 40) for h in range(hours)],
            "windgusts_10m": [18.0 + (h % 10) for h in range(hours)],
            "relative_humidity_2m": [65 + (h % 25) for h in range(hours)],
            "cloudcover": [40 + (h % 50) for h in range(hours)],
            "uv_index": [max(0.0, 4.5 - abs(12 - (h % 24)) / 2.5) for h in range(hours)],
            "is_day": [1 if 6 <= (h % 24) < 21 else 0 for h in range(hours)],
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
async def test_hourly_merges_harmonie_first_then_ecmwf(
    client: httpx.AsyncClient,
) -> None:
    route = _mock_both()
    r = await client.get("/api/forecast/52.37/4.89/hourly")
    assert r.status_code == 200
    data = r.json()
    assert data["source"] == "knmi-harmonie+ecmwf"
    assert data["timezone"] == "Europe/Amsterdam"
    hours = data["hours"]
    assert len(hours) == 192  # 8 days * 24 hours from ECMWF

    # First 72 hours: HARMONIE-sourced.
    assert all(h["source"] == "knmi-harmonie" for h in hours[:72])
    # Remaining: ECMWF-sourced.
    assert all(h["source"] == "ecmwf" for h in hours[72:])

    # HARMONIE temperature applied (10.0 + (0 % 12) = 10.0).
    assert hours[0]["temperature_c"] == 10.0
    # ECMWF temperature applied at the boundary (8.0 + (72 % 10) = 10.0).
    assert hours[72]["temperature_c"] == 10.0

    # Two upstream calls: HARMONIE + ECMWF.
    assert route.call_count == 2


@respx.mock
async def test_hourly_probability_always_from_ecmwf(
    client: httpx.AsyncClient,
) -> None:
    _mock_both()
    r = await client.get("/api/forecast/52.37/4.89/hourly")
    assert r.status_code == 200
    hours = r.json()["hours"]
    # Even though HARMONIE returned `None` probability, HARMONIE-sourced
    # slots carry ECMWF's value (10 + (0 % 60) = 10).
    assert hours[0]["source"] == "knmi-harmonie"
    assert hours[0]["precipitation_probability_pct"] == 10
    assert hours[5]["precipitation_probability_pct"] == 15


@respx.mock
async def test_hourly_falls_back_to_ecmwf_only(
    client: httpx.AsyncClient,
) -> None:
    """If HARMONIE fails, all hours come from ECMWF."""

    def _side_effect(request: httpx.Request) -> httpx.Response:
        model = request.url.params.get("models", "")
        if "harmonie" in model:
            return httpx.Response(502)
        return httpx.Response(200, json=_ecmwf_payload())

    respx.get("https://api.open-meteo.com/v1/forecast").mock(
        side_effect=_side_effect
    )
    r = await client.get("/api/forecast/52.37/4.89/hourly")
    assert r.status_code == 200
    data = r.json()
    assert all(h["source"] == "ecmwf" for h in data["hours"])
    assert data["hours"][0]["temperature_c"] == 8.0


@respx.mock
async def test_hourly_503_when_ecmwf_fails(
    client: httpx.AsyncClient,
) -> None:
    respx.get("https://api.open-meteo.com/v1/forecast").mock(
        return_value=httpx.Response(502)
    )
    r = await client.get("/api/forecast/52.37/4.89/hourly")
    assert r.status_code == 503
    assert "per-uur" in r.text.lower()


@respx.mock
async def test_hourly_caches_merged_result(
    client: httpx.AsyncClient,
) -> None:
    route = _mock_both()
    r1 = await client.get("/api/forecast/52.37/4.89/hourly")
    r2 = await client.get("/api/forecast/52.37/4.89/hourly")
    assert r1.status_code == 200 and r2.status_code == 200
    # Second hit served from cache → upstream called twice total (once per model).
    assert route.call_count == 2


@respx.mock
async def test_hourly_returns_192_hours(
    client: httpx.AsyncClient,
) -> None:
    _mock_both()
    r = await client.get("/api/forecast/52.37/4.89/hourly")
    assert r.status_code == 200
    hours = r.json()["hours"]
    assert len(hours) == 192  # 8 days × 24 hours


@pytest.mark.parametrize(
    "lat, lon",
    [
        (49.99, 4.89),  # too far south
        (54.01, 4.89),  # too far north
        (52.37, 2.99),  # too far west
        (52.37, 8.01),  # too far east
    ],
)
async def test_hourly_rejects_out_of_bbox(
    client: httpx.AsyncClient, lat: float, lon: float
) -> None:
    r = await client.get(f"/api/forecast/{lat}/{lon}/hourly")
    assert r.status_code == 422
