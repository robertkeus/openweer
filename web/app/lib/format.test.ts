import { describe, expect, it } from "vitest";
import {
  formatMmPerHour,
  formatRelativeOffset,
  rainVerdict,
} from "./format";

describe("formatMmPerHour", () => {
  it("uses Dutch comma decimal", () => {
    expect(formatMmPerHour(1.234)).toBe("1,2 mm/u");
  });

  it("renders zero with one decimal", () => {
    expect(formatMmPerHour(0)).toBe("0,0 mm/u");
  });
});

describe("rainVerdict", () => {
  it.each([
    [0.0, "droog"],
    [0.05, "droog"],
    [0.1, "licht"],
    [0.99, "licht"],
    [1.0, "matig"],
    [4.99, "matig"],
    [5.0, "zwaar"],
    [50, "zwaar"],
  ])("%p -> %s", (mm, verdict) => {
    expect(rainVerdict(mm)).toBe(verdict);
  });
});

describe("formatRelativeOffset", () => {
  it.each([
    [0, "+0m"],
    [5, "+5m"],
    [60, "+1u"],
    [95, "+1u 35m"],
    [-30, "-30m"],
    [-120, "-2u"],
  ])("%p -> %s", (mins, expected) => {
    expect(formatRelativeOffset(mins)).toBe(expected);
  });
});
