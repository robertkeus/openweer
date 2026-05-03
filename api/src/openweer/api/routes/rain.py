"""GET /api/rain/{lat}/{lon} — 2-hour minute-by-minute rain nowcast."""

from __future__ import annotations

import asyncio
from datetime import datetime
from pathlib import Path
from typing import Annotated

from fastapi import APIRouter, Depends, HTTPException, Response, status
from fastapi import Path as PathParam
from pydantic import BaseModel

from openweer.api.dependencies import AppState, get_state, latest_radar_forecast_path
from openweer.forecast.rain_2h import RainNowcast, sample_rain_nowcast

router = APIRouter(prefix="/api", tags=["rain"])

# Hard NL bbox guard — rejects any out-of-range coordinate at the edge.
_LAT_MIN, _LAT_MAX = 50.0, 54.0
_LON_MIN, _LON_MAX = 3.0, 8.0


class RainSampleOut(BaseModel):
    minutes_ahead: int
    mm_per_h: float
    valid_at: datetime


class RainResponse(BaseModel):
    lat: float
    lon: float
    analysis_at: datetime
    samples: list[RainSampleOut]


@router.get("/rain/{lat}/{lon}", response_model=RainResponse)
async def rain(
    state: Annotated[AppState, Depends(get_state)],
    response: Response,
    lat: Annotated[float, PathParam(ge=_LAT_MIN, le=_LAT_MAX, examples=[52.37])],
    lon: Annotated[float, PathParam(ge=_LON_MIN, le=_LON_MAX, examples=[4.89])],
) -> RainResponse:
    hdf5_path = latest_radar_forecast_path(state)
    if hdf5_path is None:
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail="No radar_forecast file ingested yet.",
        )

    nowcast = await asyncio.to_thread(_sample, hdf5_path, lat, lon)
    response.headers["Cache-Control"] = "public, max-age=60"
    return RainResponse(
        lat=nowcast.lat,
        lon=nowcast.lon,
        analysis_at=nowcast.analysis_at,
        samples=[
            RainSampleOut(
                minutes_ahead=s.minutes_ahead,
                mm_per_h=s.mm_per_h,
                valid_at=s.valid_at,
            )
            for s in nowcast.samples
        ],
    )


def _sample(hdf5_path: Path, lat: float, lon: float) -> RainNowcast:
    # h5py I/O + reprojection are sync; offload to a thread to keep the
    # FastAPI event loop snappy under load.
    return sample_rain_nowcast(hdf5_path, lat=lat, lon=lon)
