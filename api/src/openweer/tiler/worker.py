"""Tiler worker — watches the ingest manifests and renders new radar files.

Strategy: poll `data/manifests/latest_<dataset>.json` mtimes once per second.
When a manifest's referenced file is newer than what we've already rendered,
run the pipeline. Polling avoids pulling in `watchdog`/`inotify` for a single
file.
"""

from __future__ import annotations

import asyncio
import os
from dataclasses import dataclass, field
from pathlib import Path

from openweer._logging import get_logger
from openweer.ingest.storage import IngestStorage, ManifestEntry
from openweer.knmi.datasets import Dataset, get_dataset
from openweer.tiler.manifest import ManifestStore
from openweer.tiler.pipeline import RadarTilePipeline

log = get_logger(__name__)

DEFAULT_POLL_INTERVAL_S = 1.0
DEFAULT_OBSERVED_KEEP = 12  # ~1 h history at 5-min cadence


@dataclass(slots=True)
class TilerWorker:
    """Drives radar HDF5 → tile rendering on demand."""

    ingest_storage: IngestStorage
    pipeline: RadarTilePipeline
    datasets: tuple[Dataset, ...]
    poll_interval_s: float = DEFAULT_POLL_INTERVAL_S
    observed_keep: int = DEFAULT_OBSERVED_KEEP
    _seen_filenames: dict[str, str] = field(default_factory=dict)

    async def run(self) -> None:
        log.info("tiler.start", datasets=[d.key for d in self.datasets])
        # Process whatever's already on disk at boot.
        for dataset in self.datasets:
            self._maybe_render(dataset)
        while True:
            await asyncio.sleep(self.poll_interval_s)
            for dataset in self.datasets:
                try:
                    self._maybe_render(dataset)
                except Exception:
                    log.exception("tiler.poll_failed", dataset=dataset.key)

    def _maybe_render(self, dataset: Dataset) -> None:
        manifest = self.ingest_storage.read_manifest(dataset)
        if manifest is None:
            return
        if self._seen_filenames.get(dataset.key) == manifest.filename:
            return
        path = self.ingest_storage.raw_path(dataset, manifest.filename)
        if not path.exists():
            return
        self._render(dataset, manifest, path)
        self._seen_filenames[dataset.key] = manifest.filename

    def _render(self, dataset: Dataset, manifest: ManifestEntry, path: Path) -> None:
        log.info(
            "tiler.render_start",
            dataset=dataset.key,
            filename=manifest.filename,
            bytes=manifest.bytes_written,
        )
        frames = self.pipeline.render_file(path)
        self.pipeline.manifest.prune_observed_to(self.observed_keep)
        log.info(
            "tiler.render_done",
            dataset=dataset.key,
            filename=manifest.filename,
            frames=len(frames),
        )


def build_default_worker(
    data_dir: Path,
    *,
    poll_interval_s: float = DEFAULT_POLL_INTERVAL_S,
) -> TilerWorker:
    """Wire up a TilerWorker pointing at the standard data layout."""
    ingest = IngestStorage(data_dir)
    tiles_dir = data_dir / "tiles"
    staging_dir = data_dir / "tiles_staging"
    manifest_path = data_dir / "manifests" / "frames.json"
    tiles_dir.mkdir(parents=True, exist_ok=True)
    staging_dir.mkdir(parents=True, exist_ok=True)
    manifest_path.parent.mkdir(parents=True, exist_ok=True)
    pipeline = RadarTilePipeline(
        tiles_dir=tiles_dir,
        staging_dir=staging_dir,
        manifest=ManifestStore(manifest_path),
    )
    return TilerWorker(
        ingest_storage=ingest,
        pipeline=pipeline,
        datasets=(get_dataset("radar_forecast"),),
        poll_interval_s=poll_interval_s,
    )


# Tiny shim so we can import os.path.getmtime without adding a top-level import
# in `_maybe_render` — keeps the file's import block tidy.
def _mtime(p: Path) -> float:
    try:
        return os.path.getmtime(p)
    except OSError:
        return 0.0
