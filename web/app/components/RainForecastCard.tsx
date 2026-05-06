/**
 * 2-hour rain forecast card — bar graph + summary numbers.
 * Replaces the older `LocationCard` (this is a tighter, more focused card).
 */

import type { RainResponse } from "~/lib/api";
import { RainGraph, RainSummary } from "./RainGraph";

interface Props {
  locationName: string;
  rain: RainResponse | null;
  loading?: boolean;
  errorMessage?: string;
}

export function RainForecastCard({
  locationName,
  rain,
  loading,
  errorMessage,
}: Props) {
  return (
    <article
      aria-label={`Regenvoorspelling voor ${locationName}`}
      className="rounded-3xl border border-[--color-border] bg-[--color-surface] p-6 sm:p-7 shadow-sm"
    >
      <div className="flex items-center justify-between gap-3">
        <div>
          <p className="text-xs uppercase tracking-[0.18em] text-[--color-ink-500] font-medium">
            Voorspelling
          </p>
          <h2 className="mt-0.5 text-xl font-semibold tracking-tight">
            Komende 2 uur
          </h2>
        </div>
        <span className="text-xs text-[--color-ink-500]">{locationName}</span>
      </div>

      {errorMessage ? (
        <p className="mt-6 text-sm text-[--color-ink-500]">{errorMessage}</p>
      ) : loading ? (
        <p className="mt-6 text-sm text-[--color-ink-500]">
          Voorspelling laden…
        </p>
      ) : rain && rain.samples.length ? (
        <>
          <div className="mt-5">
            <RainSummary samples={rain.samples} />
          </div>
          <div className="mt-6 text-[--color-accent-600]">
            <RainGraph samples={rain.samples} />
          </div>
        </>
      ) : (
        <p className="mt-6 text-sm text-[--color-ink-500]">
          Geen voorspelling beschikbaar — we wachten op verse data van het KNMI.
        </p>
      )}
    </article>
  );
}
