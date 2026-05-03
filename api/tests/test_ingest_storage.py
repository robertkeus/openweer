"""IngestStorage — atomic writes, manifest, retention, path-traversal defence."""

from __future__ import annotations

import time
from collections.abc import AsyncIterator
from pathlib import Path

import pytest

from openweer.ingest.storage import IngestStorage, ManifestEntry
from openweer.knmi.datasets import get_dataset

RADAR = get_dataset("radar_forecast")


async def _async_chunks(*chunks: bytes) -> AsyncIterator[bytes]:
    for c in chunks:
        yield c


async def test_write_raw_file_lands_atomically(tmp_path: Path) -> None:
    storage = IngestStorage(tmp_path)
    written = await storage.write_raw_file(
        RADAR,
        "RAD_NL25_RAC_FM_202604031200.h5",
        _async_chunks(b"abc", b"def"),
    )
    assert written == 6
    target = storage.raw_path(RADAR, "RAD_NL25_RAC_FM_202604031200.h5")
    assert target.read_bytes() == b"abcdef"
    # Nothing left in the incoming/.part staging area.
    assert list(storage.incoming_dir(RADAR).iterdir()) == []


async def test_write_raw_file_cleans_up_on_error(tmp_path: Path) -> None:
    storage = IngestStorage(tmp_path)

    async def exploding_chunks() -> AsyncIterator[bytes]:
        yield b"first"
        raise RuntimeError("boom")

    with pytest.raises(RuntimeError, match="boom"):
        await storage.write_raw_file(RADAR, "doomed.h5", exploding_chunks())

    # The target must NOT exist (partial write was rolled back).
    assert not storage.raw_path(RADAR, "doomed.h5").exists()
    # And no .part dangling behind.
    assert list(storage.incoming_dir(RADAR).iterdir()) == []


def test_write_manifest_round_trip(tmp_path: Path) -> None:
    storage = IngestStorage(tmp_path)
    entry = ManifestEntry(
        dataset_name=RADAR.name,
        dataset_version=RADAR.version,
        filename="x.h5",
        bytes_written=42,
    )
    storage.write_manifest(RADAR, entry)
    read_back = storage.read_manifest(RADAR)
    assert read_back is not None
    assert read_back.filename == "x.h5"
    assert read_back.bytes_written == 42


def test_read_manifest_returns_none_when_absent(tmp_path: Path) -> None:
    storage = IngestStorage(tmp_path)
    assert storage.read_manifest(RADAR) is None


def test_already_ingested_detects_existing_file(tmp_path: Path) -> None:
    storage = IngestStorage(tmp_path)
    raw = storage.raw_path(RADAR, "x.h5")
    raw.parent.mkdir(parents=True, exist_ok=True)
    raw.write_bytes(b"hi")
    assert storage.already_ingested(RADAR, "x.h5")
    assert not storage.already_ingested(RADAR, "y.h5")


def test_prune_raw_older_than_removes_only_aged_files(tmp_path: Path) -> None:
    storage = IngestStorage(tmp_path)
    raw_dir = storage.raw_dir(RADAR)
    raw_dir.mkdir(parents=True, exist_ok=True)

    old = raw_dir / "old.h5"
    fresh = raw_dir / "fresh.h5"
    old.write_bytes(b"x")
    fresh.write_bytes(b"x")

    # Backdate `old` by an hour.
    backdated = time.time() - 3600
    import os

    os.utime(old, (backdated, backdated))

    removed = storage.prune_raw_older_than(RADAR, max_age_seconds=600)
    assert removed == 1
    assert not old.exists()
    assert fresh.exists()


@pytest.mark.parametrize("evil", ["../escape.h5", "a/b.h5", ".", "", "..", "with\\slash"])
def test_path_join_rejects_unsafe_filenames(tmp_path: Path, evil: str) -> None:
    storage = IngestStorage(tmp_path)
    with pytest.raises(ValueError):
        storage.raw_path(RADAR, evil)
