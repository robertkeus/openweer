import { describe, expect, it } from "vitest";
import { isInNetherlands, roundCoord } from "./geolocation";

describe("isInNetherlands", () => {
  it.each([
    [{ lat: 52.37, lon: 4.89 }, true], // Amsterdam
    [{ lat: 50.85, lon: 5.69 }, true], // Maastricht
    [{ lat: 53.22, lon: 6.57 }, true], // Groningen
    [{ lat: 50.0, lon: 4.0 }, false], // too far south
    [{ lat: 52.5, lon: 2.5 }, false], // too far west (UK)
    [{ lat: 52.5, lon: 9.0 }, false], // too far east (DE)
    [{ lat: 54.5, lon: 5.0 }, false], // too far north
  ])("%j -> %s", (c, expected) => {
    expect(isInNetherlands(c)).toBe(expected);
  });
});

describe("roundCoord", () => {
  it("rounds to 4 decimals by default", () => {
    expect(roundCoord(52.3702345)).toBe(52.3702);
  });

  it("respects custom decimals", () => {
    expect(roundCoord(52.378765, 2)).toBe(52.38);
  });
});
