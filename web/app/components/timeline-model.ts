/** Pure view-model helpers for the radar Timeline: intensity bars + time ticks. */

import type { Frame, RainSample } from "~/lib/api";
import { formatHm } from "~/lib/format";

export const TEN_MIN_MS = 10 * 60 * 1000;

const NOW_LABEL_GUARD_MS = 35 * 60 * 1000;
const HOUR_MS = 60 * 60 * 1000;

export interface IntensityBar {
  key: string;
  heightPct: number;
  color: string;
  /** Visual weight: 1 = radar (full saturation), 0.55 = HARMONIE model
   *  (faded so you can tell at a glance that the right portion is a
   *  different, lower-resolution source), 0.3 = no data. */
  opacity: number;
  /** Hatched fill — used to mark HARMONIE-model bars as a different texture
   *  beyond the visual saturation difference. */
  hatched: boolean;
}

/**
 * Build per-frame intensity bars sized by the frame's nearest 10-minute
 * rain bucket. Radar-nowcast bars are fully saturated; HARMONIE-model bars
 * carry a hatched overlay + reduced opacity so the user can read the two
 * sources apart at a glance.
 */
export function buildIntensityBars(
  frames: Frame[],
  samples: readonly RainSample[],
): IntensityBar[] {
  const buckets = bucketSamplesByTenMinutes(samples);
  const yMax = Math.max(2, ...buckets.values());

  return frames.map((f) => {
    const bucketKey = roundToTenMinutes(new Date(f.ts).getTime());
    const mm = buckets.get(bucketKey);
    const hasData = mm !== undefined;
    const intensity = hasData ? mm : 0;
    const heightPct = hasData
      ? Math.max(6, (Math.min(intensity, yMax) / yMax) * 100)
      : 6;
    const isHourly = f.kind === "hourly";
    return {
      key: f.id,
      heightPct,
      color: hasData ? colorFor(intensity) : "var(--color-ink-200)",
      opacity: !hasData ? 0.3 : isHourly ? 0.55 : 1,
      hatched: hasData && isHourly,
    };
  });
}

/** Bucket samples to 10-min boundaries, keeping the max mm/h per bucket.
 *  A sample worth `0 mm/h` still counts as data — the bar will render as a
 *  short "no-rain" tick instead of the empty-bucket dimmed style, so the
 *  user can tell "we measured zero" apart from "we have no measurement". */
function bucketSamplesByTenMinutes(
  samples: readonly RainSample[],
): Map<number, number> {
  const buckets = new Map<number, number>();
  for (const s of samples) {
    const ts = new Date(s.valid_at).getTime();
    if (Number.isNaN(ts)) continue;
    const key = roundToTenMinutes(ts);
    const prev = buckets.get(key);
    if (prev === undefined || s.mm_per_h > prev) {
      buckets.set(key, s.mm_per_h);
    }
  }
  return buckets;
}

function roundToTenMinutes(ms: number): number {
  return Math.round(ms / TEN_MIN_MS) * TEN_MIN_MS;
}

export function pctForIndex(index: number, count: number): number {
  if (count <= 1) return 0;
  return (index / (count - 1)) * 100;
}

function colorFor(mm: number): string {
  // Mirrors RainGraph + backend colormap stops.
  if (mm < 0.1) return "var(--color-no-rain)";
  if (mm < 0.5) return "rgb(155,195,241)";
  if (mm < 1.0) return "rgb(92,142,232)";
  if (mm < 2.0) return "rgb(31,93,208)";
  if (mm < 5.0) return "rgb(245,213,45)";
  if (mm < 10.0) return "rgb(245,159,45)";
  if (mm < 20.0) return "rgb(230,53,61)";
  if (mm < 50.0) return "rgb(163,21,31)";
  return "rgb(192,38,211)";
}

export interface Tick {
  ts: number;
  label: string;
  pct: number;
  isNow: boolean;
  /** 30-min ticks get a slightly taller mark. */
  isMajor: boolean;
  /** Only ticks on the hour boundary get a visible time label. */
  isLabeled: boolean;
}

/** Hour step between labeled ticks. Stretching to many hours collapses the
 *  labels visually; thin them out so they stay readable. */
function labelStepHours(spanMs: number): number {
  const hours = spanMs / HOUR_MS;
  if (hours <= 6) return 1;
  if (hours <= 12) return 2;
  if (hours <= 18) return 3;
  return 6;
}

export function buildTenMinuteTicks(frames: Frame[], nowMs: number): Tick[] {
  if (frames.length < 2) return [];
  const startTs = new Date(frames[0].ts).getTime();
  const endTs = new Date(frames[frames.length - 1].ts).getTime();
  const span = endTs - startTs;
  if (span <= 0) return [];
  const first = Math.ceil(startTs / TEN_MIN_MS) * TEN_MIN_MS;
  const stepHours = labelStepHours(span);

  // Ticks share the slider's *index-proportional* coordinate system so the
  // cursor pill, the bars, and the labels all line up — including when the
  // slider has mixed cadence (5-min radar nowcast + 10-min HARMONIE) or
  // when the playable set has gaps from manifest dedup. We snap each tick's
  // wall-clock time to the nearest frame index and place the label at that
  // index's percentage along the bar row.
  const frameTs = frames.map((f) => new Date(f.ts).getTime());
  const nearestIndex = (target: number): number => {
    let best = 0;
    let bestDelta = Number.POSITIVE_INFINITY;
    for (let i = 0; i < frameTs.length; i++) {
      const d = Math.abs(frameTs[i] - target);
      if (d < bestDelta) {
        bestDelta = d;
        best = i;
      }
    }
    return best;
  };

  const ticks: Tick[] = [];
  for (let t = first; t <= endTs; t += TEN_MIN_MS) {
    const d = new Date(t);
    const minute = d.getMinutes();
    const hour = d.getHours();
    const isNow = Math.abs(t - nowMs) < TEN_MIN_MS / 2;
    const collidesWithNow = !isNow && Math.abs(t - nowMs) < NOW_LABEL_GUARD_MS;
    const isLabelHour = minute === 0 && hour % stepHours === 0;
    // Anchor on the wall-clock target (now or the tick time) then snap to
    // the closest frame index — the cursor uses the same per-index pct,
    // so Nu lands exactly under the cursor pill when the user is at "now".
    const target = isNow ? nowMs : t;
    const idx = nearestIndex(target);
    ticks.push({
      ts: t,
      label: formatHm(d.toISOString()),
      pct: pctForIndex(idx, frames.length),
      isNow,
      isMajor: minute % 30 === 0,
      isLabeled: isLabelHour && !collidesWithNow,
    });
  }
  return ticks;
}
