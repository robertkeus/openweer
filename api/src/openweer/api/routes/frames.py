"""GET /api/frames — list of animation frames (id, ts, kind) for the slider."""

from __future__ import annotations

from typing import Annotated

from fastapi import APIRouter, Depends, Response

from openweer.api.dependencies import AppState, get_state
from openweer.tiler.manifest import FramesManifest

router = APIRouter(prefix="/api", tags=["frames"])


@router.get("/frames", response_model=FramesManifest)
async def frames(
    state: Annotated[AppState, Depends(get_state)],
    response: Response,
) -> FramesManifest:
    response.headers["Cache-Control"] = "public, max-age=30"
    return state.frames_manifest.read()
