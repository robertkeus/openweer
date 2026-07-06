"""Shared Open-Meteo plumbing for the daily and hourly forecast routes.

Both routes hit the same free Open-Meteo endpoint with the same model pair
(KNMI HARMONIE-AROME for the near range, ECMWF IFS beyond) and read values
out of parallel arrays keyed by time. Only the requested section
("daily" vs "hourly") and the field list differ.
"""

from __future__ import annotations

from collections.abc import Callable
from typing import Any

import httpx
import structlog

OPEN_METEO_URL = "https://api.open-meteo.com/v1/forecast"
HARMONIE_MODEL = "knmi_harmonie_arome_europe"
ECMWF_MODEL = "ecmwf_ifs025"
FORECAST_DAYS = 8
HARMONIE_DAYS = 3
CACHE_TTL_S = 15 * 60

_HTTP_TIMEOUT = httpx.Timeout(10.0, connect=5.0)

log = structlog.get_logger("openweer.open_meteo")

#: One "daily"/"hourly" section of an Open-Meteo response: parallel arrays per field.
Series = dict[str, Any]


async def fetch_model(
    url: str,
    lat: float,
    lon: float,
    model: str,
    days: int,
    *,
    section: str,
    fields: str,
) -> dict[str, Any] | None:
    """Fetch one model's forecast; None on any HTTP failure (caller decides severity)."""
    params = {
        "latitude": f"{lat}",
        "longitude": f"{lon}",
        section: fields,
        "timezone": "Europe/Amsterdam",
        "forecast_days": str(days),
        "models": model,
    }
    try:
        async with httpx.AsyncClient(timeout=_HTTP_TIMEOUT) as client:
            resp = await client.get(url, params=params)
            resp.raise_for_status()
            data: dict[str, Any] = resp.json()
            return data
    except httpx.HTTPError as exc:
        log.warning("open_meteo.model_fetch_failed", model=model, error=type(exc).__name__)
        return None


def at[T](series: Series, key: str, idx: int, cast: Callable[[Any], T]) -> T | None:
    """`cast(series[key][idx])`, or None when absent, null, or uncastable."""
    arr = series.get(key) or []
    if idx >= len(arr):
        return None
    v = arr[idx]
    if v is None:
        return None
    try:
        return cast(v)
    except (TypeError, ValueError):
        return None


def at_bool(series: Series, key: str, idx: int) -> bool | None:
    """Open-Meteo booleans (e.g. `is_day`) are 0/1 integers."""
    v = at(series, key, idx, int)
    return None if v is None else bool(v)
