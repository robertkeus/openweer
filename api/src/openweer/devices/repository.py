"""SQLite-backed device + favorites + push_log repository.

A single asyncio.Lock serialises writes per-process so the API and the
pusher loop running in the same event loop never step on each other.
SQLite handles cross-process locking via WAL — fine for our single-host
deployment, but if we ever fan out we'd swap to Postgres.
"""

from __future__ import annotations

import asyncio
import sqlite3
from collections.abc import Iterator
from contextlib import contextmanager
from dataclasses import dataclass
from datetime import UTC, datetime
from pathlib import Path
from typing import Self

from openweer._logging import get_logger
from openweer.devices.models import AlertPrefs, Favorite, FavoriteIn, Intensity, LeadTime
from openweer.devices.schema import apply_migrations, configure_connection

log = get_logger(__name__)


@dataclass(slots=True, frozen=True)
class DeviceWithFavorites:
    """Joined view used by the evaluator loop."""

    device_id: str
    language: str
    favorites: tuple[Favorite, ...]


class DeviceRepository:
    """SQLite-backed CRUD for devices + favorites + push log."""

    def __init__(self, db_path: Path) -> None:
        self._db_path = db_path
        self._db_path.parent.mkdir(parents=True, exist_ok=True)
        self._lock = asyncio.Lock()
        self._conn = sqlite3.connect(
            db_path,
            check_same_thread=False,
            isolation_level=None,  # autocommit; we wrap our own transactions
        )
        configure_connection(self._conn)
        apply_migrations(self._conn)

    @classmethod
    def open(cls, db_path: Path) -> Self:
        return cls(db_path)

    def close(self) -> None:
        self._conn.close()

    # ---- transactions ----

    @contextmanager
    def _tx(self) -> Iterator[sqlite3.Connection]:
        try:
            self._conn.execute("BEGIN IMMEDIATE")
            yield self._conn
            self._conn.execute("COMMIT")
        except BaseException:
            self._conn.execute("ROLLBACK")
            raise

    # ---- devices ----

    async def upsert_device(
        self,
        *,
        device_id: str,
        platform: str,
        language: str,
        app_version: str | None,
    ) -> None:
        now = _now_iso()
        async with self._lock:
            with self._tx() as conn:
                conn.execute(
                    """
                    INSERT INTO devices(device_id, platform, language, app_version,
                                        created_at, updated_at, last_seen_at)
                    VALUES (?, ?, ?, ?, ?, ?, ?)
                    ON CONFLICT(device_id) DO UPDATE SET
                        platform     = excluded.platform,
                        language     = excluded.language,
                        app_version  = excluded.app_version,
                        updated_at   = excluded.updated_at,
                        last_seen_at = excluded.last_seen_at
                    """,
                    (device_id, platform, language, app_version, now, now, now),
                )

    async def get_device(self, device_id: str) -> dict[str, object] | None:
        async with self._lock:
            row = self._conn.execute(
                "SELECT * FROM devices WHERE device_id = ?", (device_id,)
            ).fetchone()
        return dict(row) if row is not None else None

    async def delete_device(self, device_id: str) -> bool:
        async with self._lock:
            with self._tx() as conn:
                cur = conn.execute("DELETE FROM devices WHERE device_id = ?", (device_id,))
                return cur.rowcount > 0

    # ---- favorites ----

    async def replace_favorites(
        self, *, device_id: str, favorites: list[FavoriteIn]
    ) -> list[Favorite]:
        now = _now_iso()
        async with self._lock:
            with self._tx() as conn:
                conn.execute("DELETE FROM favorites WHERE device_id = ?", (device_id,))
                inserted: list[Favorite] = []
                for f in favorites:
                    cur = conn.execute(
                        """
                        INSERT INTO favorites(device_id, label, latitude, longitude,
                                              lead_time_min, threshold,
                                              quiet_hours_start, quiet_hours_end,
                                              created_at)
                        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
                        """,
                        (
                            device_id,
                            f.label,
                            f.latitude,
                            f.longitude,
                            f.alert_prefs.lead_time_min,
                            f.alert_prefs.threshold,
                            f.alert_prefs.quiet_hours_start,
                            f.alert_prefs.quiet_hours_end,
                            now,
                        ),
                    )
                    favorite_id = int(cur.lastrowid or 0)
                    inserted.append(
                        Favorite(
                            favorite_id=favorite_id,
                            label=f.label,
                            latitude=f.latitude,
                            longitude=f.longitude,
                            alert_prefs=f.alert_prefs,
                            created_at=datetime.fromisoformat(now),
                        )
                    )
        return inserted

    async def list_favorites(self, device_id: str) -> list[Favorite]:
        async with self._lock:
            rows = self._conn.execute(
                "SELECT * FROM favorites WHERE device_id = ? ORDER BY favorite_id",
                (device_id,),
            ).fetchall()
        return [_row_to_favorite(row) for row in rows]

    async def iter_devices_with_favorites(self) -> list[DeviceWithFavorites]:
        async with self._lock:
            device_rows = self._conn.execute(
                "SELECT device_id, language FROM devices"
            ).fetchall()
            fav_rows = self._conn.execute(
                "SELECT * FROM favorites ORDER BY favorite_id"
            ).fetchall()
        favs_by_device: dict[str, list[Favorite]] = {}
        for row in fav_rows:
            favs_by_device.setdefault(row["device_id"], []).append(_row_to_favorite(row))
        return [
            DeviceWithFavorites(
                device_id=row["device_id"],
                language=row["language"],
                favorites=tuple(favs_by_device.get(row["device_id"], [])),
            )
            for row in device_rows
        ]

    # ---- push log ----

    async def already_sent(
        self,
        *,
        device_id: str,
        favorite_id: int,
        dedupe_key: str,
        not_before_iso: str,
    ) -> bool:
        async with self._lock:
            row = self._conn.execute(
                """
                SELECT 1 FROM push_log
                WHERE device_id = ? AND favorite_id = ? AND dedupe_key = ?
                  AND sent_at >= ?
                """,
                (device_id, favorite_id, dedupe_key, not_before_iso),
            ).fetchone()
        return row is not None

    async def record_push_sent(
        self,
        *,
        device_id: str,
        favorite_id: int,
        dedupe_key: str,
        sent_at: datetime | None = None,
    ) -> None:
        ts = (sent_at or datetime.now(UTC)).isoformat()
        async with self._lock:
            with self._tx() as conn:
                conn.execute(
                    """
                    INSERT OR REPLACE INTO push_log(device_id, favorite_id, dedupe_key, sent_at)
                    VALUES (?, ?, ?, ?)
                    """,
                    (device_id, favorite_id, dedupe_key, ts),
                )

    async def prune_push_log_older_than(self, *, not_before_iso: str) -> int:
        async with self._lock:
            with self._tx() as conn:
                cur = conn.execute(
                    "DELETE FROM push_log WHERE sent_at < ?", (not_before_iso,)
                )
                return cur.rowcount


def _row_to_favorite(row: sqlite3.Row) -> Favorite:
    threshold: Intensity = row["threshold"]
    lead_time: LeadTime = row["lead_time_min"]
    return Favorite(
        favorite_id=row["favorite_id"],
        label=row["label"],
        latitude=row["latitude"],
        longitude=row["longitude"],
        alert_prefs=AlertPrefs(
            lead_time_min=lead_time,
            threshold=threshold,
            quiet_hours_start=row["quiet_hours_start"],
            quiet_hours_end=row["quiet_hours_end"],
        ),
        created_at=datetime.fromisoformat(row["created_at"]),
    )


def _now_iso() -> str:
    return datetime.now(UTC).isoformat()


__all__ = ["DeviceRepository", "DeviceWithFavorites"]
