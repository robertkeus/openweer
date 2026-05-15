"""GET /api/rain/{lat}/{lon} — minute-by-minute rain at a point.

Combines past observations (the last ~2 h of ingested radar files, one
image1 each) with the 2 h radar nowcast (5-min cadence) and the HARMONIE-
AROME hourly forecast (one sample per forecast hour) so the slider's bar
graph is filled from `-2 h` history through `+24 h` outlook in a single
payload.
"""

from __future__ import annotations

import asyncio
from datetime import datetime
from pathlib import Path
from typing import Annotated

from fastapi import APIRouter, Depends, HTTPException, Response, status
from fastapi import Path as PathParam
from pydantic import BaseModel

from openweer._logging import get_logger
from openweer.api._bbox import NL_LAT_MAX, NL_LAT_MIN, NL_LON_MAX, NL_LON_MIN
from openweer.api.dependencies import (
    AppState,
    get_state,
    latest_harmonie_tar_path,
    latest_radar_forecast_path,
)
from openweer.forecast.rain_2h import RainNowcast, sample_rain_nowcast
from openweer.forecast.rain_harmonie import sample_harmonie_at_point
from openweer.forecast.rain_history import sample_rain_history
from openweer.knmi.datasets import get_dataset
from openweer.tiler.pipeline import HARMONIE_FORECAST_HOURS

log = get_logger(__name__)

router = APIRouter(prefix="/api", tags=["rain"])


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
    lat: Annotated[float, PathParam(ge=NL_LAT_MIN, le=NL_LAT_MAX, examples=[52.37])],
    lon: Annotated[float, PathParam(ge=NL_LON_MIN, le=NL_LON_MAX, examples=[4.89])],
) -> RainResponse:
    hdf5_path = latest_radar_forecast_path(state)
    if hdf5_path is None:
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail="No radar_forecast file ingested yet.",
        )

    nowcast = await asyncio.to_thread(_sample_nowcast, hdf5_path, lat, lon)

    samples: list[RainSampleOut] = [
        RainSampleOut(
            minutes_ahead=s.minutes_ahead,
            mm_per_h=s.mm_per_h,
            valid_at=s.valid_at,
        )
        for s in nowcast.samples
    ]

    # Past 2 h of observed rain at this point — one sample per ingested
    # radar file (image1 = analysis-time observation). Lets the slider's
    # intensity bars fill in to the LEFT of "Nu" instead of staying blank.
    radar_dir = state.ingest.raw_dir(get_dataset("radar_forecast"))
    try:
        history = await asyncio.to_thread(
            sample_rain_history,
            radar_dir,
            lat=lat,
            lon=lon,
            analysis_at=nowcast.analysis_at,
            exclude_filenames=(hdf5_path.name,),
        )
        for h in history:
            samples.append(
                RainSampleOut(
                    minutes_ahead=h.minutes_ahead,
                    mm_per_h=h.mm_per_h,
                    valid_at=h.valid_at,
                )
            )
    except Exception:
        log.exception("rain.history_sample_failed")

    # Best-effort HARMONIE extension: if a tar is on disk, sample the user's
    # point at every forecast hour past the nowcast tail. Any failure here
    # falls back to nowcast-only — don't make the radar endpoint depend on
    # HARMONIE availability.
    tar_path = latest_harmonie_tar_path(state)
    if tar_path is not None:
        try:
            hourly = await asyncio.to_thread(
                sample_harmonie_at_point,
                tar_path,
                lat=lat,
                lon=lon,
                analysis_at=nowcast.analysis_at,
                forecast_hours=HARMONIE_FORECAST_HOURS,
            )
            nowcast_end_min = max(
                (s.minutes_ahead for s in nowcast.samples), default=0
            )
            # Keep only HARMONIE samples that land past the radar nowcast end.
            for s in hourly:
                if s.minutes_ahead <= nowcast_end_min:
                    continue
                samples.append(
                    RainSampleOut(
                        minutes_ahead=s.minutes_ahead,
                        mm_per_h=s.mm_per_h,
                        valid_at=s.valid_at,
                    )
                )
        except Exception:
            # Keep endpoint resilient if HARMONIE read fails for any reason
            # (corrupt tar, missing band, etc).
            log.exception("rain.harmonie_sample_failed")

    samples.sort(key=lambda s: s.minutes_ahead)
    response.headers["Cache-Control"] = "public, max-age=60"
    return RainResponse(
        lat=nowcast.lat,
        lon=nowcast.lon,
        analysis_at=nowcast.analysis_at,
        samples=samples,
    )


def _sample_nowcast(hdf5_path: Path, lat: float, lon: float) -> RainNowcast:
    # h5py I/O + reprojection are sync; offload to a thread to keep the
    # FastAPI event loop snappy under load.
    return sample_rain_nowcast(hdf5_path, lat=lat, lon=lon)
