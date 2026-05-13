/**
 * Persists the user's accepted location across page refreshes.
 *
 * The data lives only in this browser's localStorage — it is never sent to
 * the server, so storing full-precision coords is fine here (CLAUDE.md A09
 * rounds for *analytics*, not for on-device personalisation).
 */

import { isInNetherlands } from "./geolocation";
import type { ResolvedLocation } from "./use-geolocation";

export const STORAGE_KEY = "openweer-location";

export interface StoredLocation {
  accepted: true;
  name: string;
  lat: number;
  lon: number;
  ts: number;
}

export function getStoredLocation(): StoredLocation | null {
  if (typeof window === "undefined") return null;
  const raw = window.localStorage.getItem(STORAGE_KEY);
  if (!raw) return null;
  try {
    const parsed = JSON.parse(raw) as unknown;
    if (!isStored(parsed)) return null;
    if (!isInNetherlands({ lat: parsed.lat, lon: parsed.lon })) return null;
    return parsed;
  } catch {
    return null;
  }
}

export function setStoredLocation(loc: ResolvedLocation): void {
  if (typeof window === "undefined") return;
  const value: StoredLocation = {
    accepted: true,
    name: loc.name,
    lat: loc.lat,
    lon: loc.lon,
    ts: Date.now(),
  };
  window.localStorage.setItem(STORAGE_KEY, JSON.stringify(value));
}

export function clearStoredLocation(): void {
  if (typeof window === "undefined") return;
  window.localStorage.removeItem(STORAGE_KEY);
}

function isStored(v: unknown): v is StoredLocation {
  if (typeof v !== "object" || v === null) return false;
  const o = v as Record<string, unknown>;
  return (
    o.accepted === true &&
    typeof o.name === "string" &&
    typeof o.lat === "number" &&
    Number.isFinite(o.lat) &&
    typeof o.lon === "number" &&
    Number.isFinite(o.lon) &&
    typeof o.ts === "number" &&
    Number.isFinite(o.ts)
  );
}
