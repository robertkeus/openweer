"""Pure-function tests for the /api/chat prompt builders."""

from __future__ import annotations

from datetime import datetime, timezone

from openweer.api.routes._chat_prompt import (
    ChatContext,
    ChatRainSample,
    build_system_prompt,
    format_rain_context,
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
            valid_at=datetime(2026, 5, 4, 12, i * 5 % 60, tzinfo=timezone.utc),
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
            valid_at=datetime(2026, 5, 4, 12, 0, tzinfo=timezone.utc),
        ),
        ChatRainSample(
            minutes_ahead=30,
            mm_per_h=2.4,
            valid_at=datetime(2026, 5, 4, 12, 30, tzinfo=timezone.utc),
        ),
        ChatRainSample(
            minutes_ahead=60,
            mm_per_h=0.5,
            valid_at=datetime(2026, 5, 4, 13, 0, tzinfo=timezone.utc),
        ),
    ]
    line = format_rain_context(samples)
    assert "2.4" in line  # peak intensity
    assert "12:30" in line  # peak time UTC
    assert "totaal" in line.lower()


def test_format_rain_context_empty_returns_dutch_fallback() -> None:
    line = format_rain_context([])
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
        _ctx(cursor_at=datetime(2026, 5, 4, 13, 25, tzinfo=timezone.utc))
    )
    assert "13:25" in p


def test_build_system_prompt_says_now_when_cursor_unset() -> None:
    p = build_system_prompt(_ctx(cursor_at=None))
    assert "nu" in p.lower()
