"""Filesystem layout + atomic writes for ingested KNMI files.

All writes go through `IngestStorage`, which guarantees:
  - Files appear in `raw/<dataset>/` only after a successful download (atomic rename).
  - Manifest JSON files are likewise written atomically.
  - Path construction is anchored under a single root, so a malicious filename
    cannot escape the data dir (validated already by KnmiClient, defence-in-depth here).
"""

from __future__ import annotations

import os
import time
from collections.abc import AsyncIterator
from datetime import UTC, datetime
from pathlib import Path

import aiofiles
from pydantic import BaseModel, ConfigDict, Field

from openweer.knmi.datasets import Dataset

CHUNK_LOG_BYTES = 1 * 1024 * 1024  # log a debug line every 1 MiB streamed


class ManifestEntry(BaseModel):
    """Latest-file pointer for one dataset."""

    model_config = ConfigDict(frozen=True)

    dataset_name: str
    dataset_version: str
    filename: str
    bytes_written: int
    ingested_at: datetime = Field(default_factory=lambda: datetime.now(UTC))


class IngestStorage:
    """Filesystem operations for the ingest worker."""

    def __init__(self, data_dir: Path) -> None:
        self._root = data_dir.resolve()

    # ---- public paths ----

    @property
    def root(self) -> Path:
        return self._root

    def raw_dir(self, dataset: Dataset) -> Path:
        return self._root / "raw" / dataset.name

    def raw_path(self, dataset: Dataset, filename: str) -> Path:
        return _safe_join(self.raw_dir(dataset), filename)

    def manifest_path(self, dataset: Dataset) -> Path:
        return self._root / "manifests" / f"latest_{dataset.key}.json"

    def incoming_dir(self, dataset: Dataset) -> Path:
        return self._root / "incoming" / dataset.name

    # ---- queries ----

    def already_ingested(self, dataset: Dataset, filename: str) -> bool:
        return self.raw_path(dataset, filename).exists()

    def read_manifest(self, dataset: Dataset) -> ManifestEntry | None:
        path = self.manifest_path(dataset)
        if not path.is_file():
            return None
        try:
            return ManifestEntry.model_validate_json(path.read_bytes())
        except (ValueError, OSError):
            return None

    # ---- mutations ----

    async def write_raw_file(
        self,
        dataset: Dataset,
        filename: str,
        chunks: AsyncIterator[bytes],
    ) -> int:
        """Stream `chunks` to a temp file, then atomic-rename into raw/. Returns bytes written."""
        target = self.raw_path(dataset, filename)
        target.parent.mkdir(parents=True, exist_ok=True)
        self.incoming_dir(dataset).mkdir(parents=True, exist_ok=True)
        tmp = self.incoming_dir(dataset) / f"{filename}.{os.getpid()}.{time.monotonic_ns()}.part"
        bytes_written = 0
        try:
            async with aiofiles.open(tmp, "wb") as f:
                async for chunk in chunks:
                    if not chunk:
                        continue
                    await f.write(chunk)
                    bytes_written += len(chunk)
            os.replace(tmp, target)
        except BaseException:
            tmp.unlink(missing_ok=True)
            raise
        return bytes_written

    def write_manifest(self, dataset: Dataset, entry: ManifestEntry) -> None:
        path = self.manifest_path(dataset)
        path.parent.mkdir(parents=True, exist_ok=True)
        tmp = path.with_suffix(path.suffix + ".part")
        tmp.write_text(entry.model_dump_json(indent=2), encoding="utf-8")
        os.replace(tmp, path)

    def prune_raw_older_than(self, dataset: Dataset, max_age_seconds: float) -> int:
        """Delete raw files for `dataset` whose mtime is older than `max_age_seconds`."""
        directory = self.raw_dir(dataset)
        if not directory.is_dir():
            return 0
        cutoff = time.time() - max_age_seconds
        removed = 0
        for entry in directory.iterdir():
            if not entry.is_file():
                continue
            try:
                if entry.stat().st_mtime < cutoff:
                    entry.unlink()
                    removed += 1
            except FileNotFoundError:
                continue
        return removed


def _safe_join(parent: Path, filename: str) -> Path:
    """Join `filename` under `parent`, refusing path-traversal."""
    if "/" in filename or "\\" in filename or filename in {"", ".", ".."}:
        raise ValueError(f"Refusing unsafe filename: {filename!r}")
    candidate = (parent / filename).resolve()
    parent_resolved = parent.resolve()
    if (
        not str(candidate).startswith(str(parent_resolved) + os.sep)
        and candidate != parent_resolved
    ):
        raise ValueError(f"Filename escapes parent dir: {filename!r}")
    return candidate
