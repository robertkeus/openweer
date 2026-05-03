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

export function defaultPlayableFrames(frames: readonly Frame[]): Frame[] {
  /** Auto-loop range: observed history + nowcast (excludes hourly tail). */
  const { observed, nowcast } = partitionFrames(frames);
  return [...observed, ...nowcast];
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

export function findNowAnchor(playable: readonly Frame[]): number {
  /**
   * "Now" anchor — the frame whose timestamp is closest to the user's
   * wall-clock time. Matches the user's expectation that the slider
   * starts at the current moment.
   */
  return findCurrentIndex(playable);
}

function byTs(a: Frame, b: Frame): number {
  return new Date(a.ts).getTime() - new Date(b.ts).getTime();
}
