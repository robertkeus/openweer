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

import httpx
import structlog
from fastapi import APIRouter, HTTPException, status
from fastapi import Path as PathParam
from pydantic import BaseModel, Field

from openweer.api._bbox import NL_LAT_MAX, NL_LAT_MIN, NL_LON_MAX, NL_LON_MIN
from openweer.api._errors import upstream_url_guard
from openweer.knmi._security import assert_open_meteo_url

router = APIRouter(prefix="/api", tags=["forecast"])
log = structlog.get_logger("openweer.forecast_hourly")

_OPEN_METEO_URL = "https://api.open-meteo.com/v1/forecast"
_HARMONIE_MODEL = "knmi_harmonie_arome_europe"
_ECMWF_MODEL = "ecmwf_ifs025"
_FORECAST_DAYS = 8
_HARMONIE_DAYS = 3
_HTTP_TIMEOUT = httpx.Timeout(10.0, connect=5.0)
_CACHE_TTL_S = 15 * 60
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
        url = assert_open_meteo_url(_OPEN_METEO_URL)

    harmonie_data, ecmwf_data = await asyncio.gather(
        _fetch_model(url, rlat, rlon, _HARMONIE_MODEL, _HARMONIE_DAYS),
        _fetch_model(url, rlat, rlon, _ECMWF_MODEL, _FORECAST_DAYS),
    )

    if ecmwf_data is None:
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail="De per-uur verwachting is even niet bereikbaar.",
        )

    response = _merge(rlat, rlon, harmonie_data, ecmwf_data)
    _cache[cache_key] = (now + _CACHE_TTL_S, response)
    return response


async def _fetch_model(
    url: str, lat: float, lon: float, model: str, days: int
) -> dict | None:
    params = {
        "latitude": f"{lat}",
        "longitude": f"{lon}",
        "hourly": _HOURLY_FIELDS,
        "timezone": "Europe/Amsterdam",
        "forecast_days": str(days),
        "models": model,
    }
    try:
        async with httpx.AsyncClient(timeout=_HTTP_TIMEOUT) as client:
            resp = await client.get(url, params=params)
            resp.raise_for_status()
            return resp.json()
    except httpx.HTTPError as exc:
        log.warning(
            "forecast_hourly.model_fetch_failed",
            model=model,
            error=type(exc).__name__,
        )
        return None


def _merge(
    lat: float,
    lon: float,
    harmonie: dict | None,
    ecmwf: dict,
) -> HourlyForecastResponse:
    ecmwf_hourly = ecmwf.get("hourly") or {}
    harmonie_hourly = (harmonie.get("hourly") or {}) if harmonie else {}

    ecmwf_times: list[str] = ecmwf_hourly.get("time") or []
    harmonie_times: list[str] = harmonie_hourly.get("time") or []
    harmonie_by_time = {t: i for i, t in enumerate(harmonie_times)}

    hours: list[HourlySlot] = []
    for ei, t in enumerate(ecmwf_times):
        hi = harmonie_by_time.get(t)
        use_harmonie = (
            hi is not None
            and _at(harmonie_hourly, "temperature_2m", hi, float) is not None
        )

        if use_harmonie:
            src = harmonie_hourly
            si = hi
            source = "knmi-harmonie"
        else:
            src = ecmwf_hourly
            si = ei
            source = "ecmwf"

        hours.append(
            HourlySlot(
                time=datetime.fromisoformat(t).replace(tzinfo=_AMSTERDAM_TZ),
                weather_code=_at(src, "weathercode", si, int),
                temperature_c=_at(src, "temperature_2m", si, float),
                apparent_temperature_c=_at(src, "apparent_temperature", si, float),
                precipitation_mm=_at(src, "precipitation", si, float),
                # HARMONIE is deterministic — always take probability from ECMWF.
                precipitation_probability_pct=_at(
                    ecmwf_hourly, "precipitation_probability", ei, int
                ),
                wind_speed_kph=_at(src, "windspeed_10m", si, float),
                wind_direction_deg=_at(src, "winddirection_10m", si, int),
                wind_gusts_kph=_at(src, "windgusts_10m", si, float),
                relative_humidity_pct=_at(src, "relative_humidity_2m", si, int),
                cloud_cover_pct=_at(src, "cloudcover", si, int),
                uv_index=_at(src, "uv_index", si, float),
                is_day=_at_bool(src, "is_day", si),
                source=source,
            )
        )
    return HourlyForecastResponse(lat=lat, lon=lon, hours=hours)


def _at(hourly: dict, key: str, idx: int, cast):  # type: ignore[type-arg]
    arr = hourly.get(key) or []
    if idx >= len(arr):
        return None
    v = arr[idx]
    if v is None:
        return None
    try:
        return cast(v)
    except (TypeError, ValueError):
        return None


def _at_bool(hourly: dict, key: str, idx: int) -> bool | None:
    arr = hourly.get(key) or []
    if idx >= len(arr):
        return None
    v = arr[idx]
    if v is None:
        return None
    # Open-Meteo `is_day` is 0/1.
    try:
        return bool(int(v))
    except (TypeError, ValueError):
        return None


def _reset_hourly_cache_for_tests() -> None:
    """Test hook — empties the in-memory hourly cache between tests."""
    _cache.clear()
