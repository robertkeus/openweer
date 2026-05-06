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

import httpx
import structlog
from fastapi import APIRouter, HTTPException, status
from fastapi import Path as PathParam
from pydantic import BaseModel, Field

from openweer.api._bbox import NL_LAT_MAX, NL_LAT_MIN, NL_LON_MAX, NL_LON_MIN
from openweer.api._errors import upstream_url_guard
from openweer.knmi._security import assert_open_meteo_url

router = APIRouter(prefix="/api", tags=["forecast"])
log = structlog.get_logger("openweer.forecast")

_OPEN_METEO_URL = "https://api.open-meteo.com/v1/forecast"
_HARMONIE_MODEL = "knmi_harmonie_arome_europe"
_ECMWF_MODEL = "ecmwf_ifs025"
_FORECAST_DAYS = 8
_HARMONIE_DAYS = 3
_HTTP_TIMEOUT = httpx.Timeout(10.0, connect=5.0)
_CACHE_TTL_S = 15 * 60

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
        url = assert_open_meteo_url(_OPEN_METEO_URL)

    harmonie_data, ecmwf_data = await asyncio.gather(
        _fetch_model(url, rlat, rlon, _HARMONIE_MODEL, _HARMONIE_DAYS),
        _fetch_model(url, rlat, rlon, _ECMWF_MODEL, _FORECAST_DAYS),
    )

    if ecmwf_data is None:
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail="De meerdaagse verwachting is even niet bereikbaar.",
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
        "daily": _DAILY_FIELDS,
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
        log.warning("forecast.model_fetch_failed", model=model, error=type(exc).__name__)
        return None


def _merge(
    lat: float,
    lon: float,
    harmonie: dict | None,
    ecmwf: dict,
) -> ForecastResponse:
    ecmwf_daily = ecmwf.get("daily") or {}
    harmonie_daily = (harmonie.get("daily") or {}) if harmonie else {}

    ecmwf_times: list[str] = ecmwf_daily.get("time") or []
    harmonie_times: list[str] = harmonie_daily.get("time") or []
    harmonie_by_date = {t: i for i, t in enumerate(harmonie_times)}

    days: list[DailyForecast] = []
    for ei, day_str in enumerate(ecmwf_times):
        hi = harmonie_by_date.get(day_str)
        use_harmonie = (
            hi is not None
            and _at(harmonie_daily, "temperature_2m_max", hi, float) is not None
        )

        if use_harmonie:
            src_daily = harmonie_daily
            si = hi
            source = "knmi-harmonie"
        else:
            src_daily = ecmwf_daily
            si = ei
            source = "ecmwf"

        days.append(
            DailyForecast(
                date=date.fromisoformat(day_str),
                weather_code=_at(src_daily, "weathercode", si, int),
                temperature_max_c=_at(src_daily, "temperature_2m_max", si, float),
                temperature_min_c=_at(src_daily, "temperature_2m_min", si, float),
                precipitation_sum_mm=_at(src_daily, "precipitation_sum", si, float),
                # HARMONIE is deterministic — always take probability from ECMWF.
                precipitation_probability_pct=_at(
                    ecmwf_daily, "precipitation_probability_max", ei, int
                ),
                wind_max_kph=_at(src_daily, "windspeed_10m_max", si, float),
                wind_direction_deg=_at(src_daily, "winddirection_10m_dominant", si, int),
                sunrise=_at(ecmwf_daily, "sunrise", ei, str),
                sunset=_at(ecmwf_daily, "sunset", ei, str),
                source=source,
            )
        )
    return ForecastResponse(lat=lat, lon=lon, days=days)


def _at(daily: dict, key: str, idx: int, cast):  # type: ignore[type-arg]
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
