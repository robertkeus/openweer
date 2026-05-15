/**
 * Browser geolocation, with NL-bbox guard and Dutch error messages.
 *
 * `getCurrentPosition` resolves with `{ lat, lon }` rounded to 4 decimals
 * (~10 m precision — enough for the 1 km radar grid, plus a privacy nudge).
 */

export interface Coords {
  lat: number;
  lon: number;
}

export const NL_BBOX = {
  minLat: 50.6,
  maxLat: 53.7,
  minLon: 3.0,
  maxLon: 7.4,
} as const;

export class GeolocationError extends Error {}

/** Returns `true` if `c` lies within the NL bounding box used by the radar. */
export function isInNetherlands(c: Coords): boolean {
  return (
    c.lat >= NL_BBOX.minLat &&
    c.lat <= NL_BBOX.maxLat &&
    c.lon >= NL_BBOX.minLon &&
    c.lon <= NL_BBOX.maxLon
  );
}

export function roundCoord(value: number, decimals = 4): number {
  const k = 10 ** decimals;
  return Math.round(value * k) / k;
}

export async function getCurrentPosition(
  options: PositionOptions = { timeout: 15000, maximumAge: 60_000 },
): Promise<Coords> {
  if (typeof navigator === "undefined" || !("geolocation" in navigator)) {
    throw new GeolocationError("Je browser ondersteunt geen locatiebepaling.");
  }
  return new Promise((resolve, reject) => {
    navigator.geolocation.getCurrentPosition(
      (pos) =>
        resolve({
          lat: roundCoord(pos.coords.latitude),
          lon: roundCoord(pos.coords.longitude),
        }),
      (err) => reject(translate(err)),
      options,
    );
  });
}

function translate(err: GeolocationPositionError): GeolocationError {
  switch (err.code) {
    case err.PERMISSION_DENIED:
      return new GeolocationError(
        "Geen toestemming gekregen voor je locatie. Kies hieronder “Niet nu” en zoek je plaats via de balk bovenaan.",
      );
    case err.POSITION_UNAVAILABLE:
      // macOS-Chrome in particular returns this whenever Location Services
      // is off for the browser, or CoreLocation can't get a WiFi fix.
      // "Probeer later opnieuw" is a dead end — point the user at the
      // search bar so they can pick a place by name instead.
      return new GeolocationError(
        "Je browser kon je locatie niet bepalen. Kies “Niet nu” en zoek je plaats via de balk bovenaan.",
      );
    case err.TIMEOUT:
      return new GeolocationError(
        "Het bepalen van je locatie duurde te lang. Probeer het opnieuw, of zoek je plaats via de balk bovenaan.",
      );
    default:
      return new GeolocationError(
        "Er ging iets mis bij het ophalen van je locatie. Zoek je plaats via de balk bovenaan.",
      );
  }
}
