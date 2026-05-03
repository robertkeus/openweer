/**
 * RadarMap — MapLibre multi-source animation, client-only.
 *
 * The animation pattern (one raster source per timestep, swap visibility via
 * `raster-opacity-transition`) avoids the cache-invalidation flicker that
 * happens with a single templated tile URL — see step-5b research notes.
 */

import { useEffect, useRef, useState } from "react";
import type { Frame } from "~/lib/api";
import { tileUrlTemplate } from "~/lib/frames";
import { TimeSlider } from "./TimeSlider";

interface Props {
  frames: Frame[];
}

const NL_CENTER: [number, number] = [5.3, 52.1];
const FRAME_INTERVAL_MS = 500;
const FADE_MS = 220;
const BASEMAP_STYLE =
  "https://tiles.openfreemap.org/styles/positron";

export function RadarMap({ frames }: Props) {
  const containerRef = useRef<HTMLDivElement | null>(null);
  // Use unknown so we don't import MapLibre types into the SSR bundle.
  const mapRef = useRef<unknown>(null);
  const playableFramesRef = useRef<Frame[]>([]);

  const [currentIndex, setCurrentIndex] = useState(0);
  const [isPlaying, setIsPlaying] = useState(true);
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
        attribution: "© KNMI",
      });
      m.addLayer({
        id: sourceId,
        type: "raster",
        source: sourceId,
        paint: {
          "raster-opacity": i === 0 ? 1 : 0,
          "raster-opacity-transition": { duration: FADE_MS },
          "raster-fade-duration": 0,
        },
      });
    });
    setCurrentIndex(0);
  }, [mapReady, frames]);

  // ---- 3) Animation loop ----
  useEffect(() => {
    if (!mapReady || !isPlaying || frames.length < 2) return;
    const id = setInterval(() => {
      setCurrentIndex((prev) => (prev + 1) % frames.length);
    }, FRAME_INTERVAL_MS);
    return () => clearInterval(id);
  }, [mapReady, isPlaying, frames.length]);

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

  return (
    <div className="relative isolate w-full h-full">
      <div
        ref={containerRef}
        className="absolute inset-0"
        aria-label="Regenradar Nederland"
        role="region"
      />
      <div className="absolute inset-x-0 bottom-0 z-10">
        <TimeSlider
          frames={frames}
          currentIndex={currentIndex}
          isPlaying={isPlaying}
          onSeek={(i) => {
            setIsPlaying(false);
            setCurrentIndex(i);
          }}
          onTogglePlay={() => setIsPlaying((p) => !p)}
        />
      </div>
    </div>
  );
}
