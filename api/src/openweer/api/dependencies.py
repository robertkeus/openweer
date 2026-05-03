"""Shared dependency injection for the FastAPI routes.

Boundary types, settings, and storage are constructed once at app start and
reused across requests. Routes consume them through `Depends(get_*)`.
"""

from __future__ import annotations

from dataclasses import dataclass
from pathlib import Path

from fastapi import Request

from openweer.ingest.storage import IngestStorage
from openweer.knmi.datasets import get_dataset
from openweer.settings import Settings, get_settings
from openweer.tiler.manifest import ManifestStore


@dataclass(slots=True, frozen=True)
class AppState:
    """Process-wide handles attached to `app.state.openweer`."""

    settings: Settings
    ingest: IngestStorage
    frames_manifest: ManifestStore

    @classmethod
    def build(cls, settings: Settings) -> AppState:
        data_dir: Path = settings.data_dir
        ingest = IngestStorage(data_dir)
        frames_manifest = ManifestStore(data_dir / "manifests" / "frames.json")
        return cls(settings=settings, ingest=ingest, frames_manifest=frames_manifest)


def get_state(request: Request) -> AppState:
    state: AppState = request.app.state.openweer
    return state


def get_settings_dep() -> Settings:
    return get_settings()


def latest_radar_forecast_path(state: AppState) -> Path | None:
    """Return the path to the newest ingested radar_forecast HDF5, if any."""
    dataset = get_dataset("radar_forecast")
    manifest = state.ingest.read_manifest(dataset)
    if manifest is None:
        return None
    path = state.ingest.raw_path(dataset, manifest.filename)
    return path if path.exists() else None
