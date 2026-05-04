/**
 * RadarMap — MapLibre multi-source animation, client-only.
 *
 * Pure rendering component. Slider state and the current frame index are
 * owned by the route via `useRadarTimeline`; the map only needs the frame
 * list and which index is currently visible.
 */

import { useEffect, useRef, useState } from "react";
import type { Frame } from "~/lib/api";
import { tileUrlTemplate } from "~/lib/frames";
import { isInNetherlands } from "~/lib/geolocation";
import { reverseGeocode } from "~/lib/use-geolocation";

interface Props {
  frames: Frame[];
  currentIndex: number;
  /** Optional center the map should fly to. */
  center?: { lat: number; lon: number };
  /** Fired when the user double-clicks a point on the map. */
  onLocationPick?: (loc: { name: string; lat: number; lon: number }) => void;
  className?: string;
}

const NL_CENTER: [number, number] = [5.3, 52.1];
const NL_BOUNDS: [number, number, number, number] = [3.0, 50.6, 7.4, 53.7];
const FADE_MS = 220;
const BASEMAP_LIGHT = "https://tiles.openfreemap.org/styles/positron";
// OpenFreeMap doesn't publish a dark style; CARTO's dark-matter is freely
// hosted and attribution-compatible.
const BASEMAP_DARK =
  "https://basemaps.cartocdn.com/gl/dark-matter-gl-style/style.json";

function basemapStyle(isDark: boolean): string {
  return isDark ? BASEMAP_DARK : BASEMAP_LIGHT;
}

function isDocumentDark(): boolean {
  return typeof document !== "undefined" &&
    document.documentElement.classList.contains("dark");
}

const RADAR_MIN_ZOOM = 6;
const RADAR_MAX_ZOOM = 10;

