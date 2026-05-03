/**
 * Location-aware "rain at your spot" card. Shown above the radar map on
 * the home page (default Amsterdam) and as the hero on /locatie/:slug.
 */

import { Link } from "react-router";
import type { RainResponse } from "~/lib/api";
import { RainGraph, RainSummary } from "./RainGraph";

interface Props {
  locationName: string;
  rain: RainResponse | null;
  errorMessage?: string;
}

export function LocationCard({ locationName, rain, errorMessage }: Props) {
  return (
    <div className="rounded-2xl border border-[--color-ink-100] bg-white p-5 sm:p-6 shadow-sm dark:bg-[--color-ink-900] dark:border-[--color-ink-700]">
      <div className="flex items-start justify-between gap-3">
        <div>
          <p className="text-sm font-medium uppercase tracking-wider text-[--color-accent-600]">
            Regen in
          </p>
          <h2 className="mt-1 text-2xl font-semibold tracking-tight">
            {locationName}
          </h2>
        </div>
        <Link
          to="/"
          className="text-sm text-[--color-ink-500] hover:text-[--color-accent-600] underline-offset-4 hover:underline"
        >
          Andere locatie
        </Link>
      </div>

      {errorMessage ? (
        <p className="mt-4 text-sm text-[--color-ink-500]">{errorMessage}</p>
      ) : rain && rain.samples.length ? (
        <>
          <div className="mt-4">
            <RainSummary samples={rain.samples} />
          </div>
          <div className="mt-6 text-[--color-accent-600]">
            <RainGraph samples={rain.samples} />
          </div>
        </>
      ) : (
        <p className="mt-4 text-sm text-[--color-ink-500]">
          Geen radarvoorspelling beschikbaar — we hebben nog geen verse data
          van het KNMI ontvangen.
        </p>
      )}
    </div>
  );
}
