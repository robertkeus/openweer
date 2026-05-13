import { afterEach, describe, expect, it } from "vitest";
import {
  STORAGE_KEY,
  clearStoredLocation,
  getStoredLocation,
  setStoredLocation,
} from "./location-store";

afterEach(() => {
  window.localStorage.clear();
});

describe("getStoredLocation", () => {
  it("returns null when nothing is stored", () => {
    expect(getStoredLocation()).toBeNull();
  });

  it("returns null for malformed JSON", () => {
    window.localStorage.setItem(STORAGE_KEY, "not json");
    expect(getStoredLocation()).toBeNull();
  });

  it("returns null when fields are missing or wrong types", () => {
    window.localStorage.setItem(
      STORAGE_KEY,
      JSON.stringify({ accepted: true, lat: "52.1", lon: 5.1, ts: 0 }),
    );
    expect(getStoredLocation()).toBeNull();
  });

  it("returns null when coords fall outside the NL bbox", () => {
    window.localStorage.setItem(
      STORAGE_KEY,
      JSON.stringify({
        accepted: true,
        name: "Paris",
        lat: 48.85,
        lon: 2.35,
        ts: Date.now(),
      }),
    );
    expect(getStoredLocation()).toBeNull();
  });

  it("round-trips a valid NL location", () => {
    setStoredLocation({ name: "Groningen", lat: 53.22, lon: 6.57 });
    const stored = getStoredLocation();
    expect(stored).not.toBeNull();
    expect(stored?.name).toBe("Groningen");
    expect(stored?.lat).toBeCloseTo(53.22);
    expect(stored?.lon).toBeCloseTo(6.57);
    expect(stored?.accepted).toBe(true);
    expect(typeof stored?.ts).toBe("number");
  });
});

describe("clearStoredLocation", () => {
  it("removes the persisted entry", () => {
    setStoredLocation({ name: "Utrecht", lat: 52.09, lon: 5.12 });
    expect(getStoredLocation()).not.toBeNull();
    clearStoredLocation();
    expect(getStoredLocation()).toBeNull();
  });
});
