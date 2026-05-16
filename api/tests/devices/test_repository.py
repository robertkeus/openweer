"""SQLite repository — schema, upsert, replace_favorites, push log dedupe."""

from __future__ import annotations

from collections.abc import AsyncIterator
from pathlib import Path

import pytest

from openweer.devices.models import AlertPrefs, FavoriteIn
from openweer.devices.repository import DeviceRepository


@pytest.fixture
async def repo(tmp_path: Path) -> AsyncIterator[DeviceRepository]:
    r = DeviceRepository.open(tmp_path / "devices.db")
    yield r
    r.close()


async def test_schema_creates_required_tables(tmp_path: Path) -> None:
    DeviceRepository.open(tmp_path / "devices.db").close()
    # Re-open and inspect via a raw connection.
    import sqlite3

    conn = sqlite3.connect(tmp_path / "devices.db")
    try:
        names = {
            row[0]
            for row in conn.execute(
                "SELECT name FROM sqlite_master WHERE type='table'"
            ).fetchall()
        }
    finally:
        conn.close()
    assert {"devices", "favorites", "push_log", "schema_version"}.issubset(names)


async def test_upsert_device_is_idempotent(repo: DeviceRepository) -> None:
    token = "a" * 64
    await repo.upsert_device(device_id=token, platform="ios", language="nl", app_version="1.0.0")
    await repo.upsert_device(device_id=token, platform="ios", language="en", app_version="1.0.1")
    row = await repo.get_device(token)
    assert row is not None
    assert row["language"] == "en"
    assert row["app_version"] == "1.0.1"


async def test_replace_favorites_overwrites_previous_set(repo: DeviceRepository) -> None:
    token = "b" * 64
    await repo.upsert_device(device_id=token, platform="ios", language="nl", app_version=None)
    first = await repo.replace_favorites(
        device_id=token,
        favorites=[
            FavoriteIn(label="Home", latitude=52.37, longitude=4.89),
            FavoriteIn(label="Werk", latitude=52.09, longitude=5.12),
        ],
    )
    assert len(first) == 2
    assert {f.label for f in first} == {"Home", "Werk"}

    second = await repo.replace_favorites(
        device_id=token,
        favorites=[FavoriteIn(label="Schoonouders", latitude=51.92, longitude=4.48)],
    )
    assert [f.label for f in second] == ["Schoonouders"]
    listed = await repo.list_favorites(token)
    assert [f.label for f in listed] == ["Schoonouders"]


async def test_delete_device_cascades_favorites(repo: DeviceRepository) -> None:
    token = "c" * 64
    await repo.upsert_device(device_id=token, platform="ios", language="nl", app_version=None)
    await repo.replace_favorites(
        device_id=token,
        favorites=[FavoriteIn(label="Home", latitude=52.37, longitude=4.89)],
    )
    assert len(await repo.list_favorites(token)) == 1
    assert await repo.delete_device(token) is True
    assert await repo.list_favorites(token) == []


async def test_iter_devices_groups_favorites(repo: DeviceRepository) -> None:
    a = "a" * 64
    b = "b" * 64
    await repo.upsert_device(device_id=a, platform="ios", language="nl", app_version=None)
    await repo.upsert_device(device_id=b, platform="ios", language="en", app_version=None)
    await repo.replace_favorites(
        device_id=a,
        favorites=[FavoriteIn(label="Home", latitude=52.37, longitude=4.89)],
    )
    await repo.replace_favorites(
        device_id=b,
        favorites=[
            FavoriteIn(label="Werk", latitude=52.09, longitude=5.12),
            FavoriteIn(label="Familie", latitude=51.92, longitude=4.48),
        ],
    )
    grouped = await repo.iter_devices_with_favorites()
    by_id = {d.device_id: d for d in grouped}
    assert len(by_id[a].favorites) == 1
    assert len(by_id[b].favorites) == 2


async def test_push_log_dedupe_window(repo: DeviceRepository) -> None:
    token = "d" * 64
    await repo.upsert_device(device_id=token, platform="ios", language="nl", app_version=None)
    favs = await repo.replace_favorites(
        device_id=token,
        favorites=[FavoriteIn(label="Home", latitude=52.37, longitude=4.89)],
    )
    fav_id = favs[0].favorite_id
    await repo.record_push_sent(device_id=token, favorite_id=fav_id, dedupe_key="k1")
    assert await repo.already_sent(
        device_id=token,
        favorite_id=fav_id,
        dedupe_key="k1",
        not_before_iso="0000-01-01T00:00:00+00:00",
    )
    # A future cutoff prunes the entry — already_sent reports False.
    assert not await repo.already_sent(
        device_id=token,
        favorite_id=fav_id,
        dedupe_key="k1",
        not_before_iso="9999-12-31T23:59:59+00:00",
    )


async def test_favorite_coords_persist_rounded(repo: DeviceRepository) -> None:
    token = "e" * 64
    await repo.upsert_device(device_id=token, platform="ios", language="nl", app_version=None)
    favs = await repo.replace_favorites(
        device_id=token,
        favorites=[
            FavoriteIn(
                label="Home",
                latitude=52.37345,
                longitude=4.89234,
                alert_prefs=AlertPrefs(lead_time_min=15, threshold="light"),
            ),
        ],
    )
    assert favs[0].latitude == 52.37
    assert favs[0].longitude == 4.89
    assert favs[0].alert_prefs.lead_time_min == 15
    assert favs[0].alert_prefs.threshold == "light"
