"""SQLite schema for the device + favorites + push-log tables.

Only stdlib `sqlite3` is used. WAL mode enables concurrent readers (the
pusher loop) alongside the API process's writes without blocking. Foreign
keys are enforced per-connection — SQLite has them off by default.
"""

from __future__ import annotations

import sqlite3

SCHEMA_VERSION = 1

_DDL = (
    """
    CREATE TABLE IF NOT EXISTS schema_version (
        version INTEGER PRIMARY KEY
    );
    """,
    """
    CREATE TABLE IF NOT EXISTS devices (
        device_id     TEXT PRIMARY KEY,
        platform      TEXT NOT NULL,
        language      TEXT NOT NULL DEFAULT 'nl',
        app_version   TEXT,
        created_at    TEXT NOT NULL,
        updated_at    TEXT NOT NULL,
        last_seen_at  TEXT NOT NULL
    );
    """,
    """
    CREATE TABLE IF NOT EXISTS favorites (
        favorite_id       INTEGER PRIMARY KEY AUTOINCREMENT,
        device_id         TEXT NOT NULL REFERENCES devices(device_id) ON DELETE CASCADE,
        label             TEXT NOT NULL,
        latitude          REAL NOT NULL,
        longitude         REAL NOT NULL,
        lead_time_min     INTEGER NOT NULL,
        threshold         TEXT NOT NULL,
        quiet_hours_start INTEGER,
        quiet_hours_end   INTEGER,
        created_at        TEXT NOT NULL
    );
    """,
    """
    CREATE INDEX IF NOT EXISTS favorites_device_idx ON favorites(device_id);
    """,
    """
    CREATE TABLE IF NOT EXISTS push_log (
        device_id    TEXT NOT NULL,
        favorite_id  INTEGER NOT NULL,
        dedupe_key   TEXT NOT NULL,
        sent_at      TEXT NOT NULL,
        PRIMARY KEY (device_id, favorite_id, dedupe_key)
    );
    """,
    """
    CREATE INDEX IF NOT EXISTS push_log_sent_at_idx ON push_log(sent_at);
    """,
)


def apply_migrations(conn: sqlite3.Connection) -> None:
    """Create tables on first run; no-op afterwards.

    Future migrations bump SCHEMA_VERSION and run additional DDL conditional
    on `SELECT version FROM schema_version`. v1 is the bootstrap so we only
    seed the version row.
    """
    conn.execute("PRAGMA foreign_keys = ON")
    for statement in _DDL:
        conn.execute(statement)
    cur = conn.execute("SELECT version FROM schema_version LIMIT 1")
    row = cur.fetchone()
    if row is None:
        conn.execute("INSERT INTO schema_version(version) VALUES (?)", (SCHEMA_VERSION,))
    conn.commit()


def configure_connection(conn: sqlite3.Connection) -> None:
    """Apply per-connection PRAGMAs used by every code path."""
    conn.execute("PRAGMA journal_mode = WAL")
    conn.execute("PRAGMA foreign_keys = ON")
    conn.execute("PRAGMA synchronous = NORMAL")
    conn.row_factory = sqlite3.Row


__all__ = ["SCHEMA_VERSION", "apply_migrations", "configure_connection"]
