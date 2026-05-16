"""Pydantic models for the device + favorites + alert-prefs API boundary.

Coordinate validation reuses the NL bounding box from `api._bbox`. Coords
are rounded to two decimals before persistence (CLAUDE.md A09: never log
or store full-precision PII-adjacent location data).
"""

from __future__ import annotations

from datetime import datetime
from typing import Annotated, Literal

from pydantic import BaseModel, ConfigDict, Field, field_validator

from openweer.api._bbox import NL_LAT_MAX, NL_LAT_MIN, NL_LON_MAX, NL_LON_MIN

LeadTime = Literal[15, 30, 60]
Intensity = Literal["light", "moderate", "heavy"]

# mm/h thresholds keyed by intensity class. KNMI radar reports mm/h per
# 5-min sample; "light" picks up drizzle, "moderate" the typical regen-
# bui, "heavy" a downpour.
INTENSITY_MM_PER_H: dict[Intensity, float] = {
    "light": 0.1,
    "moderate": 1.0,
    "heavy": 4.0,
}


class AlertPrefs(BaseModel):
    """Per-favorite notification preferences."""

    model_config = ConfigDict(extra="forbid")

    lead_time_min: LeadTime = 30
    threshold: Intensity = "moderate"
    quiet_hours_start: int | None = Field(default=None, ge=0, le=23)
    quiet_hours_end: int | None = Field(default=None, ge=0, le=23)


class FavoriteIn(BaseModel):
    """A favorite as submitted by the client. `id` is server-assigned."""

    model_config = ConfigDict(extra="forbid")

    label: Annotated[str, Field(min_length=1, max_length=40)]
    latitude: Annotated[float, Field(ge=NL_LAT_MIN, le=NL_LAT_MAX)]
    longitude: Annotated[float, Field(ge=NL_LON_MIN, le=NL_LON_MAX)]
    alert_prefs: AlertPrefs = Field(default_factory=AlertPrefs)

    @field_validator("latitude", "longitude")
    @classmethod
    def _round_two_decimals(cls, v: float) -> float:
        return round(v, 2)


class Favorite(FavoriteIn):
    """A persisted favorite. Adds the server-assigned id + created_at."""

    favorite_id: int
    created_at: datetime


class DeviceRegistration(BaseModel):
    """Request body for `POST /api/devices`."""

    model_config = ConfigDict(extra="forbid")

    token: Annotated[str, Field(min_length=8, max_length=200, pattern=r"^[A-Fa-f0-9]+$")]
    platform: Literal["ios"] = "ios"
    language: Literal["nl", "en"] = "nl"
    app_version: Annotated[str, Field(max_length=32)] | None = None


class DeviceResponse(BaseModel):
    """Response body for device endpoints."""

    device_id: str
    favorites: list[Favorite]


class FavoritesReplace(BaseModel):
    """Request body for `PUT /api/devices/{token}/favorites`."""

    model_config = ConfigDict(extra="forbid")

    favorites: list[FavoriteIn]


__all__ = [
    "INTENSITY_MM_PER_H",
    "AlertPrefs",
    "DeviceRegistration",
    "DeviceResponse",
    "Favorite",
    "FavoriteIn",
    "FavoritesReplace",
    "Intensity",
    "LeadTime",
]
