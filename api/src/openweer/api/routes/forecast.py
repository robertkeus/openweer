"""GET /api/forecast/{lat}/{lon} — 8-day daily forecast.

Days 1–2 use KNMI HARMONIE-AROME (high-resolution NL model) via Open-Meteo.
Days 3–8 fall back to ECMWF IFS (the same global model KNMI.nl uses for its
extended forecast). Both requests go through Open-Meteo's free API so no
extra key is needed.

A small in-memory cache (15 min TTL keyed on coords rounded to 2 decimals)
prevents redundant upstream calls.
"""

from __future__ import annotations

import asyncio
import time
from datetime import date
from typing import Annotated

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
    fetch_model,
)
from openweer.knmi._security import assert_open_meteo_url

router = APIRouter(prefix="/api", tags=["forecast"])

_DAILY_FIELDS = ",".join(
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
)


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
    source: str | None = None


class ForecastResponse(BaseModel):
    lat: float
    lon: float
    days: list[DailyForecast] = Field(default_factory=list)
    source: str = "knmi-harmonie+ecmwf"


_cache: dict[tuple[float, float], tuple[float, ForecastResponse]] = {}


@router.get("/forecast/{lat}/{lon}", response_model=ForecastResponse)
async def forecast(
    lat: Annotated[float, PathParam(ge=NL_LAT_MIN, le=NL_LAT_MAX, examples=[52.37])],
    lon: Annotated[float, PathParam(ge=NL_LON_MIN, le=NL_LON_MAX, examples=[4.89])],
) -> ForecastResponse:
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
            url, rlat, rlon, HARMONIE_MODEL, HARMONIE_DAYS, section="daily", fields=_DAILY_FIELDS
        ),
        fetch_model(
            url, rlat, rlon, ECMWF_MODEL, FORECAST_DAYS, section="daily", fields=_DAILY_FIELDS
        ),
    )

    if ecmwf_data is None:
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail="De meerdaagse verwachting is even niet bereikbaar.",
        )

    response = _merge(rlat, rlon, harmonie_data, ecmwf_data)
    _cache[cache_key] = (now + CACHE_TTL_S, response)
    return response


def _merge(
    lat: float,
    lon: float,
    harmonie: Series | None,
    ecmwf: Series,
) -> ForecastResponse:
    ecmwf_daily: Series = ecmwf.get("daily") or {}
    harmonie_daily: Series = (harmonie.get("daily") or {}) if harmonie else {}

    ecmwf_times: list[str] = ecmwf_daily.get("time") or []
    harmonie_times: list[str] = harmonie_daily.get("time") or []
    harmonie_by_date = {t: i for i, t in enumerate(harmonie_times)}

    days: list[DailyForecast] = []
    for ei, day_str in enumerate(ecmwf_times):
        hi = harmonie_by_date.get(day_str)
        if hi is not None and at(harmonie_daily, "temperature_2m_max", hi, float) is not None:
            src_daily, si, source = harmonie_daily, hi, "knmi-harmonie"
        else:
            src_daily, si, source = ecmwf_daily, ei, "ecmwf"

        days.append(
            DailyForecast(
                date=date.fromisoformat(day_str),
                weather_code=at(src_daily, "weathercode", si, int),
                temperature_max_c=at(src_daily, "temperature_2m_max", si, float),
                temperature_min_c=at(src_daily, "temperature_2m_min", si, float),
                precipitation_sum_mm=at(src_daily, "precipitation_sum", si, float),
                # HARMONIE is deterministic — always take probability from ECMWF.
                precipitation_probability_pct=at(
                    ecmwf_daily, "precipitation_probability_max", ei, int
                ),
                wind_max_kph=at(src_daily, "windspeed_10m_max", si, float),
                wind_direction_deg=at(src_daily, "winddirection_10m_dominant", si, int),
                sunrise=at(ecmwf_daily, "sunrise", ei, str),
                sunset=at(ecmwf_daily, "sunset", ei, str),
                source=source,
            )
        )
    return ForecastResponse(lat=lat, lon=lon, days=days)


def _reset_cache_for_tests() -> None:
    """Test hook — empties the in-memory cache between tests."""
    _cache.clear()
