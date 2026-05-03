"""Frames manifest — atomic write, dedupe-by-id, observed retention."""

from __future__ import annotations

from datetime import UTC, datetime, timedelta
from pathlib import Path

from openweer.tiler.manifest import Frame, ManifestStore


def _frame(idx: int, kind: str = "observed", *, base: datetime | None = None) -> Frame:
    base = base or datetime(2026, 5, 3, 6, 0, tzinfo=UTC)
    ts = base + timedelta(minutes=5 * idx)
    return Frame(
        id=ts.strftime("%Y%m%dT%H%M") + "Z",
        ts=ts,
        kind=kind,  # type: ignore[arg-type]
        cadence_minutes=5,
        max_zoom=10,
    )


def test_read_returns_empty_when_file_absent(tmp_path: Path) -> None:
    store = ManifestStore(tmp_path / "frames.json")
    m = store.read()
    assert m.frames == ()


def test_write_then_read_round_trip(tmp_path: Path) -> None:
    store = ManifestStore(tmp_path / "frames.json")
    written = store.write([_frame(0), _frame(1)])
    read_back = store.read()
    assert read_back.frames == written.frames


def test_upsert_replaces_same_id_entries(tmp_path: Path) -> None:
    store = ManifestStore(tmp_path / "frames.json")
    store.write([_frame(0, "observed"), _frame(1, "nowcast")])

    # Upsert the second one with a different kind: same id → replace.
    updated = _frame(1, kind="hourly")
    store.upsert([updated])

    kinds = {f.id: f.kind for f in store.read().frames}
    assert kinds[updated.id] == "hourly"
    assert len(kinds) == 2


def test_prune_observed_to_keeps_only_most_recent(tmp_path: Path) -> None:
    store = ManifestStore(tmp_path / "frames.json")
    frames = [_frame(i, "observed") for i in range(5)]
    nowcast = _frame(10, "nowcast")
    store.write([*frames, nowcast])

    store.prune_observed_to(2)

    after = store.read().frames
    observed_left = [f for f in after if f.kind == "observed"]
    assert len(observed_left) == 2
    # The two newest observed frames survive.
    assert observed_left[0].ts < observed_left[1].ts
    assert observed_left[-1] == frames[-1]
    # Nowcast is untouched by `prune_observed_to`.
    assert any(f.kind == "nowcast" for f in after)


def test_atomic_write_uses_part_file(tmp_path: Path) -> None:
    target = tmp_path / "frames.json"
    store = ManifestStore(target)
    store.write([_frame(0)])
    # No leftover .part file after a successful write.
    assert not (tmp_path / "frames.json.part").exists()
    assert target.is_file()
