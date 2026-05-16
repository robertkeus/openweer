"""Device registry + per-favorite rain push notifications.

A device's APNs token is its only identifier — there are no user accounts.
Each device may save up to `MAX_FAVORITES_PER_DEVICE` favorite locations,
each with its own alert preferences (lead time, intensity threshold,
optional quiet hours). The pusher loop samples the latest radar nowcast
at every favorite every 5 minutes and pushes when the threshold is met.
"""

from __future__ import annotations

from openweer.devices.models import (
    AlertPrefs,
    DeviceRegistration,
    Favorite,
    FavoriteIn,
    Intensity,
    LeadTime,
)
from openweer.devices.repository import DeviceRepository

MAX_FAVORITES_PER_DEVICE = 5

__all__ = [
    "MAX_FAVORITES_PER_DEVICE",
    "AlertPrefs",
    "DeviceRegistration",
    "DeviceRepository",
    "Favorite",
    "FavoriteIn",
    "Intensity",
    "LeadTime",
]
