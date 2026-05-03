import { afterEach, beforeEach, describe, expect, it } from "vitest";
import {
  ANTI_FOUC_SCRIPT,
  applyTheme,
  getStoredTheme,
  resolveTheme,
  setStoredTheme,
  STORAGE_KEY,
} from "./theme";

describe("resolveTheme", () => {
  it("passes through explicit modes", () => {
    expect(resolveTheme("light", true)).toBe("light");
    expect(resolveTheme("dark", false)).toBe("dark");
  });

  it("follows the system preference for system mode", () => {
    expect(resolveTheme("system", true)).toBe("dark");
    expect(resolveTheme("system", false)).toBe("light");
  });
});

describe("applyTheme", () => {
  beforeEach(() => {
    document.documentElement.classList.remove("dark");
  });

  it("toggles the dark class on <html>", () => {
    applyTheme("dark");
    expect(document.documentElement.classList.contains("dark")).toBe(true);
    applyTheme("light");
    expect(document.documentElement.classList.contains("dark")).toBe(false);
  });
});

describe("storage helpers", () => {
  afterEach(() => {
    window.localStorage.clear();
  });

  it("defaults to system when nothing is stored", () => {
    expect(getStoredTheme()).toBe("system");
  });

  it("rejects garbage values from localStorage", () => {
    window.localStorage.setItem(STORAGE_KEY, "neon");
    expect(getStoredTheme()).toBe("system");
  });

  it("round-trips known modes", () => {
    setStoredTheme("dark");
    expect(getStoredTheme()).toBe("dark");
    setStoredTheme("light");
    expect(getStoredTheme()).toBe("light");
  });
});

describe("ANTI_FOUC_SCRIPT", () => {
  it("references the storage key and dark class", () => {
    expect(ANTI_FOUC_SCRIPT).toContain(STORAGE_KEY);
    expect(ANTI_FOUC_SCRIPT).toContain("classList.toggle('dark'");
  });
});
