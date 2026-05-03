"""Frames manifest (`frames.json`) — the single source of truth for the slider.

Atomic-rename writes; per-kind sort + retention; safe against concurrent readers.
"""

from __future__ import annotations

import os
from collections.abc import Iterable
from datetime import datetime
from pathlib import Path
from typing import Literal

from pydantic import BaseModel, ConfigDict

FrameKind = Literal["observed", "nowcast", "hourly"]


class Frame(BaseModel):
    """One animation frame, identifying the on-disk tile dir + its timestamp."""

    model_config = ConfigDict(frozen=True)

    id: str
    ts: datetime
    kind: FrameKind
    cadence_minutes: int
    max_zoom: int


class FramesManifest(BaseModel):
    """Top-level structure written to `frames.json`."""

    model_config = ConfigDict(frozen=True)

    frames: tuple[Frame, ...]
    generated_at: datetime


class ManifestStore:
    """Read/write the frames manifest atomically."""

    def __init__(self, path: Path) -> None:
        self._path = path

    @property
    def path(self) -> Path:
        return self._path

    def read(self) -> FramesManifest:
        if not self._path.is_file():
            return FramesManifest(frames=(), generated_at=_now())
        try:
            return FramesManifest.model_validate_json(self._path.read_bytes())
        except (ValueError, OSError):
            return FramesManifest(frames=(), generated_at=_now())

    def write(self, frames: Iterable[Frame]) -> FramesManifest:
        manifest = FramesManifest(
            frames=tuple(_dedupe_sorted(frames)),
            generated_at=_now(),
        )
        self._path.parent.mkdir(parents=True, exist_ok=True)
        tmp = self._path.with_suffix(self._path.suffix + ".part")
        tmp.write_text(manifest.model_dump_json(indent=2), encoding="utf-8")
        os.replace(tmp, self._path)
        return manifest

    def upsert(self, frames: Iterable[Frame]) -> FramesManifest:
        """Merge `frames` into the existing manifest, replacing same-id entries."""
        existing = {f.id: f for f in self.read().frames}
        for f in frames:
            existing[f.id] = f
        return self.write(existing.values())

    def prune_observed_to(self, max_count: int) -> FramesManifest:
        """Trim `observed` frames to the most-recent `max_count` (oldest dropped)."""
        current = self.read().frames
        observed = sorted((f for f in current if f.kind == "observed"), key=_ts)
        keep = set(f.id for f in observed[-max_count:]) if observed else set()
        kept = [f for f in current if f.kind != "observed" or f.id in keep]
        return self.write(kept)


def _ts(f: Frame) -> datetime:
    return f.ts


def _dedupe_sorted(frames: Iterable[Frame]) -> list[Frame]:
    by_id: dict[str, Frame] = {}
    for f in frames:
        by_id[f.id] = f
    return sorted(by_id.values(), key=_ts)


def _now() -> datetime:
    from datetime import UTC

    return datetime.now(UTC)


# tiny helper for tests to round-trip a manifest from JSON.
def manifest_from_json(text: str) -> FramesManifest:
    return FramesManifest.model_validate_json(text)


def manifest_to_json(m: FramesManifest, *, indent: int | None = 2) -> str:
    return m.model_dump_json(indent=indent)
