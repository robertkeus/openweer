/**
 * RadarMap — MapLibre multi-source animation, client-only.
 *
 * The animation pattern (one raster source per timestep, swap visibility via
 * `raster-opacity-transition`) avoids the cache-invalidation flicker that
 * happens with a single templated tile URL — see step-5b research notes.
 */

import { useEffect, useMemo, useRef, useState } from "react";
import type { Frame } from "~/lib/api";
import { findCurrentIndex, tileUrlTemplate } from "~/lib/frames";
import { TimeSlider } from "./TimeSlider";

interface Props {
  frames: Frame[];
}

const NL_CENTER: [number, number] = [5.3, 52.1];
const NL_BOUNDS: [number, number, number, number] = [3.0, 50.6, 7.4, 53.7];
const FRAME_INTERVAL_MS = 500;
const FADE_MS = 220;
const BASEMAP_STYLE = "https://tiles.openfreemap.org/styles/positron";

// Tile coverage matches the backend (api/src/openweer/tiler/pipeline.py).
const RADAR_MIN_ZOOM = 6;
const RADAR_MAX_ZOOM = 10;

export function RadarMap({ frames }: Props) {
  const containerRef = useRef<HTMLDivElement | null>(null);
  // Use unknown so we don't import MapLibre types into the SSR bundle.
  const mapRef = useRef<unknown>(null);
  const playableFramesRef = useRef<Frame[]>([]);

  // Anchor the slider at the frame closest to wall-clock time so users see
  // the current observation first, then can press play to scrub the forecast.
  const initialIndex = useMemo(() => findCurrentIndex(frames), [frames]);
  const [currentIndex, setCurrentIndex] = useState(initialIndex);
  const [isPlaying, setIsPlaying] = useState(false);
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
        style: BASEMAP_STYLE,
        center: NL_CENTER,
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
            'Radar © <a href="https://www.knmi.nl">KNMI</a> · Kaart © <a href="https://openfreemap.org">OpenFreeMap</a>',
          compact: true,
        }),
        "bottom-right",
      );
      m.addControl(new maplibre.NavigationControl({ showCompass: false }), "top-right");

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
  }, []);

  // ---- 2) Add one raster source/layer per frame after the basemap is ready ----
  useEffect(() => {
    if (!mapReady) return;
    const m = mapRef.current as
      | { addSource: Function; addLayer: Function; getSource: Function; setPaintProperty: Function }
      | null;
    if (!m || !frames.length) return;

    playableFramesRef.current = frames;
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
          "raster-opacity": i === initialIndex ? 1 : 0,
          "raster-opacity-transition": { duration: FADE_MS },
          "raster-fade-duration": 0,
        },
      });
    });
  }, [mapReady, frames, initialIndex]);

  // ---- 3) Animation loop. When it reaches the last frame we pause and
  // settle back at "now" so the slider doesn't cycle forever. ----
  useEffect(() => {
    if (!mapReady || !isPlaying || frames.length < 2) return;
    const id = setInterval(() => {
      setCurrentIndex((prev) => {
        const next = prev + 1;
        if (next >= frames.length) {
          setIsPlaying(false);
          return initialIndex;
        }
        return next;
      });
    }, FRAME_INTERVAL_MS);
    return () => clearInterval(id);
  }, [mapReady, isPlaying, frames.length, initialIndex]);

  // ---- 4) On every index change, fade the previous out, the new one in ----
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

  // MapLibre overrides `position` on its container, so we wrap it in our own
  // absolutely-positioned box that defines the bounds.
  return (
    <>
      <div className="absolute inset-0">
        <div
          ref={containerRef}
          className="w-full h-full"
          aria-label="Regenradar Nederland"
          role="region"
        />
      </div>
      <div className="absolute inset-x-0 bottom-0 z-10">
        <TimeSlider
          frames={frames}
          currentIndex={currentIndex}
          nowIndex={initialIndex}
          isPlaying={isPlaying}
          onSeek={(i) => {
            setIsPlaying(false);
            setCurrentIndex(i);
          }}
          onTogglePlay={() => {
            // After a finished cycle, tapping play restarts from "now".
            if (!isPlaying && currentIndex >= frames.length - 1) {
              setCurrentIndex(initialIndex);
            }
            setIsPlaying((p) => !p);
          }}
        />
      </div>
    </>
  );
}
