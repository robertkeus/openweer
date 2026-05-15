import { describe, expect, it } from "vitest";
import { render, screen } from "@testing-library/react";
import type { RainResponse, RainSample } from "~/lib/api";
import { WeatherNowCard } from "./WeatherNowCard";

const now = new Date(Date.parse("2026-05-03T06:30Z"));
const sample = (minutes: number, mm: number): RainSample => ({
  minutes_ahead: minutes,
  mm_per_h: mm,
  valid_at: new Date(now.getTime() + minutes * 60_000).toISOString(),
});

const dryRain: RainResponse = {
  lat: 52.37,
  lon: 4.89,
  analysis_at: now.toISOString(),
  samples: Array.from({ length: 25 }, (_, i) => sample(i * 5, 0)),
};

const drizzleRain: RainResponse = {
  lat: 52.37,
  lon: 4.89,
  analysis_at: now.toISOString(),
  samples: [sample(0, 0.12), sample(5, 0.4), sample(10, 0.6)],
};

describe("WeatherNowCard", () => {
  it("shows the current intensity in mm/u with Dutch decimal", () => {
    render(<WeatherNowCard locationName="Amsterdam" rain={drizzleRain} />);
    const headline = screen.getByLabelText("Huidige neerslag");
    expect(headline).toHaveTextContent("0,1");
    expect(headline).toHaveTextContent("mm/u");
  });

  it("says it stays dry when there's no rain in the next 2h", () => {
    render(<WeatherNowCard locationName="Amsterdam" rain={dryRain} />);
    expect(screen.getByText(/blijft droog/)).toBeInTheDocument();
  });

  it("shows a placeholder when no rain data is available", () => {
    render(<WeatherNowCard locationName="Amsterdam" rain={null} />);
    expect(screen.getByText(/Nog geen radardata/)).toBeInTheDocument();
  });

  it("uses the heavy headline when peaks exceed 5 mm/u", () => {
    const stormy: RainResponse = {
      ...drizzleRain,
      samples: [sample(0, 1), sample(5, 8), sample(10, 12)],
    };
    render(<WeatherNowCard locationName="Amsterdam" rain={stormy} />);
    expect(screen.getByText(/Zware buien op komst/)).toBeInTheDocument();
  });

  // /api/rain returns radar nowcast (0–120 min) and HARMONIE (up to +24 h).
  // The "Komende 2 uur" copy must ignore the HARMONIE tail — otherwise rain at
  // +4 h would say "Matige buien op komst" above a "blijft droog" headline.
  it("ignores samples beyond +2h when picking the headline and peak", () => {
    const dryNowcastWetLater: RainResponse = {
      ...drizzleRain,
      samples: [
        ...Array.from({ length: 25 }, (_, i) => sample(i * 5, 0)),
        sample(180, 1.3),
        sample(240, 2.0),
      ],
    };
    render(
      <WeatherNowCard locationName="Amsterdam" rain={dryNowcastWetLater} />,
    );
    expect(screen.getByText(/blijft droog/)).toBeInTheDocument();
    expect(screen.queryByText(/op komst/)).not.toBeInTheDocument();
  });
});
