"""GET /api/forecast/{lat}/{lon} — 8-day daily forecast via Open-Meteo.

Open-Meteo blends ECMWF IFS, ICON-EU, and GFS into a single free API
without a key. We fetch with a small in-memory cache (15 min TTL keyed
on coords rounded to 2 decimals) so users browsing nearby spots don't
each round-trip the upstream.
"""

from __future__ import annotations

import asyncio
import time
from datetime import date
from typing import Annotated

import httpx
import structlog
from fastapi import APIRouter, HTTPException, status
from fastapi import Path as PathParam
from pydantic import BaseModel, Field

from openweer.knmi._security import UrlNotAllowedError, assert_open_meteo_url

router = APIRouter(prefix="/api", tags=["forecast"])
log = structlog.get_logger("openweer.forecast")

_LAT_MIN, _LAT_MAX = 50.0, 54.0
_LON_MIN, _LON_MAX = 3.0, 8.0

_OPEN_METEO_URL = "https://api.open-meteo.com/v1/forecast"
_FORECAST_DAYS = 8
_HTTP_TIMEOUT = httpx.Timeout(10.0, connect=5.0)
_CACHE_TTL_S = 15 * 60


class DailyForecast(BaseModel):
    date: date
    weather_code: int | None
    temperature_max_c: float | None
    temperature_min_c: float | None
    precipitation_sum_mm: float | None
    precipitation_probability_pct: int | None
    wind_max_kph: float | None
    wind_direction_deg: int | None
    sunrise: str | None
    sunset: str | None


class ForecastResponse(BaseModel):
    lat: float
    lon: float
    days: list[DailyForecast] = Field(default_factory=list)
    source: str = "open-meteo"


# Tiny module-level cache: { (lat_2dp, lon_2dp) -> (deadline_s, response_json) }.
_cache: dict[tuple[float, float], tuple[float, dict]] = {}


@router.get("/forecast/{lat}/{lon}", response_model=ForecastResponse)
async def forecast(
    lat: Annotated[float, PathParam(ge=_LAT_MIN, le=_LAT_MAX, examples=[52.37])],
    lon: Annotated[float, PathParam(ge=_LON_MIN, le=_LON_MAX, examples=[4.89])],
) -> ForecastResponse:
    rlat = round(lat, 2)
    rlon = round(lon, 2)
    cache_key = (rlat, rlon)
    now = time.monotonic()

    cached = _cache.get(cache_key)
    if cached and cached[0] > now:
        return _build_response(rlat, rlon, cached[1])

    try:
        url = assert_open_meteo_url(_OPEN_METEO_URL)
    except UrlNotAllowedError:
        raise HTTPException(
            status_code=status.HTTP_502_BAD_GATEWAY,
            detail="De voorspellingsbron is niet toegestaan.",
        )

    params = {
        "latitude": f"{rlat}",
        "longitude": f"{rlon}",
        "daily": ",".join(
            [
                "weathercode",
                "temperature_2m_max",
                "temperature_2m_min",
                "precipitation_sum",
                "precipitation_probability_max",
                "windspeed_10m_max",
                "winddirection_10m_dominant",
                "sunrise",
                "sunset",
            ]
        ),
        "timezone": "Europe/Amsterdam",
        "forecast_days": str(_FORECAST_DAYS),
    }
    try:
        async with httpx.AsyncClient(timeout=_HTTP_TIMEOUT) as client:
            resp = await client.get(url, params=params)
            resp.raise_for_status()
            data = resp.json()
    except httpx.HTTPError as exc:
        log.warning("forecast.transport_error", error=type(exc).__name__)
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail="De meerdaagse verwachting is even niet bereikbaar.",
        ) from exc

    _cache[cache_key] = (now + _CACHE_TTL_S, data)
    return _build_response(rlat, rlon, data)


def _build_response(lat: float, lon: float, data: dict) -> ForecastResponse:
    daily = data.get("daily") or {}
    times: list[str] = daily.get("time") or []
    days: list[DailyForecast] = []
    for i, day in enumerate(times):
        days.append(
            DailyForecast(
                date=date.fromisoformat(day),
                weather_code=_at(daily, "weathercode", i, int),
                temperature_max_c=_at(daily, "temperature_2m_max", i, float),
                temperature_min_c=_at(daily, "temperature_2m_min", i, float),
                precipitation_sum_mm=_at(daily, "precipitation_sum", i, float),
                precipitation_probability_pct=_at(
                    daily, "precipitation_probability_max", i, int
                ),
                wind_max_kph=_at(daily, "windspeed_10m_max", i, float),
                wind_direction_deg=_at(
                    daily, "winddirection_10m_dominant", i, int
                ),
                sunrise=_at(daily, "sunrise", i, str),
                sunset=_at(daily, "sunset", i, str),
            )
        )
    return ForecastResponse(lat=lat, lon=lon, days=days)


def _at(daily: dict, key: str, idx: int, cast):
    arr = daily.get(key) or []
    if idx >= len(arr):
        return None
    v = arr[idx]
    if v is None:
        return None
    try:
        return cast(v)
    except (TypeError, ValueError):
        return None


def _reset_cache_for_tests() -> None:
    """Test hook — empties the in-memory cache between tests."""
    _cache.clear()
