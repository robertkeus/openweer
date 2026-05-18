"""Pure-function tests for the /api/chat prompt builders."""

from __future__ import annotations

from datetime import UTC, datetime

import pytest

from openweer.api.routes._chat_prompt import (
    MAJOR_CITIES,
    ChatContext,
    ChatRainSample,
    CityRainSummary,
    build_system_prompt,
    format_cities_rain_context,
    format_rain_context,
    summarise_city_samples,
)


def _ctx(**overrides: object) -> ChatContext:
    base = dict(
        location_name="Amsterdam",
        lat=52.37,
        lon=4.89,
        samples=[],
        language="nl",
        theme="light",
    )
    base.update(overrides)
    return ChatContext(**base)  # type: ignore[arg-type]


def test_format_rain_context_dry() -> None:
    samples = [
        ChatRainSample(
            minutes_ahead=i * 5,
            mm_per_h=0.0,
            valid_at=datetime(2026, 5, 4, 12, i * 5 % 60, tzinfo=UTC),
        )
        for i in range(6)
    ]
    line = format_rain_context(samples)
    assert "droog" in line.lower()


def test_format_rain_context_wet_includes_peak_and_total() -> None:
    samples = [
        ChatRainSample(
            minutes_ahead=0,
            mm_per_h=0.0,
            valid_at=datetime(2026, 5, 4, 12, 0, tzinfo=UTC),
        ),
        ChatRainSample(
            minutes_ahead=30,
            mm_per_h=2.4,
            valid_at=datetime(2026, 5, 4, 12, 30, tzinfo=UTC),
        ),
        ChatRainSample(
            minutes_ahead=60,
            mm_per_h=0.5,
            valid_at=datetime(2026, 5, 4, 13, 0, tzinfo=UTC),
        ),
    ]
    line = format_rain_context(samples)
    assert "2.4" in line  # peak intensity
    assert "12:30" in line  # peak time UTC
    assert "totaal" in line.lower()


def test_format_rain_context_empty_returns_dutch_fallback() -> None:
    line = format_rain_context([])
    assert "geen" in line.lower()


def test_format_rain_context_ignores_past_peaks() -> None:
    """Past observation samples (minutes_ahead < 0) must not bias the
    forecast summary. Pre-fix, a heavy shower from 90 min ago was reported
    as today's peak hours after it had cleared."""
    samples = [
        # Past: heavy rain 90 min ago — *should be ignored*.
        ChatRainSample(
            minutes_ahead=-90,
            mm_per_h=12.0,
            valid_at=datetime(2026, 5, 4, 10, 30, tzinfo=UTC),
        ),
        ChatRainSample(
            minutes_ahead=-60,
            mm_per_h=4.0,
            valid_at=datetime(2026, 5, 4, 11, 0, tzinfo=UTC),
        ),
        # Future: dry next 2 h.
        *[
            ChatRainSample(
                minutes_ahead=i * 5,
                mm_per_h=0.0,
                valid_at=datetime(2026, 5, 4, 12, i * 5 % 60, tzinfo=UTC),
            )
            for i in range(13)
        ],
    ]
    line = format_rain_context(samples)
    assert "12.0" not in line  # past peak must not bleed into the forecast
    assert "droog" in line.lower()


def test_format_rain_context_all_past_returns_no_forecast_fallback() -> None:
    """If every sample is in the past, treat it like an empty forecast."""
    samples = [
        ChatRainSample(
            minutes_ahead=-30,
            mm_per_h=5.0,
            valid_at=datetime(2026, 5, 4, 11, 30, tzinfo=UTC),
        ),
    ]
    line = format_rain_context(samples)
    assert "geen" in line.lower()


def test_build_system_prompt_dutch_default() -> None:
    p = build_system_prompt(_ctx())
    assert "OpenWeer" in p
    assert "Amsterdam" in p
    assert "Nederlands" in p
    # Coordinate is rounded to 2 decimals (privacy).
    assert "52.37" in p


def test_build_system_prompt_english_when_language_en() -> None:
    p = build_system_prompt(_ctx(language="en"))
    assert "OpenWeer" in p
    assert "English" in p
    assert "Amsterdam" in p


def test_build_system_prompt_unknown_language_falls_back_to_nl() -> None:
    # ChatContext validator coerces unknown -> "nl".
    p = build_system_prompt(_ctx(language="fr"))
    assert "Nederlands" in p


def test_build_system_prompt_mentions_cursor_when_set() -> None:
    p = build_system_prompt(
        _ctx(cursor_at=datetime(2026, 5, 4, 13, 25, tzinfo=UTC))
    )
    assert "13:25" in p


