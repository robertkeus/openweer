"""Pure prompt-construction helpers for the /api/chat route.

Lives in its own module so we can unit-test the builders without spinning
up FastAPI. The route layer turns these strings into OpenAI-style message
dicts before forwarding to GreenPT.
"""

from __future__ import annotations

from collections.abc import Iterable, Sequence
from dataclasses import dataclass
from datetime import UTC, datetime

from pydantic import BaseModel, Field, field_validator

from openweer.api._bbox import NL_LAT_MAX, NL_LAT_MIN, NL_LON_MAX, NL_LON_MIN


@dataclass(frozen=True, slots=True)
class City:
    """A named (lat, lon) used for the national rain snapshot."""

    name: str
    lat: float
    lon: float


# Mirror of web/app/lib/locations.ts:KNOWN_LOCATIONS — keep in sync.
MAJOR_CITIES: tuple[City, ...] = (
    City("Amsterdam", 52.37, 4.89),
    City("Rotterdam", 51.92, 4.48),
    City("Den Haag", 52.07, 4.30),
    City("Utrecht", 52.09, 5.12),
    City("Eindhoven", 51.44, 5.48),
    City("Groningen", 53.22, 6.57),
    City("Maastricht", 50.85, 5.69),
    City("Arnhem", 51.98, 5.91),
    City("Tilburg", 51.55, 5.09),
    City("Leeuwarden", 53.20, 5.79),
    City("Middelburg", 51.50, 3.61),
    City("Enschede", 52.22, 6.89),
)


class ChatRainSample(BaseModel):
    """One bar of the 2-hour rain forecast (matches the frontend RainSample)."""

    minutes_ahead: int = Field(ge=-30, le=240)
    mm_per_h: float = Field(ge=0.0, le=200.0)
    valid_at: datetime


class ChatContext(BaseModel):
    """Structured context the user is currently looking at on the map."""

    location_name: str = Field(min_length=1, max_length=120)
    lat: float = Field(ge=NL_LAT_MIN, le=NL_LAT_MAX)
    lon: float = Field(ge=NL_LON_MIN, le=NL_LON_MAX)
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
    peak_local = peak.valid_at.astimezone(UTC).strftime("%H:%M UTC")
    return (
        f"Piek {peak.mm_per_h:.1f} mm/u rond {peak_local}; "
        f"totaal ongeveer {total_mm:.1f} mm; "
        f"{wet_share * 100:.0f}% van de minuten is nat."
    )


@dataclass(frozen=True, slots=True)
class CityRainSummary:
    """Compact rain summary for one city, used by the national snapshot block."""

    name: str
    peak_mm_per_h: float
    total_mm: float


def summarise_city_samples(
    name: str,
    samples: Sequence[ChatRainSample],
) -> CityRainSummary:
    """Reduce 2h of 5-minute samples to a peak intensity + total accumulation."""
    if not samples:
        return CityRainSummary(name=name, peak_mm_per_h=0.0, total_mm=0.0)
    peak = max(s.mm_per_h for s in samples)
    total_mm = sum(s.mm_per_h for s in samples) / 12.0  # 5-min cadence
    return CityRainSummary(name=name, peak_mm_per_h=peak, total_mm=total_mm)


def format_cities_rain_context(
    rows: Iterable[CityRainSummary],
    *,
    language: str = "nl",
) -> str:
    """Multi-line per-city block, sorted drier-first so ordering is informative.

    Empty input returns "" so the caller can omit the section entirely.
    """
    rows = list(rows)
    if not rows:
        return ""
    rows.sort(key=lambda r: (r.peak_mm_per_h, r.total_mm, r.name))
    is_en = language == "en"
    lines = []
    for r in rows:
        if r.peak_mm_per_h < 0.1:
            label = "dry" if is_en else "droog"
            lines.append(f"- {r.name}: {label}")
        else:
            peak_word = "peak" if is_en else "piek"
            total_word = "total" if is_en else "totaal"
            unit_h = "mm/h" if is_en else "mm/u"
            lines.append(
                f"- {r.name}: {peak_word} {r.peak_mm_per_h:.1f} {unit_h}, "
                f"{total_word} {r.total_mm:.1f} mm"
            )
    return "\n".join(lines)


def build_system_prompt(
    ctx: ChatContext,
    *,
    cities_block: str | None = None,
) -> str:
    """The Dutch (or English) system prompt sent on every chat turn.

    `cities_block` is an optional pre-formatted multi-line string from
    `format_cities_rain_context`. When provided, a "national snapshot" section
    is appended so the model can answer cross-city comparison questions.
    """
    rain_line = format_rain_context(ctx.samples)
    if ctx.cursor_at is not None:
        cursor_hm = ctx.cursor_at.astimezone(UTC).strftime("%H:%M UTC")
        cursor_line = (
            f"De gebruiker bekijkt momenteel de tijd {cursor_hm} op de tijdslider."
        )
    else:
        cursor_line = "De tijdslider staat op 'nu'."
    if ctx.language == "en":
        cities_section = (
            f"\nOther major Dutch cities (next 2h, driest first):\n{cities_block}\n"
            if cities_block
            else ""
        )
        cursor_line_en = (
            cursor_line.replace(
                "De gebruiker bekijkt momenteel", "The user is currently inspecting"
            )
            .replace("op de tijdslider", "on the timeline")
            .replace("staat op", "is at")
        )
        return (
            "You are the OpenWeer assistant — a friendly weather coach for the "
            "Netherlands. Reply in clear English in 1-3 short paragraphs, with "
            "concrete advice based on the radar context below. Never invent "
            "data; if you're unsure, say so.\n\n"
            f"Current location: {ctx.location_name} ({ctx.lat:.2f}, {ctx.lon:.2f}).\n"
            f"Forecast (next 2h): {rain_line}\n"
            f"{cursor_line_en}\n"
            f"{cities_section}"
        )
    cities_section_nl = (
        f"\nAndere grote steden in Nederland (komende 2 uur, droogste eerst):\n{cities_block}\n"
        if cities_block
        else ""
    )
    return (
        "Je bent de OpenWeer-assistent — een vriendelijke weercoach voor "
        "Nederland. Antwoord in helder Nederlands in 1-3 korte alinea's, met "
        "concrete tips gebaseerd op de radarcontext hieronder. Verzin nooit "
        "data; als je iets niet weet, zeg dat eerlijk.\n\n"
        f"Huidige locatie: {ctx.location_name} ({ctx.lat:.2f}, {ctx.lon:.2f}).\n"
        f"Verwachting komende 2 uur: {rain_line}\n"
        f"{cursor_line}\n"
        f"{cities_section_nl}"
    )
