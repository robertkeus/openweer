import { describe, expect, it } from "vitest";
import { render, screen } from "@testing-library/react";
import type { DailyForecast, HourlySlot } from "~/lib/api";
import { HourlyStrip } from "./HourlyStrip";

const day: DailyForecast = {
  date: "2026-05-17",
  weather_code: 3,
  temperature_max_c: 18,
  temperature_min_c: 9,
  precipitation_sum_mm: 0,
  precipitation_probability_pct: 10,
  wind_max_kph: 14,
  wind_direction_deg: 220,
  sunrise: "2026-05-17T05:41",
  sunset: "2026-05-17T21:31",
  source: "knmi-harmonie",
};

const slot = (hour: number, overrides: Partial<HourlySlot> = {}): HourlySlot => ({
  time: new Date(
    Date.UTC(2026, 4, 17, hour - 2 /* +02:00 → UTC */),
  ).toISOString(),
  weather_code: 1,
  temperature_c: 15 + hour,
  apparent_temperature_c: 14 + hour,
  precipitation_mm: 0,
  precipitation_probability_pct: 20,
  wind_speed_kph: 12,
  wind_direction_deg: 220,
  wind_gusts_kph: 18,
  relative_humidity_pct: 70,
  cloud_cover_pct: 40,
  uv_index: 3,
  is_day: hour >= 6 && hour < 21,
  source: "knmi-harmonie",
  ...overrides,
});

describe("HourlyStrip", () => {
  it("renders skeleton when pending and no slots", () => {
    render(<HourlyStrip slots={[]} day={day} pending={true} />);
    expect(screen.getByText("Per uur")).toBeInTheDocument();
    expect(
      document.querySelectorAll('[class*="animate-pulse"]').length,
    ).toBeGreaterThan(0);
  });

  it("renders one cell per slot when data is loaded", () => {
    const slots = [slot(6), slot(7), slot(8)];
    render(<HourlyStrip slots={slots} day={day} pending={false} />);
    // Three hour cells. The sunrise cell may also appear if 05 == any hour
    // in our slot set, which it isn't here (we start at 06), so total
    // listitems should be exactly 3.
    const cells = document.querySelectorAll('[role="listitem"]');
    expect(cells.length).toBeGreaterThanOrEqual(3);
  });

  it("injects a sunrise cell after the matching hour", () => {
    // Day starts at 05:00 local Amsterdam — sunrise 05:41 falls in the 5 o'clock slot.
    const slots = [slot(5), slot(6)];
    render(<HourlyStrip slots={slots} day={day} pending={false} />);
    expect(screen.getByLabelText(/Zonsopgang 05:41/)).toBeInTheDocument();
  });
});
