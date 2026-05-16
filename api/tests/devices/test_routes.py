"""/api/devices, /api/devices/{token}, /api/devices/{token}/favorites — integration tests."""

from __future__ import annotations

from collections.abc import AsyncIterator
from pathlib import Path

import httpx
import pytest
from asgi_lifespan import LifespanManager

from openweer.api.app import create_app
from openweer.settings import Settings

TOKEN = "a" * 64


@pytest.fixture
async def client(tmp_path: Path) -> AsyncIterator[httpx.AsyncClient]:
    settings = Settings(_env_file=None, OPENWEER_DATA_DIR=tmp_path)  # type: ignore[call-arg]
    app = create_app(settings=settings)
    async with LifespanManager(app):
        async with httpx.AsyncClient(
            transport=httpx.ASGITransport(app=app), base_url="http://test"
        ) as c:
            yield c


async def test_register_device_returns_empty_favorites(client: httpx.AsyncClient) -> None:
    r = await client.post(
        "/api/devices",
        json={"token": TOKEN, "platform": "ios", "language": "nl", "app_version": "1.0.0"},
    )
    assert r.status_code == 200
    body = r.json()
    assert body["device_id"] == TOKEN
    assert body["favorites"] == []


async def test_register_rejects_non_hex_token(client: httpx.AsyncClient) -> None:
    r = await client.post(
        "/api/devices",
        json={"token": "not-hex!", "platform": "ios", "language": "nl"},
    )
    assert r.status_code == 422


async def test_put_favorites_round_trip(client: httpx.AsyncClient) -> None:
    await client.post(
        "/api/devices",
        json={"token": TOKEN, "platform": "ios", "language": "nl"},
    )
    payload = {
        "favorites": [
            {
                "label": "Home",
                "latitude": 52.37345,
                "longitude": 4.89234,
                "alert_prefs": {
                    "lead_time_min": 30,
                    "threshold": "moderate",
                    "quiet_hours_start": 22,
                    "quiet_hours_end": 7,
                },
            },
            {
                "label": "Werk",
                "latitude": 52.09,
                "longitude": 5.12,
            },
        ]
    }
    r = await client.put(f"/api/devices/{TOKEN}/favorites", json=payload)
    assert r.status_code == 200, r.text
    favs = r.json()["favorites"]
    assert [f["label"] for f in favs] == ["Home", "Werk"]
    # Coords rounded to 2 decimals at the API boundary.
    assert favs[0]["latitude"] == 52.37
    assert favs[0]["longitude"] == 4.89


async def test_put_favorites_rejects_oversize_list(client: httpx.AsyncClient) -> None:
    await client.post("/api/devices", json={"token": TOKEN, "platform": "ios"})
    payload = {
        "favorites": [
            {"label": f"Plek {i}", "latitude": 52.37, "longitude": 4.89}
            for i in range(6)
        ]
    }
    r = await client.put(f"/api/devices/{TOKEN}/favorites", json=payload)
    assert r.status_code == 400


async def test_put_favorites_rejects_out_of_bbox(client: httpx.AsyncClient) -> None:
    await client.post("/api/devices", json={"token": TOKEN, "platform": "ios"})
    payload = {"favorites": [{"label": "Berlin", "latitude": 52.52, "longitude": 13.40}]}
    r = await client.put(f"/api/devices/{TOKEN}/favorites", json=payload)
    assert r.status_code == 422


async def test_put_favorites_requires_known_device(client: httpx.AsyncClient) -> None:
    r = await client.put(
        f"/api/devices/{TOKEN}/favorites",
        json={"favorites": [{"label": "Home", "latitude": 52.37, "longitude": 4.89}]},
    )
    assert r.status_code == 404


async def test_get_device_returns_favorites(client: httpx.AsyncClient) -> None:
    await client.post("/api/devices", json={"token": TOKEN, "platform": "ios"})
    await client.put(
        f"/api/devices/{TOKEN}/favorites",
        json={"favorites": [{"label": "Home", "latitude": 52.37, "longitude": 4.89}]},
    )
    r = await client.get(f"/api/devices/{TOKEN}")
    assert r.status_code == 200
    assert r.json()["favorites"][0]["label"] == "Home"


async def test_delete_device_succeeds(client: httpx.AsyncClient) -> None:
    await client.post("/api/devices", json={"token": TOKEN, "platform": "ios"})
    r = await client.delete(f"/api/devices/{TOKEN}")
    assert r.status_code == 204
    r2 = await client.get(f"/api/devices/{TOKEN}")
    assert r2.status_code == 404


async def test_delete_unknown_device_404(client: httpx.AsyncClient) -> None:
    r = await client.delete(f"/api/devices/{TOKEN}")
    assert r.status_code == 404


async def test_invalid_token_path_rejected(client: httpx.AsyncClient) -> None:
    r = await client.get("/api/devices/zzz")  # too short + non-hex
    assert r.status_code == 422
