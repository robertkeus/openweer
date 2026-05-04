"""Pure prompt-construction helpers for the /api/chat route.

Lives in its own module so we can unit-test the builders without spinning
up FastAPI. The route layer turns these strings into OpenAI-style message
dicts before forwarding to GreenPT.
"""

from __future__ import annotations

from datetime import datetime, timezone
from typing import Iterable

from pydantic import BaseModel, Field, field_validator

# NL bbox — mirrors the radar coverage area; we clamp coords inside the
# context to the same range the rain endpoint already enforces.
_LAT_MIN, _LAT_MAX = 50.0, 54.0
_LON_MIN, _LON_MAX = 3.0, 8.0


class ChatRainSample(BaseModel):
    """One bar of the 2-hour rain forecast (matches the frontend RainSample)."""

    minutes_ahead: int = Field(ge=-30, le=240)
    mm_per_h: float = Field(ge=0.0, le=200.0)
    valid_at: datetime


class ChatContext(BaseModel):
    """Structured context the user is currently looking at on the map."""

    location_name: str = Field(min_length=1, max_length=120)
    lat: float = Field(ge=_LAT_MIN, le=_LAT_MAX)
    lon: float = Field(ge=_LON_MIN, le=_LON_MAX)
    cursor_at: datetime | None = None
    samples: list[ChatRainSample] = Field(default_factory=list, max_length=60)
    language: str = Field(default="nl", min_length=2, max_length=8)
    theme: str = Field(default="light")

    @field_validator("language")
    @classmethod
    def _normalise_language(cls, v: str) -> str:
        v = v.lower().strip()
        if v not in ("nl", "en"):
            return "nl"
        return v


def format_rain_context(samples: Iterable[ChatRainSample]) -> str:
    """Compact one-line summary of the forecast: peak, total mm, dry/wet share."""
    samples = list(samples)
    if not samples:
        return "Geen radar­voorspelling beschikbaar."
    peak = max(samples, key=lambda s: s.mm_per_h)
    total_mm = sum(s.mm_per_h for s in samples) / 12.0  # 5-min cadence → /12 = mm/h to mm
    wet_count = sum(1 for s in samples if s.mm_per_h >= 0.1)
    wet_share = wet_count / len(samples)
    if peak.mm_per_h < 0.1:
        return "Het blijft naar verwachting droog de komende 2 uur."
    peak_local = peak.valid_at.astimezone(timezone.utc).strftime("%H:%M UTC")
    return (
        f"Piek {peak.mm_per_h:.1f} mm/u rond {peak_local}; "
        f"totaal ongeveer {total_mm:.1f} mm; "
        f"{wet_share * 100:.0f}% van de minuten is nat."
    )


def build_system_prompt(ctx: ChatContext) -> str:
    """The Dutch (or English) system prompt sent on every chat turn."""
    rain_line = format_rain_context(ctx.samples)
    cursor_line = (
        f"De gebruiker bekijkt momenteel de tijd {ctx.cursor_at.astimezone(timezone.utc).strftime('%H:%M UTC')} op de tijdslider."
        if ctx.cursor_at is not None
        else "De tijdslider staat op 'nu'."
    )
    if ctx.language == "en":
        return (
            "You are the OpenWeer assistant — a friendly weather coach for the "
            "Netherlands. Reply in clear English in 1-3 short paragraphs, with "
            "concrete advice based on the radar context below. Never invent "
            "data; if you're unsure, say so.\n\n"
            f"Current location: {ctx.location_name} ({ctx.lat:.2f}, {ctx.lon:.2f}).\n"
            f"Forecast (next 2h): {rain_line}\n"
            f"{cursor_line.replace('De gebruiker bekijkt momenteel', 'The user is currently inspecting').replace('op de tijdslider', 'on the timeline').replace('staat op', 'is at')}\n"
        )
    return (
        "Je bent de OpenWeer-assistent — een vriendelijke weercoach voor "
        "Nederland. Antwoord in helder Nederlands in 1-3 korte alinea's, met "
        "concrete tips gebaseerd op de radarcontext hieronder. Verzin nooit "
        "data; als je iets niet weet, zeg dat eerlijk.\n\n"
        f"Huidige locatie: {ctx.location_name} ({ctx.lat:.2f}, {ctx.lon:.2f}).\n"
        f"Verwachting komende 2 uur: {rain_line}\n"
        f"{cursor_line}\n"
    )
