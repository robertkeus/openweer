import { describe, expect, it } from "vitest";
import type { HourlySlot } from "~/lib/api";
import {
  compassFor,
  conditionLabelNl,
  fmtTemp,
  formatHHmmFromIso,
  hourOfSlot,
  parseHourFromIso,
  slotsForDate,
  wmoToCondition,
} from "./util";

const slot = (iso: string): HourlySlot => ({
  time: iso,
  weather_code: 1,
  temperature_c: 15,
  apparent_temperature_c: 14,
  precipitation_mm: 0,
  precipitation_probability_pct: 10,
  wind_speed_kph: 10,
  wind_direction_deg: 220,
  wind_gusts_kph: 14,
  relative_humidity_pct: 70,
  cloud_cover_pct: 40,
  uv_index: 2,
  is_day: true,
  source: "knmi-harmonie",
});

describe("slotsForDate", () => {
  it("filters slots whose Amsterdam-local date matches", () => {
    // 2026-05-17 00:00 +02:00 == 2026-05-16 22:00 UTC
    const a = slot("2026-05-16T22:00:00Z");
    const b = slot("2026-05-17T10:00:00Z");
    const c = slot("2026-05-18T01:00:00Z");
    const out = slotsForDate([a, b, c], "2026-05-17");
    expect(out.map((s) => s.time)).toEqual([a.time, b.time]);
  });
});

describe("hourOfSlot", () => {
  it("returns the Europe/Amsterdam hour", () => {
    // 10:00 UTC during DST → 12:00 in Amsterdam
    expect(hourOfSlot(slot("2026-05-17T10:00:00Z"))).toBe(12);
  });
});

describe("compassFor", () => {
  it("maps cardinals", () => {
    expect(compassFor(0)).toBe("N");
    expect(compassFor(90)).toBe("O");
    expect(compassFor(180)).toBe("Z");
    expect(compassFor(270)).toBe("W");
  });
  it("returns null for nullish input", () => {
    expect(compassFor(null)).toBeNull();
    expect(compassFor(undefined)).toBeNull();
  });
});

describe("formatHHmmFromIso / parseHourFromIso", () => {
  it("slices HH:mm from a yyyy-MM-ddTHH:mm string", () => {
    expect(formatHHmmFromIso("2026-05-17T05:41")).toBe("05:41");
    expect(parseHourFromIso("2026-05-17T05:41")).toBe(5);
  });
  it("returns null for nullish input", () => {
    expect(formatHHmmFromIso(null)).toBeNull();
    expect(parseHourFromIso(undefined)).toBeNull();
  });
});

describe("conditionLabelNl / wmoToCondition / fmtTemp", () => {
  it("maps WMO codes to condition kinds", () => {
    expect(wmoToCondition(0)).toBe("clear");
    expect(wmoToCondition(2)).toBe("partly-cloudy");
    expect(wmoToCondition(45)).toBe("fog");
    expect(wmoToCondition(63)).toBe("rain");
    expect(wmoToCondition(95)).toBe("thunder");
    expect(wmoToCondition(null)).toBe("unknown");
  });

  it("renders Dutch labels", () => {
    expect(conditionLabelNl("rain")).toBe("Regen");
    expect(conditionLabelNl("unknown")).toBe("—");
  });

  it("formats temperature with negative sign and °", () => {
    expect(fmtTemp(0)).toBe("0°");
    expect(fmtTemp(-3)).toBe("−3°");
    expect(fmtTemp(null)).toBe("—");
  });
});