export function RadarMap({
  frames,
  currentIndex,
  center,
  onLocationPick,
  className = "absolute inset-0",
}: Props) {
  const containerRef = useRef<HTMLDivElement | null>(null);
  const mapRef = useRef<unknown>(null);
  const markerRef = useRef<unknown>(null);
  const onLocationPickRef = useRef(onLocationPick);
  const [mapReady, setMapReady] = useState(false);

  // Keep the ref pointing at the latest callback so the dblclick handler
  // (registered once when the map mounts) always sees the current state.
  useEffect(() => {
    onLocationPickRef.current = onLocationPick;
  }, [onLocationPick]);

  // ---- 1) Mount the map once ----
  useEffect(() => {
    if (!containerRef.current) return;
    let cancelled = false;
    let map: unknown;

    (async () => {
      const maplibre = await import("maplibre-gl");
      await import("maplibre-gl/dist/maplibre-gl.css");
      if (cancelled || !containerRef.current) return;

      map = new maplibre.Map({
        container: containerRef.current,
        style: basemapStyle(isDocumentDark()),
        center: center ? [center.lon, center.lat] : NL_CENTER,
        zoom: 7,
        minZoom: 5,
        maxZoom: 10,
        attributionControl: false,
        cooperativeGestures: false,
      });
      mapRef.current = map;
      const m = map as InstanceType<typeof maplibre.Map>;

      m.addControl(
        new maplibre.AttributionControl({
          customAttribution:
            'Radar © <a href="https://www.knmi.nl">KNMI</a> · Kaart © <a href="https://openfreemap.org">OpenFreeMap</a> / <a href="https://carto.com/attributions">CARTO</a>',
          compact: true,
        }),
        "bottom-right",
      );

      // Use double-click to pick a location instead of zooming in.
      m.doubleClickZoom.disable();
      m.on("dblclick", (e: { lngLat: { lng: number; lat: number } }) => {
        const { lng, lat } = e.lngLat;
        if (!isInNetherlands({ lat, lon: lng })) return;
        const round = (v: number) => Math.round(v * 10000) / 10000;
        const rlat = round(lat);
        const rlon = round(lng);
        // Optimistically apply the pin with a coordinate-style label, then
        // upgrade to the reverse-geocoded city name when Nominatim responds.
        const fallback = `${rlat.toFixed(2)}°N, ${rlon.toFixed(2)}°O`;
        onLocationPickRef.current?.({
          name: fallback,
          lat: rlat,
          lon: rlon,
        });
        void reverseGeocode(rlat, rlon).then((name) => {
          if (!name) return;
          onLocationPickRef.current?.({ name, lat: rlat, lon: rlon });
        });
      });

      m.once("load", () => {
        if (!cancelled) setMapReady(true);
      });
    })();

    return () => {
      cancelled = true;
      const m = mapRef.current as { remove?: () => void } | null;
      m?.remove?.();
      mapRef.current = null;
    };
    // Center change is handled by a separate effect — we don't remount the map.
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  // ---- 2) Add one raster source/layer per frame after the basemap is ready ----
  useEffect(() => {
    if (!mapReady) return;
    const m = mapRef.current as
      | {
          addSource: Function;
          addLayer: Function;
          getSource: Function;
          setPaintProperty: Function;
        }
      | null;
    if (!m || !frames.length) return;

    frames.forEach((frame, i) => {
      const sourceId = `radar-${frame.id}`;
      if (m.getSource(sourceId)) return;
      m.addSource(sourceId, {
        type: "raster",
        tiles: [tileUrlTemplate(frame)],
        tileSize: 256,
        bounds: NL_BOUNDS,
        minzoom: RADAR_MIN_ZOOM,
        maxzoom: RADAR_MAX_ZOOM,
        attribution: "© KNMI",
      });
      m.addLayer({
        id: sourceId,
        type: "raster",
        source: sourceId,
        paint: {
          "raster-opacity": i === currentIndex ? 1 : 0,
          "raster-opacity-transition": { duration: FADE_MS },
          "raster-fade-duration": 0,
        },
      });
    });
  }, [mapReady, frames, currentIndex]);

  // ---- 3) On every index change, fade the previous out, the new one in ----
  useEffect(() => {
    if (!mapReady) return;
    const m = mapRef.current as { setPaintProperty: Function } | null;
    if (!m || !frames.length) return;
    frames.forEach((frame, i) => {
      m.setPaintProperty(
        `radar-${frame.id}`,
        "raster-opacity",
        i === currentIndex ? 1 : 0,
      );
    });
  }, [currentIndex, mapReady, frames]);

  // ---- 4) Fly to a new center + drop a marker at the selected location ----
  useEffect(() => {
    if (!mapReady || !center) return;
    const m = mapRef.current as
      | { flyTo: (opts: { center: [number, number]; zoom?: number }) => void }
      | null;
    m?.flyTo({ center: [center.lon, center.lat], zoom: 9 });

    void (async () => {
      const maplibre = await import("maplibre-gl");
      const map = mapRef.current as InstanceType<typeof maplibre.Map> | null;
      if (!map) return;
      const existing = markerRef.current as InstanceType<
        typeof maplibre.Marker
      > | null;
      if (existing) {
        existing.setLngLat([center.lon, center.lat]);
        return;
      }
      const el = document.createElement("div");
      el.className = "radar-marker";
      el.innerHTML = `
        <span class="radar-marker__pulse" aria-hidden="true"></span>
        <svg viewBox="0 0 32 40" width="28" height="35" aria-hidden="true">
          <path d="M16 2c-7.2 0-13 5.6-13 12.6 0 9 13 23.4 13 23.4s13-14.4 13-23.4C29 7.6 23.2 2 16 2Z" fill="var(--color-accent-600)" stroke="white" stroke-width="2"/>
          <circle cx="16" cy="14" r="4.5" fill="white"/>
        </svg>
      `;
      const marker = new maplibre.Marker({ element: el, anchor: "bottom" })
        .setLngLat([center.lon, center.lat])
        .addTo(map);
      markerRef.current = marker;
    })();
  }, [mapReady, center?.lat, center?.lon]);

  // ---- 5) Swap basemap style when the dark class flips on <html> ----
  useEffect(() => {
    if (typeof document === "undefined") return;
    const root = document.documentElement;
    let lastDark = root.classList.contains("dark");
    const observer = new MutationObserver(() => {
      const nextDark = root.classList.contains("dark");
      if (nextDark === lastDark) return;
      lastDark = nextDark;
      const m = mapRef.current as
        | {
            setStyle: (s: string) => void;
            once: (ev: string, cb: () => void) => void;
          }
        | null;
      if (!m) return;
      // setStyle wipes sources/layers — flip mapReady so the source-adding
      // effect (#2) re-runs once the new style finishes loading.
      setMapReady(false);
      m.setStyle(basemapStyle(nextDark));
      m.once("style.load", () => setMapReady(true));
    });
    observer.observe(root, { attributes: true, attributeFilter: ["class"] });
    return () => observer.disconnect();
  }, []);

  return (
    <div className={className}>
      <div
        ref={containerRef}
        className="w-full h-full"
        aria-label="Regenradar Nederland"
        role="region"
      />
    </div>
  );
}
