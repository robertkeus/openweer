"""GET /api/weather/{lat}/{lon} — current observations from the nearest KNMI station."""

from __future__ import annotations

import asyncio
from datetime import datetime
from typing import Annotated, Literal

from fastapi import APIRouter, Depends, HTTPException, status
from fastapi import Path as PathParam
from pydantic import BaseModel

from openweer.api.dependencies import AppState, get_state
from openweer.forecast.observations import (
    StationObservation,
    latest_observation_path,
    nearest_station_observation,
)

router = APIRouter(prefix="/api", tags=["weather"])

_LAT_MIN, _LAT_MAX = 50.0, 54.0
_LON_MIN, _LON_MAX = 3.0, 8.0

ConditionKind = Literal[
    "clear",
    "partly-cloudy",
    "cloudy",
    "fog",
    "drizzle",
    "rain",
    "thunder",
    "snow",
    "unknown",
]


class WeatherStation(BaseModel):
    name: str
    id: str
    lat: float
    lon: float
    distance_km: float


class CurrentWeather(BaseModel):
    observed_at: datetime
    temperature_c: float | None
    feels_like_c: float | None
    condition: ConditionKind
    condition_label: str  # Dutch
    wind_speed_mps: float | None
    wind_speed_bft: int | None
    wind_direction_deg: float | None
    wind_direction_compass: str | None  # NW, ZZW, etc.
    humidity_pct: float | None
    pressure_hpa: float | None
    rainfall_1h_mm: float | None
    rainfall_24h_mm: float | None
    cloud_cover_octas: float | None
    visibility_m: float | None


class WeatherResponse(BaseModel):
    station: WeatherStation
    current: CurrentWeather


@router.get("/weather/{lat}/{lon}", response_model=WeatherResponse)
async def weather(
    state: Annotated[AppState, Depends(get_state)],
    lat: Annotated[float, PathParam(ge=_LAT_MIN, le=_LAT_MAX, examples=[52.37])],
    lon: Annotated[float, PathParam(ge=_LON_MIN, le=_LON_MAX, examples=[4.89])],
) -> WeatherResponse:
    raw_dir = state.settings.data_dir / "raw" / "10-minute-in-situ-meteorological-observations"
    nc_path = await asyncio.to_thread(latest_observation_path, raw_dir)
    if nc_path is None:
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail="Geen waarnemingen beschikbaar.",
        )
    obs = await asyncio.to_thread(nearest_station_observation, nc_path, lat, lon)
    return _to_response(obs)


def _to_response(obs: StationObservation) -> WeatherResponse:
    return WeatherResponse(
        station=WeatherStation(
            name=obs.station_name,
            id=obs.station_id,
            lat=obs.lat,
            lon=obs.lon,
            distance_km=round(obs.distance_km, 1),
        ),
        current=CurrentWeather(
            observed_at=obs.observed_at,
            temperature_c=obs.temperature_c,
            feels_like_c=_feels_like(obs.temperature_c, obs.wind_speed_mps, obs.humidity_pct),
            condition=_classify_condition(obs.weather_code, obs.cloud_cover_octas, obs.rainfall_1h_mm),
            condition_label=_condition_label_nl(obs.weather_code, obs.cloud_cover_octas, obs.rainfall_1h_mm),
            wind_speed_mps=obs.wind_speed_mps,
            wind_speed_bft=_beaufort(obs.wind_speed_mps),
            wind_direction_deg=obs.wind_direction_deg,
            wind_direction_compass=_compass_nl(obs.wind_direction_deg),
            humidity_pct=obs.humidity_pct,
            pressure_hpa=obs.pressure_hpa,
            rainfall_1h_mm=obs.rainfall_1h_mm,
            rainfall_24h_mm=obs.rainfall_24h_mm,
            cloud_cover_octas=obs.cloud_cover_octas,
            visibility_m=obs.visibility_m,
        ),
    )


def _classify_condition(
    ww: int | None, cloud_octas: float | None, rain_1h: float | None
) -> ConditionKind:
    """Map WMO `ww` code (0-99) plus fallback signals to a UI condition kind."""
    if ww is not None:
        if 95 <= ww <= 99:
            return "thunder"
        if 70 <= ww <= 79 or 85 <= ww <= 86:
            return "snow"
        if 60 <= ww <= 69 or 80 <= ww <= 84:
            return "rain"
        if 50 <= ww <= 59:
            return "drizzle"
        if 40 <= ww <= 49 or 10 <= ww <= 19:
            return "fog"
        if ww == 0:
            return "clear"
        if 1 <= ww <= 3:
            return "partly-cloudy"
        if 4 <= ww <= 9:
            return "cloudy"
    # Fallback heuristics when ww is missing.
    if rain_1h is not None and rain_1h > 0.05:
        return "rain"
    if cloud_octas is not None:
        if cloud_octas <= 1:
            return "clear"
        if cloud_octas <= 4:
            return "partly-cloudy"
        return "cloudy"
    return "unknown"


def _condition_label_nl(
    ww: int | None, cloud_octas: float | None, rain_1h: float | None
) -> str:
    kind = _classify_condition(ww, cloud_octas, rain_1h)
    return {
        "clear": "Helder",
        "partly-cloudy": "Half bewolkt",
        "cloudy": "Bewolkt",
        "fog": "Mist",
        "drizzle": "Motregen",
        "rain": "Regen",
        "thunder": "Onweer",
        "snow": "Sneeuw",
        "unknown": "Onbekend",
    }[kind]


# Beaufort cut-offs in m/s (lower bound of each force).
_BEAUFORT_THRESHOLDS_MPS = (
    0.3, 1.6, 3.4, 5.5, 8.0, 10.8, 13.9, 17.2, 20.8, 24.5, 28.5, 32.7,
)


def _beaufort(speed_mps: float | None) -> int | None:
    if speed_mps is None:
        return None
    bft = 0
    for i, t in enumerate(_BEAUFORT_THRESHOLDS_MPS, start=1):
        if speed_mps >= t:
            bft = i
    return bft


_COMPASS_NL = (
    "N", "NNO", "NO", "ONO",
    "O", "OZO", "ZO", "ZZO",
    "Z", "ZZW", "ZW", "WZW",
    "W", "WNW", "NW", "NNW",
)


def _compass_nl(deg: float | None) -> str | None:
    if deg is None:
        return None
    idx = int((deg % 360) / 22.5 + 0.5) % 16
    return _COMPASS_NL[idx]


def _feels_like(
    temp_c: float | None, wind_mps: float | None, humidity_pct: float | None
) -> float | None:
    """Apparent temperature: wind chill below 10°C, AT for the rest, else None.

    Both formulas are well-known approximations; we round to one decimal.
    """
    if temp_c is None:
        return None
    if temp_c <= 10.0 and wind_mps is not None and wind_mps > 1.34:  # 4.8 km/h
        # Wind-chill (Steadman) — Dutch KNMI uses the JAG/TI variant which
        # is close enough for the UI strip we're building here.
        v_kmh = wind_mps * 3.6
        wci = (
            13.12
            + 0.6215 * temp_c
            - 11.37 * (v_kmh**0.16)
            + 0.3965 * temp_c * (v_kmh**0.16)
        )
        return round(wci, 1)
    if temp_c >= 26.0 and humidity_pct is not None:
        # Steadman apparent temperature (simplified): adds humidity-driven heat.
        e = (humidity_pct / 100) * 6.105 * 2.71828 ** ((17.27 * temp_c) / (237.7 + temp_c))
        at = temp_c + 0.348 * e - 0.7 * (wind_mps or 0) - 4.25
        return round(at, 1)
    return round(temp_c, 1)
