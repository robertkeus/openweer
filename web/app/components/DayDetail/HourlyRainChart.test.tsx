import { describe, expect, it } from "vitest";
import { render, screen } from "@testing-library/react";
import type { HourlySlot } from "~/lib/api";
import { HourlyRainChart } from "./HourlyRainChart";

function makeSlots(): HourlySlot[] {
  return Array.from({ length: 24 }, (_, h) => ({
    time: new Date(Date.UTC(2026, 4, 17, h - 2)).toISOString(),
    weather_code: 1,
    temperature_c: 12 + h,
    apparent_temperature_c: 11 + h,
    precipitation_mm: h % 6 === 0 ? 1.2 : 0,
    precipitation_probability_pct: 30,
    wind_speed_kph: 10,
    wind_direction_deg: 200,
    wind_gusts_kph: 16,
    relative_humidity_pct: 70,
    cloud_cover_pct: 50,
    uv_index: 2,
    is_day: h >= 6 && h < 21,
    source: "knmi-harmonie",
  }));
}

describe("HourlyRainChart", () => {
  it("renders one rect per slot", () => {
    const slots = makeSlots();
    render(<HourlyRainChart slots={slots} pending={false} />);
    const svg = screen.getByRole("img");
    expect(svg.querySelectorAll("rect").length).toBe(slots.length);
  });

  it("includes title and desc for screen readers", () => {
    render(<HourlyRainChart slots={makeSlots()} pending={false} />);
    expect(
      document.querySelector('h3[id="day-detail-rain"]')?.textContent,
    ).toBe("Regen per uur");
    const svg = screen.getByRole("img");
    expect(svg.querySelector("title")).not.toBeNull();
    expect(svg.querySelector("desc")).not.toBeNull();
  });

  it("renders a skeleton when pending with no slots", () => {
    render(<HourlyRainChart slots={[]} pending={true} />);
    expect(
      document.querySelectorAll('[class*="animate-pulse"]').length,
    ).toBeGreaterThan(0);
  });

  it("renders nothing when slots are empty and not pending", () => {
    const { container } = render(
      <HourlyRainChart slots={[]} pending={false} />,
    );
    expect(container.firstChild).toBeNull();
  });
});
