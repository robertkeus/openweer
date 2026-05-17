/**
 * Inline drill-down for one day in the weekly forecast. Renders inside the
 * RainSheet's panel slot in place of the weather list — same container, same
 * scroll, no overlay or backdrop. Lazy-fetches `/api/forecast/{lat}/{lon}/hourly`
 * on mount; the parent caches the response so a re-open within 10 min renders
 * synchronously.
 */

import { useEffect, useMemo, useState } from "react";
import {
  api,
  ApiError,
  type DailyForecast,
  type HourlyForecastResponse,
} from "~/lib/api";
import { DayDetailHeader } from "./DayDetailHeader";
import { DayDetailStatsGrid } from "./DayDetailStatsGrid";
import { HourlyRainChart } from "./HourlyRainChart";
import { HourlyStrip } from "./HourlyStrip";
import { navigationTitleFor, slotsForDate } from "./util";

export interface HourlyCacheEntry {
  response: HourlyForecastResponse;
  fetchedAt: number;
  lat: number;
  lon: number;
}

const FRESHNESS_MS = 10 * 60_000;

interface Props {
  day: DailyForecast;
  coord: { lat: number; lon: number };
  hourlyCache: HourlyCacheEntry | null;
  onClose: () => void;
  onHourlyLoaded: (entry: HourlyCacheEntry) => void;
}

export function DayDetailView({
  day,
  coord,
  hourlyCache,
  onClose,
  onHourlyLoaded,
}: Props) {
  const [error, setError] = useState<string | null>(null);
  const [pending, setPending] = useState(false);
  const [retryNonce, setRetryNonce] = useState(0);

  const slots = useMemo(() => {
    if (!hourlyCache) return [];
    if (hourlyCache.lat !== coord.lat || hourlyCache.lon !== coord.lon) {
      return [];
    }
    return slotsForDate(hourlyCache.response.hours, day.date);
  }, [hourlyCache, day.date, coord.lat, coord.lon]);

  // Esc closes — natural panel behaviour, no `<dialog>` needed.
  useEffect(() => {
    function onKey(e: KeyboardEvent) {
      if (e.key === "Escape") onClose();
    }
    window.addEventListener("keydown", onKey);
    return () => window.removeEventListener("keydown", onKey);
  }, [onClose]);

  // Lazy-fetch hourly when the cache is missing, stale, or for a different
  // coord. Pre-existing fresh cache → render synchronously, no fetch.
  useEffect(() => {
    const fresh =
      hourlyCache !== null &&
      Date.now() - hourlyCache.fetchedAt < FRESHNESS_MS &&
      hourlyCache.lat === coord.lat &&
      hourlyCache.lon === coord.lon;
    if (fresh) {
      setError(null);
      setPending(false);
      return;
    }
    const ctrl = new AbortController();
    setPending(true);
    setError(null);
    api
      .forecastHourly(coord.lat, coord.lon)
      .then((resp) => {
        if (ctrl.signal.aborted) return;
        onHourlyLoaded({
          response: resp,
          fetchedAt: Date.now(),
          lat: coord.lat,
          lon: coord.lon,
        });
      })
      .catch((err) => {
        if (ctrl.signal.aborted) return;
        if (err instanceof ApiError && err.status === 503) {
          setError("Per-uur is even niet bereikbaar.");
        } else {
          setError("Per-uur niet beschikbaar.");
        }
      })
      .finally(() => {
        if (!ctrl.signal.aborted) setPending(false);
      });
    return () => ctrl.abort();
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [coord.lat, coord.lon, retryNonce]);

  return (
    <section aria-label={`Details voor ${navigationTitleFor(day)}`} className="p-4 space-y-4">
      <div className="flex items-center gap-2">
        <button
          type="button"
          onClick={onClose}
          aria-label="Terug naar de daglijst"
          className="-ml-1 inline-flex items-center gap-1 rounded-md px-2 py-1 text-sm font-medium text-[--color-accent-600] hover:bg-[--color-border]/40 focus:bg-[--color-border]/40 focus:outline-none"
        >
          <span aria-hidden="true">‹</span>
          <span>Terug</span>
        </button>
        <h2 className="ml-1 text-base font-semibold text-[--color-ink-900]">
          {navigationTitleFor(day)}
        </h2>
      </div>

      <DayDetailHeader day={day} slots={slots} />

      {error && slots.length === 0 ? (
        <div className="flex items-center gap-3 rounded-xl border border-[--color-border] px-3 py-2">
          <span aria-hidden="true">⚠️</span>
          <span className="flex-1 text-sm text-[--color-ink-900]">{error}</span>
          <button
            type="button"
            className="text-sm font-semibold text-[--color-accent-600]"
            onClick={() => setRetryNonce((n) => n + 1)}
          >
            Opnieuw
          </button>
        </div>
      ) : null}

      <HourlyStrip slots={slots} day={day} pending={pending} />
      <HourlyRainChart slots={slots} pending={pending} />
      <DayDetailStatsGrid day={day} slots={slots} />
    </section>
  );
}
