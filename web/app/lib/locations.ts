/**
 * Tiny built-in directory of Dutch locations for v1. The full search will
 * later go through Nominatim (proxied behind /api/locations/search).
 */

export interface Location {
  slug: string;
  name: string;
  lat: number;
  lon: number;
}

export const DEFAULT_LOCATION: Location = {
  slug: "amsterdam",
  name: "Amsterdam",
  lat: 52.37,
  lon: 4.89,
};

export const KNOWN_LOCATIONS: readonly Location[] = [
  DEFAULT_LOCATION,
  { slug: "rotterdam", name: "Rotterdam", lat: 51.92, lon: 4.48 },
  { slug: "den-haag", name: "Den Haag", lat: 52.07, lon: 4.3 },
  { slug: "utrecht", name: "Utrecht", lat: 52.09, lon: 5.12 },
  { slug: "eindhoven", name: "Eindhoven", lat: 51.44, lon: 5.48 },
  { slug: "groningen", name: "Groningen", lat: 53.22, lon: 6.57 },
  { slug: "maastricht", name: "Maastricht", lat: 50.85, lon: 5.69 },
  { slug: "arnhem", name: "Arnhem", lat: 51.98, lon: 5.91 },
  { slug: "tilburg", name: "Tilburg", lat: 51.55, lon: 5.09 },
  { slug: "leeuwarden", name: "Leeuwarden", lat: 53.2, lon: 5.79 },
  { slug: "middelburg", name: "Middelburg", lat: 51.5, lon: 3.61 },
  { slug: "enschede", name: "Enschede", lat: 52.22, lon: 6.89 },
];

const BY_SLUG: ReadonlyMap<string, Location> = new Map(
  KNOWN_LOCATIONS.map((l) => [l.slug, l]),
);

export function findLocationBySlug(slug: string): Location | null {
  return BY_SLUG.get(slug.toLowerCase()) ?? null;
}
