"""Decide which favorites should trigger a push notification.

Pure functions on top of `sample_rain_nowcasts`. Tested independently of
SQLite + APNs: feed it a sequence of `DeviceWithFavorites`, an HDF5 path,
and a "now" timestamp, and it returns the `Alert`s that should fire.
"""

from __future__ import annotations

from collections.abc import Iterable, Sequence
from dataclasses import dataclass
from datetime import datetime, timedelta
from pathlib import Path

from openweer._logging import get_logger
from openweer.devices.models import INTENSITY_MM_PER_H, Favorite, Intensity
from openweer.devices.repository import DeviceWithFavorites
from openweer.forecast.rain_2h import RainNowcast, RainSample, sample_rain_nowcasts

log = get_logger(__name__)


@dataclass(frozen=True, slots=True)
class Alert:
    """One push to send."""

    device_id: str
    favorite: Favorite
    lead_minutes: int
    intensity: Intensity
    mm_per_h: float
    dedupe_key: str
    language: str


def evaluate(
    *,
    hdf5_path: Path,
    devices: Sequence[DeviceWithFavorites],
    now: datetime,
) -> list[Alert]:
    """Return alerts for every (device, favorite) whose rain threshold trips."""
    if not devices:
        return []
    points = _unique_points(devices)
    if not points:
        return []
    try:
        nowcasts = sample_rain_nowcasts(hdf5_path, points)
    except Exception:
        log.exception("devices.evaluator.sample_failed", path=str(hdf5_path))
        return []
    nowcast_by_point = {(round(n.lat, 2), round(n.lon, 2)): n for n in nowcasts}

    alerts: list[Alert] = []
    for device in devices:
        for fav in device.favorites:
            if _in_quiet_hours(fav, now):
                continue
            nowcast = nowcast_by_point.get((round(fav.latitude, 2), round(fav.longitude, 2)))
            if nowcast is None:
                continue
            alert = _evaluate_one(device=device, favorite=fav, nowcast=nowcast)
            if alert is not None:
                alerts.append(alert)
    return alerts


def _evaluate_one(
    *,
    device: DeviceWithFavorites,
    favorite: Favorite,
    nowcast: RainNowcast,
) -> Alert | None:
    """Return an Alert when the favorite's threshold trips within its lead window."""
    threshold_mm = INTENSITY_MM_PER_H[favorite.alert_prefs.threshold]
    lead = favorite.alert_prefs.lead_time_min
    triggering: RainSample | None = None
    for sample in nowcast.samples:
        if sample.minutes_ahead < 0 or sample.minutes_ahead > lead:
            continue
        if sample.mm_per_h >= threshold_mm:
            triggering = sample
            break
    if triggering is None:
        return None
    classified = _classify_intensity(triggering.mm_per_h)
    # Cooldown key is (favorite, intensity) — **without** the 5-min bucket
    # of the triggering sample. The bucket used to be part of the key so
    # that "new rain at 14:30" and "new rain at 14:35" looked distinct,
    # but during sustained rain the first-triggering bucket rolls forward
    # by 5 min every tick — so the key was changing every cycle and the
    # user got a fresh push every 5 minutes for the same ongoing event
    # (~6/hour, 30+ overnight). Dropping the bucket means the first push
    # for "moderate at this favorite" suppresses all follow-ups within
    # the cooldown window; an *escalation* (e.g. light → moderate, or
    # moderate → heavy) still mints a new key and breaks through.
    dedupe_key = f"{favorite.favorite_id}:{classified}"
    return Alert(
        device_id=device.device_id,
        favorite=favorite,
        lead_minutes=triggering.minutes_ahead,
        intensity=classified,
        mm_per_h=triggering.mm_per_h,
        dedupe_key=dedupe_key,
        language=device.language,
    )


def _classify_intensity(mm_per_h: float) -> Intensity:
    if mm_per_h >= INTENSITY_MM_PER_H["heavy"]:
        return "heavy"
    if mm_per_h >= INTENSITY_MM_PER_H["moderate"]:
        return "moderate"
    return "light"


def _in_quiet_hours(favorite: Favorite, now: datetime) -> bool:
    start = favorite.alert_prefs.quiet_hours_start
    end = favorite.alert_prefs.quiet_hours_end
    if start is None or end is None:
        return False
    h = now.hour
    if start == end:
        return True
    if start < end:
        return start <= h < end
    # wraps midnight, e.g. 22 → 7
    return h >= start or h < end


def _unique_points(devices: Iterable[DeviceWithFavorites]) -> list[tuple[float, float]]:
    seen: dict[tuple[float, float], None] = {}
    for d in devices:
        for f in d.favorites:
            seen.setdefault((round(f.latitude, 2), round(f.longitude, 2)), None)
    return list(seen.keys())


def stale_dedupe_cutoff(now: datetime, window: timedelta) -> str:
    return (now - window).isoformat()


__all__ = ["Alert", "evaluate", "stale_dedupe_cutoff"]
