"""NL bounding box used for API-boundary coordinate validation.

A coordinate outside this box is rejected at the route level (OWASP A03).
The box is intentionally a few tenths of a degree wider than the political
border so that nearby coastal/border requests still resolve to a station.
"""

from __future__ import annotations

NL_LAT_MIN: float = 50.0
NL_LAT_MAX: float = 54.0
NL_LON_MIN: float = 3.0
NL_LON_MAX: float = 8.0
