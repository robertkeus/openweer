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

interface Props {
  frames: Frame[];
  currentIndex: number;
  /** Optional center the map should fly to. */
  center?: { lat: number; lon: number };
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
  className = "absolute inset-0",
}: Props) {
  const containerRef = useRef<HTMLDivElement | null>(null);
  const mapRef = useRef<unknown>(null);
  const [mapReady, setMapReady] = useState(false);

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

  // ---- 4) Fly to a new center when the parent updates the location ----
  useEffect(() => {
    if (!mapReady || !center) return;
    const m = mapRef.current as
      | { flyTo: (opts: { center: [number, number]; zoom?: number }) => void }
      | null;
    m?.flyTo({ center: [center.lon, center.lat], zoom: 9 });
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
