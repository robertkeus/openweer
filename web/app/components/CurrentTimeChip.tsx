import { useEffect, useState } from "react";
import type { RainSample } from "~/lib/api";
import { formatHm } from "~/lib/format";

interface Props {
  /** Optional list of rain samples; the chip picks the one closest to "now". */
  samples?: readonly RainSample[];
}

/**
 * Floating wall-clock chip. Shows the user's current local time (NL) and,
 * if rain samples are available, the rain reading at the moment closest
 * to right now. Re-ticks every 30 seconds so it stays accurate during
 * long page sessions.
 */
export function CurrentTimeChip({ samples }: Props) {
  // Strictly client-side: initialise to null so SSR renders nothing and any
  // cached HTML can't freeze the displayed time.
  const [now, setNow] = useState<Date | null>(null);

  useEffect(() => {
    setNow(new Date());
    const id = window.setInterval(() => setNow(new Date()), 30_000);
    return () => window.clearInterval(id);
  }, []);

  if (!now) return null;

  const sample = samples?.length ? closestSample(samples, now.getTime()) : null;
  const nowIso = now.toISOString();

  return (
    <div aria-live="polite" className="glass-card px-3 py-2 text-right">
      <p className="text-base font-semibold tabular-nums leading-none">
        {formatHm(nowIso)}
      </p>
      {sample ? (
        <p className="mt-1 text-xs tabular-nums text-[--color-ink-700]">
          {sample.mm_per_h.toFixed(1).replace(".", ",")} mm/u
        </p>
      ) : null}
    </div>
  );
}

function closestSample(
  samples: readonly RainSample[],
  nowMs: number,
): RainSample {
  let best = samples[0];
  let bestDelta = Math.abs(new Date(best.valid_at).getTime() - nowMs);
  for (const s of samples.slice(1)) {
    const d = Math.abs(new Date(s.valid_at).getTime() - nowMs);
    if (d < bestDelta) {
      best = s;
      bestDelta = d;
    }
  }
  return best;
}