def test_build_system_prompt_says_now_when_cursor_unset() -> None:
    p = build_system_prompt(_ctx(cursor_at=None))
    assert "nu" in p.lower()


def test_build_system_prompt_includes_explicit_now_anchor_nl() -> None:
    """The Dutch prompt must surface wall-clock now so the model can tell
    past observations from forecasts."""
    p = build_system_prompt(_ctx(), now=datetime(2026, 5, 4, 12, 35, tzinfo=UTC))
    assert "Huidige tijd" in p
    assert "12:35 UTC" in p


def test_build_system_prompt_includes_explicit_now_anchor_en() -> None:
    p = build_system_prompt(
        _ctx(language="en"), now=datetime(2026, 5, 4, 12, 35, tzinfo=UTC)
    )
    assert "Current time" in p
    assert "12:35 UTC" in p


def test_major_cities_includes_amsterdam_and_utrecht() -> None:
    names = {c.name for c in MAJOR_CITIES}
    # Sanity: at least the cities the user asked the assistant to compare.
    assert {"Amsterdam", "Rotterdam", "Utrecht", "Den Haag"} <= names


def test_summarise_city_samples_computes_peak_and_total() -> None:
    samples = [
        ChatRainSample(
            minutes_ahead=0,
            mm_per_h=0.0,
            valid_at=datetime(2026, 5, 4, 12, 0, tzinfo=UTC),
        ),
        ChatRainSample(
            minutes_ahead=30,
            mm_per_h=2.4,
            valid_at=datetime(2026, 5, 4, 12, 30, tzinfo=UTC),
        ),
        ChatRainSample(
            minutes_ahead=60,
            mm_per_h=0.6,
            valid_at=datetime(2026, 5, 4, 13, 0, tzinfo=UTC),
        ),
    ]
    s = summarise_city_samples("Utrecht", samples)
    assert s.name == "Utrecht"
    assert s.peak_mm_per_h == 2.4
    # 5-minute cadence → divide sum by 12 to get total mm.
    assert s.total_mm == pytest.approx((2.4 + 0.6) / 12.0)


def test_summarise_city_samples_empty_returns_zeros() -> None:
    s = summarise_city_samples("Leeuwarden", [])
    assert s.peak_mm_per_h == 0.0
    assert s.total_mm == 0.0


def test_format_cities_rain_context_sorts_dry_first_and_marks_dry() -> None:
    rows = [
        CityRainSummary(name="Rotterdam", peak_mm_per_h=2.4, total_mm=1.2),
        CityRainSummary(name="Amsterdam", peak_mm_per_h=0.0, total_mm=0.0),
        CityRainSummary(name="Utrecht", peak_mm_per_h=0.5, total_mm=0.3),
    ]
    out = format_cities_rain_context(rows)
    lines = out.splitlines()
    assert lines[0].startswith("- Amsterdam:")
    assert "droog" in lines[0]
    assert lines[1].startswith("- Utrecht:")
    assert "piek 0.5 mm/u" in lines[1]
    assert lines[2].startswith("- Rotterdam:")
    assert "totaal 1.2 mm" in lines[2]


def test_format_cities_rain_context_english_uses_english_labels() -> None:
    rows = [
        CityRainSummary(name="Amsterdam", peak_mm_per_h=0.0, total_mm=0.0),
        CityRainSummary(name="Rotterdam", peak_mm_per_h=2.4, total_mm=1.2),
    ]
    out = format_cities_rain_context(rows, language="en")
    assert "dry" in out
    assert "peak 2.4 mm/h" in out
    assert "total 1.2 mm" in out


def test_format_cities_rain_context_empty_returns_empty_string() -> None:
    assert format_cities_rain_context([]) == ""


def test_build_system_prompt_includes_cities_block_when_provided() -> None:
    block = "- Utrecht: droog\n- Rotterdam: piek 2.4 mm/u, totaal 1.2 mm"
    p = build_system_prompt(_ctx(), cities_block=block)
    assert "Andere grote steden" in p
    assert "Utrecht" in p
    assert "Rotterdam" in p
    assert "2.4 mm/u" in p


def test_build_system_prompt_omits_cities_section_when_block_missing() -> None:
    p = build_system_prompt(_ctx(), cities_block=None)
    assert "Andere grote steden" not in p


def test_build_system_prompt_english_includes_cities_block() -> None:
    block = "- Amsterdam: dry\n- Rotterdam: peak 2.4 mm/h, total 1.2 mm"
    p = build_system_prompt(_ctx(language="en"), cities_block=block)
    assert "Other major Dutch cities" in p
    assert "Rotterdam" in p
