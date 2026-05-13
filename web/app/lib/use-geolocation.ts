import { useCallback, useState, useTransition } from "react";
import {
  GeolocationError,
  getCurrentPosition,
  isInNetherlands,
  type Coords,
} from "./geolocation";
import { setStoredLocation } from "./location-store";

export interface ResolvedLocation extends Coords {
  name: string;
}

interface UseGeolocationResult {
  resolving: boolean;
  error: string | null;
  resolve: () => Promise<ResolvedLocation | null>;
  clearError: () => void;
}

interface NominatimReverseResult {
  address?: {
    city?: string;
    town?: string;
    village?: string;
    municipality?: string;
    county?: string;
    suburb?: string;
    neighbourhood?: string;
  };
  name?: string;
}

/**
 * Reverse-geocode lat/lon to a Dutch place name via Nominatim. Returns null
 * on any failure — callers should fall back to a generic label.
 */
export async function reverseGeocode(
  lat: number,
  lon: number,
  signal?: AbortSignal,
): Promise<string | null> {
  try {
    const url = new URL("https://nominatim.openstreetmap.org/reverse");
    url.searchParams.set("lat", lat.toString());
    url.searchParams.set("lon", lon.toString());
    url.searchParams.set("format", "jsonv2");
    url.searchParams.set("zoom", "12");
    url.searchParams.set("addressdetails", "1");
    const res = await fetch(url, {
      signal,
      headers: { "Accept-Language": "nl,en" },
    });
    if (!res.ok) return null;
    const data = (await res.json()) as NominatimReverseResult;
    const a = data.address ?? {};
    return (
      a.city ??
      a.town ??
      a.village ??
      a.municipality ??
      a.suburb ??
      a.neighbourhood ??
      a.county ??
      data.name ??
      null
    );
  } catch {
    return null;
  }
}

/** Wraps the browser geolocation flow with the NL-bbox guard and Dutch errors. */
export function useGeolocation(
  onResolved: (loc: ResolvedLocation) => void,
): UseGeolocationResult {
  const [resolving, setResolving] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [, startTransition] = useTransition();

  const resolve = useCallback(async () => {
    setError(null);
    setResolving(true);
    try {
      const pos = await getCurrentPosition();
      if (!isInNetherlands(pos)) {
        setError(
          "Je locatie ligt buiten Nederland — de radar dekt alleen de Lage Landen.",
        );
        return null;
      }
      // Reverse-geocode so the search bar shows the city (e.g. "Groningen")
      // instead of the generic "Jouw locatie" placeholder.
      const placeName = await reverseGeocode(pos.lat, pos.lon);
      const resolved: ResolvedLocation = {
        name: placeName ?? "Jouw locatie",
        lat: pos.lat,
        lon: pos.lon,
      };
      setStoredLocation(resolved);
      startTransition(() => onResolved(resolved));
      return resolved;
    } catch (e) {
      setError(
        e instanceof GeolocationError
          ? e.message
          : "Er ging iets mis bij het ophalen van je locatie.",
      );
      return null;
    } finally {
      setResolving(false);
    }
  }, [onResolved]);

  return {
    resolving,
    error,
    resolve,
    clearError: () => setError(null),
  };
}
