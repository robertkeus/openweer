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
/** Cross-fade duration for adjacent frames *within the same data source*
 *  (radar→radar, model→model). Snappy enough for slider scrubbing and
 *  auto-play to chain into continuous motion. */
const FADE_MS = 220;
/** Longer cross-fade when crossing the radar↔model seam at +2 h. Holding
 *  both layers visible for ~half a second reads as a deliberate model
 *  handoff instead of a glitch — the two products show visibly different
 *  rain fields. */
const CROSS_SOURCE_FADE_MS = 700;
const BASEMAP_LIGHT = "https://tiles.openfreemap.org/styles/positron";
// OpenFreeMap doesn't publish a dark style; CARTO's dark-matter is freely
// hosted and attribution-compatible.
const BASEMAP_DARK =
  "https://basemaps.cartocdn.com/gl/dark-matter-gl-style/style.json";

function basemapStyle(isDark: boolean): string {
  return isDark ? BASEMAP_DARK : BASEMAP_LIGHT;
}

function isDocumentDark(): boolean {
  return (
    typeof document !== "undefined" &&
    document.documentElement.classList.contains("dark")
  );
}

const RADAR_MIN_ZOOM = 6;
const RADAR_MAX_ZOOM = 10;

/** True when the active frame is changing between a radar-derived frame
 *  (observed/nowcast) and a HARMONIE-model frame (hourly). Same-source
 *  moves and first-paint (`prev === undefined`) return false. */
function isCrossSourceTransition(
  prev: Frame["kind"] | undefined,
  next: Frame["kind"] | undefined,
): boolean {
  if (!prev || !next || prev === next) return false;
  const isRadar = (k: Frame["kind"]) => k === "observed" || k === "nowcast";
  return isRadar(prev) !== isRadar(next);
}

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
            'Radar © <a href="https://www.knmi.nl">KNMI</a> · Kaart © <a href="https://openfreemap.org">OpenFreeMap</a> / <a href="https://carto.com/attributions">CARTO</a> · <a href="https://github.com/robertkeus/openweer" target="_blank" rel="noopener">OpenWeer op GitHub</a>',
          compact: true,
        }),
        "bottom-right",
      );

      // Use double-click to pick a location instead of zooming in. We bind
      // a DOM listener on the canvas (instead of `map.on('dblclick', ...)`)
      // so the gesture also works on browsers/trackpads where MapLibre's
      // internal dblclick recognizer can be flaky.
      m.doubleClickZoom.disable();
      const handlePick = (lng: number, lat: number) => {
        if (!isInNetherlands({ lat, lon: lng })) return;
        const round = (v: number) => Math.round(v * 10000) / 10000;
        const rlat = round(lat);
        const rlon = round(lng);
        const fallback = `${rlat.toFixed(2)}°N, ${rlon.toFixed(2)}°O`;
        onLocationPickRef.current?.({ name: fallback, lat: rlat, lon: rlon });
        void reverseGeocode(rlat, rlon).then((name) => {
          if (!name) return;
          onLocationPickRef.current?.({ name, lat: rlat, lon: rlon });
        });
      };
      const canvas = m.getCanvasContainer();
      const onDblClick = (ev: MouseEvent) => {
        ev.preventDefault();
        const { lng, lat } = m.unproject([ev.offsetX, ev.offsetY]);
        handlePick(lng, lat);
      };
      canvas.addEventListener("dblclick", onDblClick);
      // Touch fallback: detect two pointerdowns within 350ms at the same
      // spot. dblclick is unreliable on touch screens.
      let lastTap = { ts: 0, x: 0, y: 0 };
      const onPointerDown = (ev: PointerEvent) => {
        if (ev.pointerType !== "touch") return;
        const now = ev.timeStamp;
        const dx = Math.abs(ev.clientX - lastTap.x);
        const dy = Math.abs(ev.clientY - lastTap.y);
        if (now - lastTap.ts < 350 && dx < 24 && dy < 24) {
          ev.preventDefault();
          const rect = canvas.getBoundingClientRect();
          const { lng, lat } = m.unproject([
            ev.clientX - rect.left,
            ev.clientY - rect.top,
          ]);
          handlePick(lng, lat);
          lastTap = { ts: 0, x: 0, y: 0 };
          return;
        }
        lastTap = { ts: now, x: ev.clientX, y: ev.clientY };
      };
      canvas.addEventListener("pointerdown", onPointerDown);

      // Use `style.load`, not `load`. `load` only fires once MapLibre's
      // raf-driven render loop completes a first frame; on some first-paint
      // races (cold cache, deferred script execution under a hidden frame)
      // that loop never ticks, so `load` never fires and the radar layers
      // never get added — the map stays on its basemap background colour
      // (black for dark-matter, white for positron) until a setStyle()
      // kicks the loop. `style.load` only requires the style JSON to be
      // parsed and the sources constructed, which is all this effect needs
      // before handing off to the source-adding effect below.
      const onReady = () => {
        if (!cancelled) setMapReady(true);
      };
      if (m.isStyleLoaded()) {
        onReady();
      } else {
        m.once("style.load", onReady);
      }
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
    const m = mapRef.current as {
      addSource: (id: string, source: object) => unknown;
      addLayer: (layer: object) => unknown;
      getSource: (id: string) => unknown;
      setPaintProperty: (
        layerId: string,
        prop: string,
        value: unknown,
      ) => unknown;
    } | null;
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
  const prevIndexRef = useRef<number | null>(null);
  useEffect(() => {
    if (!mapReady) return;
    const m = mapRef.current as {
      setPaintProperty: (
        layerId: string,
        prop: string,
        value: unknown,
      ) => unknown;
    } | null;
    if (!m || !frames.length) return;

    // Cross-fade duration: bump to CROSS_SOURCE_FADE_MS when the active
    // frame's kind shifts between radar (observed/nowcast) and model
    // (hourly), so the two visibly-different rasters overlap for ~half a
    // second instead of cutting.
    const prevIndex = prevIndexRef.current;
    const prevKind = prevIndex !== null ? frames[prevIndex]?.kind : undefined;
    const nextKind = frames[currentIndex]?.kind;
    const crossesSeam = isCrossSourceTransition(prevKind, nextKind);
    const outgoingId =
      prevIndex !== null ? frames[prevIndex]?.id : undefined;
    const incomingId = frames[currentIndex]?.id;

    frames.forEach((frame, i) => {
      // Only the two layers actually involved in this transition need their
      // transition duration retuned; leave others on whatever they were.
      if (frame.id === outgoingId || frame.id === incomingId) {
        m.setPaintProperty(
          `radar-${frame.id}`,
          "raster-opacity-transition",
          { duration: crossesSeam ? CROSS_SOURCE_FADE_MS : FADE_MS },
        );
      }
      m.setPaintProperty(
        `radar-${frame.id}`,
        "raster-opacity",
        i === currentIndex ? 1 : 0,
      );
    });
    prevIndexRef.current = currentIndex;
  }, [currentIndex, mapReady, frames]);

  // ---- 4) Fly to a new center + drop a marker at the selected location ----
  useEffect(() => {
    if (!mapReady || !center) return;
    const m = mapRef.current as {
      flyTo: (opts: { center: [number, number]; zoom?: number }) => void;
    } | null;
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
      const m = mapRef.current as {
        setStyle: (s: string) => void;
        once: (ev: string, cb: () => void) => void;
      } | null;
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
