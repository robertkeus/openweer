"""Routes for device registration + favorite locations.

Identity is the APNs token (hex). No user accounts. A device may have up
to `MAX_FAVORITES_PER_DEVICE` favorites, each with its own alert prefs.

  POST   /api/devices                       — upsert this device
  GET    /api/devices/{token}                — reconcile state (called on app launch)
  PUT    /api/devices/{token}/favorites      — replace the favorite list atomically
  DELETE /api/devices/{token}                — unsubscribe
"""

from __future__ import annotations

import re
from typing import Annotated

from fastapi import APIRouter, Depends, HTTPException, status
from fastapi import Path as PathParam

from openweer._logging import get_logger
from openweer.api.dependencies import AppState, get_state
from openweer.devices import MAX_FAVORITES_PER_DEVICE
from openweer.devices.models import (
    DeviceRegistration,
    DeviceResponse,
    FavoritesReplace,
)

log = get_logger(__name__)

router = APIRouter(prefix="/api/devices", tags=["devices"])

# Hex APNs tokens — length tolerant (current 64-char standard tokens fit, future-proofed).
_TOKEN_RE = re.compile(r"^[A-Fa-f0-9]{8,200}$")
TokenPath = Annotated[
    str,
    PathParam(min_length=8, max_length=200, pattern=r"^[A-Fa-f0-9]+$"),
]


def _validate_token(token: str) -> str:
    if not _TOKEN_RE.fullmatch(token):
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Invalid token.")
    return token


@router.post("", response_model=DeviceResponse, status_code=status.HTTP_200_OK)
async def register_device(
    body: DeviceRegistration,
    state: Annotated[AppState, Depends(get_state)],
) -> DeviceResponse:
    repo = state.devices
    await repo.upsert_device(
        device_id=body.token,
        platform=body.platform,
        language=body.language,
        app_version=body.app_version,
    )
    favorites = await repo.list_favorites(body.token)
    log.info("devices.registered", token_tail=body.token[-6:], platform=body.platform)
    return DeviceResponse(device_id=body.token, favorites=favorites)


@router.get("/{token}", response_model=DeviceResponse)
async def get_device(
    token: TokenPath,
    state: Annotated[AppState, Depends(get_state)],
) -> DeviceResponse:
    _validate_token(token)
    repo = state.devices
    row = await repo.get_device(token)
    if row is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Unknown device.")
    favorites = await repo.list_favorites(token)
    return DeviceResponse(device_id=token, favorites=favorites)


@router.put("/{token}/favorites", response_model=DeviceResponse)
async def replace_favorites(
    token: TokenPath,
    body: FavoritesReplace,
    state: Annotated[AppState, Depends(get_state)],
) -> DeviceResponse:
    _validate_token(token)
    if len(body.favorites) > MAX_FAVORITES_PER_DEVICE:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"At most {MAX_FAVORITES_PER_DEVICE} favorites allowed.",
        )
    repo = state.devices
    if await repo.get_device(token) is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Unknown device.")
    favorites = await repo.replace_favorites(device_id=token, favorites=body.favorites)
    log.info(
        "devices.favorites_replaced",
        token_tail=token[-6:],
        count=len(favorites),
    )
    return DeviceResponse(device_id=token, favorites=favorites)


@router.delete("/{token}", status_code=status.HTTP_204_NO_CONTENT)
async def delete_device(
    token: TokenPath,
    state: Annotated[AppState, Depends(get_state)],
) -> None:
    _validate_token(token)
    repo = state.devices
    if not await repo.delete_device(token):
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Unknown device.")
    log.info("devices.deleted", token_tail=token[-6:])
