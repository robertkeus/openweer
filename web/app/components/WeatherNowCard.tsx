/**
 * "Right now" card derived from the radar nowcast — no separate /api/now needed
 * for v1. Shows the rain situation at t=0 and a one-line outlook for the next
 * 2 hours. Temperature/wind will land with /api/now in a follow-up.
 */

import type { RainResponse } from "~/lib/api";
import { formatHm, formatMmPerHour, rainVerdict } from "~/lib/format";

interface Props {
  locationName: string;
  rain: RainResponse | null;
  loading?: boolean;
}

// /api/rain now returns ~24 h (radar nowcast + HARMONIE). The "Komende 2 uur"
// dl below must stay scoped to that window, otherwise rain arriving at +4 h
// would say "Matige buien op komst" above a "Het blijft droog" headline.
const NOWCAST_MINUTES = 120;

export function WeatherNowCard({ locationName, rain, loading }: Props) {
  const sample = rain?.samples[0];
  const nowcastSamples = rain?.samples.filter(
    (s) => s.minutes_ahead <= NOWCAST_MINUTES,
  );
  const peak = nowcastSamples?.length
    ? nowcastSamples.reduce((a, b) => (a.mm_per_h > b.mm_per_h ? a : b))
    : null;
  const verdict = peak ? rainVerdict(peak.mm_per_h) : "droog";
  const startsAt = peak && peak.mm_per_h >= 0.1 ? peak : null;

  return (
    <article
      aria-label={`Actueel weer in ${locationName}`}
      className="rounded-3xl border border-[--color-border] bg-[--color-surface] p-6 sm:p-7 shadow-sm overflow-hidden relative"
    >
      <div>
        <p className="text-xs uppercase tracking-[0.18em] text-[--color-ink-500] font-medium">
          Nu in
        </p>
        <h2 className="mt-0.5 text-xl font-semibold tracking-tight">
          {locationName}
        </h2>
      </div>

      <div className="mt-6 flex items-end gap-3">
        <p
          aria-label="Huidige neerslag"
          className="text-5xl sm:text-6xl font-semibold tabular-nums tracking-tight leading-none"
        >
          {sample ? sample.mm_per_h.toFixed(1).replace(".", ",") : "—"}
          <span className="text-2xl ml-1 text-[--color-ink-500] font-medium">
            mm/u
          </span>
        </p>
      </div>
      <p className="mt-2 text-sm text-[--color-ink-500]">
        {sample
          ? `Radar van ${formatHm(sample.valid_at)} (Nederlandse tijd).`
          : loading
            ? "Voorspelling laden…"
            : "Nog geen radardata."}
      </p>

      <hr className="my-6 border-[--color-border]" />

      <dl className="grid grid-cols-2 gap-4 text-sm">
        <div>
          <dt className="text-[--color-ink-700] uppercase text-xs tracking-wider">
            Komende 2 uur
          </dt>
          <dd className="mt-1 font-medium text-[--color-ink-900]">
            {verdict === "droog" && peak && peak.mm_per_h < 0.1
              ? "Het blijft droog."
              : verdict === "licht"
                ? "Lichte regen mogelijk."
                : verdict === "matig"
                  ? "Matige buien op komst."
                  : "Zware buien op komst."}
          </dd>
        </div>
        <div>
          <dt className="text-[--color-ink-700] uppercase text-xs tracking-wider">
            Piek
          </dt>
          <dd className="mt-1 font-medium tabular-nums">
            {peak ? formatMmPerHour(peak.mm_per_h) : "—"}
            {startsAt ? (
              <span className="text-[--color-ink-500] font-normal">
                {" "}
                · {formatHm(startsAt.valid_at)}
              </span>
            ) : null}
          </dd>
        </div>
      </dl>
    </article>
  );
}
