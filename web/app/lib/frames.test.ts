import { describe, expect, it } from "vitest";
import type { Frame } from "./api";
import {
  defaultPlayableFrames,
  findCurrentIndex,
  partitionFrames,
  tileUrlTemplate,
} from "./frames";

const f = (id: string, kind: Frame["kind"], ts: string): Frame => ({
  id,
  ts,
  kind,
  cadence_minutes: kind === "hourly" ? 60 : 5,
  max_zoom: 10,
});

describe("partitionFrames", () => {
  it("splits and sorts each kind chronologically", () => {
    const frames = [
      f("c", "nowcast", "2026-05-03T07:00Z"),
      f("a", "observed", "2026-05-03T05:55Z"),
      f("b", "observed", "2026-05-03T06:00Z"),
      f("d", "nowcast", "2026-05-03T06:55Z"),
      f("e", "hourly", "2026-05-03T09:00Z"),
    ];
    const { observed, nowcast, hourly } = partitionFrames(frames);
    expect(observed.map((x) => x.id)).toEqual(["a", "b"]);
    expect(nowcast.map((x) => x.id)).toEqual(["d", "c"]);
    expect(hourly.map((x) => x.id)).toEqual(["e"]);
  });
});

describe("defaultPlayableFrames", () => {
  it("returns observed + nowcast, never hourly", () => {
    const frames = [
      f("o", "observed", "2026-05-03T05:55Z"),
      f("n", "nowcast", "2026-05-03T06:00Z"),
      f("h", "hourly", "2026-05-03T09:00Z"),
    ];
    const playable = defaultPlayableFrames(frames);
    expect(playable.map((x) => x.kind)).toEqual(["observed", "nowcast"]);
  });
});

describe("findCurrentIndex", () => {
  it("picks the frame closest to now", () => {
    const now = Date.now();
    const frames = [
      f("a", "observed", new Date(now - 60_000).toISOString()),
      f("b", "observed", new Date(now - 1000).toISOString()),
      f("c", "nowcast", new Date(now + 60_000).toISOString()),
    ];
    expect(findCurrentIndex(frames)).toBe(1);
  });

  it("returns 0 for empty input", () => {
    expect(findCurrentIndex([])).toBe(0);
  });
});

describe("tileUrlTemplate", () => {
  it("produces a maplibre-compatible XYZ template", () => {
    expect(tileUrlTemplate(f("20260503T0630Z", "observed", "2026-05-03T06:30Z"))).toBe(
      "/tiles/20260503T0630Z/{z}/{x}/{y}.png",
    );
  });
});
