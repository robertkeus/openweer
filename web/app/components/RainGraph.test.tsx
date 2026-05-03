import { describe, expect, it } from "vitest";
import { render, screen } from "@testing-library/react";
import type { RainSample } from "~/lib/api";
import { RainGraph, RainSummary } from "./RainGraph";

const sample = (minutes: number, mm: number): RainSample => ({
  minutes_ahead: minutes,
  mm_per_h: mm,
  valid_at: new Date(Date.parse("2026-05-03T06:30Z") + minutes * 60_000).toISOString(),
});

describe("RainGraph", () => {
  it("renders an svg with one bar per sample", () => {
    const samples = [sample(0, 0), sample(5, 0.4), sample(10, 1.2)];
    render(<RainGraph samples={samples} />);
    const svg = screen.getByRole("img");
    expect(svg).toBeInTheDocument();
    expect(svg.querySelectorAll("rect").length).toBe(3);
  });

  it("renders nothing for empty samples", () => {
    const { container } = render(<RainGraph samples={[]} />);
    expect(container).toBeEmptyDOMElement();
  });

  it("includes accessible description with total rainfall", () => {
    const samples = Array.from({ length: 25 }, (_, i) => sample(i * 5, 1.2));
    render(<RainGraph samples={samples} />);
    const desc = screen.getByText(/Totaal naar verwachting/);
    expect(desc).toBeInTheDocument();
  });
});

describe("RainSummary", () => {
  it("dry verdict when no rain", () => {
    const samples = Array.from({ length: 25 }, (_, i) => sample(i * 5, 0));
    render(<RainSummary samples={samples} />);
    expect(screen.getByText(/blijft droog/)).toBeInTheDocument();
  });

  it("light verdict for moderate intensity", () => {
    const samples = [sample(0, 0.1), sample(5, 0.5)];
    render(<RainSummary samples={samples} />);
    expect(screen.getByText(/Lichte regen/)).toBeInTheDocument();
  });

  it("heavy verdict for severe peak", () => {
    const samples = [sample(0, 1.0), sample(5, 12.0), sample(10, 0.5)];
    render(<RainSummary samples={samples} />);
    expect(screen.getByText(/Zware buien/)).toBeInTheDocument();
  });

  it("renders total expected rainfall in mm", () => {
    const samples = Array.from({ length: 24 }, () => sample(0, 6.0));
    render(<RainSummary samples={samples} />);
    // 6 mm/h * 24 samples * 5min = 12 mm
    expect(screen.getByText(/12\.0 mm/)).toBeInTheDocument();
  });
});
