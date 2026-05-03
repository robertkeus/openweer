import { describe, expect, it } from "vitest";
import {
  DEFAULT_LOCATION,
  KNOWN_LOCATIONS,
  findLocationBySlug,
} from "./locations";

describe("locations", () => {
  it("default is Amsterdam", () => {
    expect(DEFAULT_LOCATION.slug).toBe("amsterdam");
    expect(DEFAULT_LOCATION.lat).toBeCloseTo(52.37, 2);
  });

  it("findLocationBySlug is case-insensitive", () => {
    expect(findLocationBySlug("Rotterdam")?.name).toBe("Rotterdam");
    expect(findLocationBySlug("ROTTERDAM")?.name).toBe("Rotterdam");
  });

  it("returns null for unknown slug", () => {
    expect(findLocationBySlug("atlantis")).toBeNull();
  });

  it("every location has unique slug", () => {
    const slugs = KNOWN_LOCATIONS.map((l) => l.slug);
    expect(new Set(slugs).size).toBe(slugs.length);
  });

  it("every location has NL bbox-compatible coordinates", () => {
    for (const loc of KNOWN_LOCATIONS) {
      expect(loc.lat).toBeGreaterThanOrEqual(50);
      expect(loc.lat).toBeLessThanOrEqual(54);
      expect(loc.lon).toBeGreaterThanOrEqual(3);
      expect(loc.lon).toBeLessThanOrEqual(8);
    }
  });
});
