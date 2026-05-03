"""GET /api/health — service liveness + freshness summary."""

from __future__ import annotations

from datetime import datetime
from typing import Annotated

from fastapi import APIRouter, Depends
from pydantic import BaseModel

from openweer import __version__
from openweer.api.dependencies import AppState, get_state
from openweer.knmi.datasets import DATASETS

router = APIRouter(prefix="/api", tags=["health"])


class DatasetFreshness(BaseModel):
    dataset: str
    filename: str | None
    ingested_at: datetime | None


class HealthResponse(BaseModel):
    ok: bool
    version: str
    datasets: list[DatasetFreshness]


@router.get("/health", response_model=HealthResponse)
async def health(state: Annotated[AppState, Depends(get_state)]) -> HealthResponse:
    freshness: list[DatasetFreshness] = []
    for ds in DATASETS.values():
        manifest = state.ingest.read_manifest(ds)
        freshness.append(
            DatasetFreshness(
                dataset=ds.key,
                filename=manifest.filename if manifest else None,
                ingested_at=manifest.ingested_at if manifest else None,
            )
        )
    return HealthResponse(ok=True, version=__version__, datasets=freshness)
