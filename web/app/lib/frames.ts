/**
 * Pure helpers for slicing the frames manifest by kind and computing the
 * tile URL for a given (frame, z, x, y).
 */

import type { Frame } from "./api";

export type FrameKind = Frame["kind"];

export function tileUrlTemplate(frame: Frame): string {
  return `/tiles/${frame.id}/{z}/{x}/{y}.png`;
}

export function partitionFrames(frames: readonly Frame[]) {
  const observed: Frame[] = [];
  const nowcast: Frame[] = [];
  const hourly: Frame[] = [];
  for (const f of frames) {
    if (f.kind === "observed") observed.push(f);
    else if (f.kind === "nowcast") nowcast.push(f);
    else hourly.push(f);
  }
  observed.sort(byTs);
  nowcast.sort(byTs);
  hourly.sort(byTs);
  return { observed, nowcast, hourly };
}

/** Past observations to retain on the slider (in milliseconds). */
const HISTORY_WINDOW_MS = 2 * 60 * 60 * 1000; // 2h
/**
 * Forecast horizon to retain on the slider. KNMI's radar nowcast caps at
 * 2h, so today the slider effectively goes to "now + 2h"; the extra cap
 * lets longer-horizon hourly forecast frames flow in automatically when a
 * future ingest pipeline starts producing them.
 */
const FORECAST_WINDOW_MS = 4 * 60 * 60 * 1000; // 4h

export function defaultPlayableFrames(frames: readonly Frame[]): Frame[] {
  /**
   * Auto-loop range: a rolling window of past observed history plus
   * forward nowcast (and hourly forecast tail when present). Sorted
   * globally by timestamp so the slider reads left-to-right as past →
   * future regardless of how many overlapping ingest cycles produced
   * the manifest.
   *
   * The window is anchored on the latest observed frame: HISTORY_WINDOW_MS
   * before, FORECAST_WINDOW_MS after. This keeps tick density readable
   * even when the manifest holds many days of data.
   */
  const { observed, nowcast, hourly } = partitionFrames(frames);
  if (!observed.length && !nowcast.length && !hourly.length) return [];
  const all = [...observed, ...nowcast, ...hourly].sort(byTs);

  const lastObserved = observed.length ? observed[observed.length - 1] : null;
  const anchorMs = lastObserved
    ? new Date(lastObserved.ts).getTime()
    : new Date(all[all.length - 1].ts).getTime();
  const minTs = anchorMs - HISTORY_WINDOW_MS;
  const maxTs = anchorMs + FORECAST_WINDOW_MS;

  return all.filter((f) => {
    const t = new Date(f.ts).getTime();
    return t >= minTs && t <= maxTs;
  });
}

export function findCurrentIndex(playable: readonly Frame[]): number {
  /** Index of the frame whose `ts` is closest to "now", or 0 if empty. */
  if (!playable.length) return 0;
  const nowMs = Date.now();
  let best = 0;
  let bestDelta = Number.POSITIVE_INFINITY;
  playable.forEach((f, i) => {
    const delta = Math.abs(new Date(f.ts).getTime() - nowMs);
    if (delta < bestDelta) {
      bestDelta = delta;
      best = i;
    }
  });
  return best;
}

function byTs(a: Frame, b: Frame): number {
  return new Date(a.ts).getTime() - new Date(b.ts).getTime();
}
