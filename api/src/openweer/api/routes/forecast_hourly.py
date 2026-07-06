"""GET /api/forecast/{lat}/{lon}/hourly — 8-day hourly forecast.

Hours 0–48 use KNMI HARMONIE-AROME (high-resolution NL model) via Open-Meteo.
Hours beyond fall back to ECMWF IFS (the same global model KNMI.nl uses for
its extended forecast). Both requests go through Open-Meteo's free API so
no extra key is needed.

A small in-memory cache (15 min TTL keyed on coords rounded to 2 decimals)
prevents redundant upstream calls. The merge strategy mirrors
`forecast.py::_merge` but is keyed by hour-timestamp instead of date.
"""

from __future__ import annotations

import asyncio
import time
from datetime import datetime
from typing import Annotated
from zoneinfo import ZoneInfo

from fastapi import APIRouter, HTTPException, status
from fastapi import Path as PathParam
from pydantic import BaseModel, Field

from openweer.api._bbox import NL_LAT_MAX, NL_LAT_MIN, NL_LON_MAX, NL_LON_MIN
from openweer.api._errors import upstream_url_guard
from openweer.api.routes._open_meteo import (
    CACHE_TTL_S,
    ECMWF_MODEL,
    FORECAST_DAYS,
    HARMONIE_DAYS,
    HARMONIE_MODEL,
    OPEN_METEO_URL,
    Series,
    at,
    at_bool,
    fetch_model,
)
from openweer.knmi._security import assert_open_meteo_url

router = APIRouter(prefix="/api", tags=["forecast"])

_AMSTERDAM_TZ = ZoneInfo("Europe/Amsterdam")

_HOURLY_FIELDS = ",".join(
    [
        "temperature_2m",
        "apparent_temperature",
        "weathercode",
        "precipitation",
        "precipitation_probability",
        "windspeed_10m",
        "winddirection_10m",
        "windgusts_10m",
        "relative_humidity_2m",
        "cloudcover",
        "uv_index",
        "is_day",
    ]
)


class HourlySlot(BaseModel):
    time: datetime
    weather_code: int | None
    temperature_c: float | None
    apparent_temperature_c: float | None
    precipitation_mm: float | None
    precipitation_probability_pct: int | None
    wind_speed_kph: float | None
    wind_direction_deg: int | None
    wind_gusts_kph: float | None
    relative_humidity_pct: int | None
    cloud_cover_pct: int | None
    uv_index: float | None
    is_day: bool | None
    source: str | None = None


class HourlyForecastResponse(BaseModel):
    lat: float
    lon: float
    source: str = "knmi-harmonie+ecmwf"
    timezone: str = "Europe/Amsterdam"
    hours: list[HourlySlot] = Field(default_factory=list)


_cache: dict[tuple[float, float], tuple[float, HourlyForecastResponse]] = {}


@router.get("/forecast/{lat}/{lon}/hourly", response_model=HourlyForecastResponse)
async def forecast_hourly(
    lat: Annotated[float, PathParam(ge=NL_LAT_MIN, le=NL_LAT_MAX, examples=[52.37])],
    lon: Annotated[float, PathParam(ge=NL_LON_MIN, le=NL_LON_MAX, examples=[4.89])],
) -> HourlyForecastResponse:
    rlat = round(lat, 2)
    rlon = round(lon, 2)
    cache_key = (rlat, rlon)
    now = time.monotonic()

    cached = _cache.get(cache_key)
    if cached and cached[0] > now:
        return cached[1]

    with upstream_url_guard("De voorspellingsbron is niet toegestaan."):
        url = assert_open_meteo_url(OPEN_METEO_URL)

    harmonie_data, ecmwf_data = await asyncio.gather(
        fetch_model(
            url, rlat, rlon, HARMONIE_MODEL, HARMONIE_DAYS, section="hourly", fields=_HOURLY_FIELDS
        ),
        fetch_model(
            url, rlat, rlon, ECMWF_MODEL, FORECAST_DAYS, section="hourly", fields=_HOURLY_FIELDS
        ),
    )

    if ecmwf_data is None:
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail="De per-uur verwachting is even niet bereikbaar.",
        )

    response = _merge(rlat, rlon, harmonie_data, ecmwf_data)
    _cache[cache_key] = (now + CACHE_TTL_S, response)
    return response


def _merge(
    lat: float,
    lon: float,
    harmonie: Series | None,
    ecmwf: Series,
) -> HourlyForecastResponse:
    ecmwf_hourly: Series = ecmwf.get("hourly") or {}
    harmonie_hourly: Series = (harmonie.get("hourly") or {}) if harmonie else {}

    ecmwf_times: list[str] = ecmwf_hourly.get("time") or []
    harmonie_times: list[str] = harmonie_hourly.get("time") or []
    harmonie_by_time = {t: i for i, t in enumerate(harmonie_times)}

    hours: list[HourlySlot] = []
    for ei, t in enumerate(ecmwf_times):
        hi = harmonie_by_time.get(t)
        if hi is not None and at(harmonie_hourly, "temperature_2m", hi, float) is not None:
            src, si, source = harmonie_hourly, hi, "knmi-harmonie"
        else:
            src, si, source = ecmwf_hourly, ei, "ecmwf"

        hours.append(
            HourlySlot(
                time=datetime.fromisoformat(t).replace(tzinfo=_AMSTERDAM_TZ),
                weather_code=at(src, "weathercode", si, int),
                temperature_c=at(src, "temperature_2m", si, float),
                apparent_temperature_c=at(src, "apparent_temperature", si, float),
                precipitation_mm=at(src, "precipitation", si, float),
                # HARMONIE is deterministic — always take probability from ECMWF.
                precipitation_probability_pct=at(
                    ecmwf_hourly, "precipitation_probability", ei, int
                ),
                wind_speed_kph=at(src, "windspeed_10m", si, float),
                wind_direction_deg=at(src, "winddirection_10m", si, int),
                wind_gusts_kph=at(src, "windgusts_10m", si, float),
                relative_humidity_pct=at(src, "relative_humidity_2m", si, int),
                cloud_cover_pct=at(src, "cloudcover", si, int),
                uv_index=at(src, "uv_index", si, float),
                is_day=at_bool(src, "is_day", si),
                source=source,
            )
        )
    return HourlyForecastResponse(lat=lat, lon=lon, hours=hours)


def _reset_hourly_cache_for_tests() -> None:
    """Test hook — empties the in-memory hourly cache between tests."""
    _cache.clear()
