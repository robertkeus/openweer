import { useCallback, useEffect, useMemo, useRef } from "react";
import type { Frame, RainSample } from "~/lib/api";
import { formatHm, formatRelativeOffset } from "~/lib/format";

interface Props {
  frames: Frame[];
  currentIndex: number;
  /** Index of the frame closest to wall-clock time (the "Nu" anchor). */
  nowIndex?: number;
  isPlaying: boolean;
  /** Point-rain forecast samples for the current location (5-min cadence). */
  rainSamples?: readonly RainSample[];
  onSeek: (index: number) => void;
  onTogglePlay: () => void;
}

const FRAME_LABELS: Record<Frame["kind"], string> = {
  observed: "waarneming",
  nowcast: "voorspelling (5 min)",
  hourly: "voorspelling (uur)",
};

const TEN_MIN_MS = 10 * 60 * 1000;

export function Timeline({
  frames,
  currentIndex,
  nowIndex,
  isPlaying,
  rainSamples,
  onSeek,
  onTogglePlay,
}: Props) {
  const sliderRef = useRef<HTMLInputElement>(null);

  const current = frames[currentIndex];
  const baseTs = useMemo(() => {
    if (!frames.length) return null;
    const anchor =
      typeof nowIndex === "number" && frames[nowIndex]
        ? frames[nowIndex]
        : (frames.find((f) => f.kind === "nowcast") ?? frames[0]);
    return new Date(anchor.ts).getTime();
  }, [frames, nowIndex]);

  const minutesFromNow = useMemo(() => {
    if (!current || baseTs === null) return 0;
    return Math.round((new Date(current.ts).getTime() - baseTs) / 60000);
  }, [current, baseTs]);

  const handleKeyDown = useCallback(
    (e: React.KeyboardEvent<HTMLInputElement>) => {
      if (e.key === " ") {
        e.preventDefault();
        onTogglePlay();
      }
    },
    [onTogglePlay],
  );

  useEffect(() => {
    if (!current) return;
    sliderRef.current?.setAttribute(
      "aria-valuetext",
      liveLabel(current, minutesFromNow),
    );
  }, [current, minutesFromNow]);

  if (!frames.length || !current) {
    return null;
  }

  return (
    <div
      className="pointer-events-auto timeline-panel rounded-2xl px-3 sm:px-4 pt-3 pb-2"
      role="group"
      aria-label="Regenradar tijdlijn"
    >
      <div className="flex items-stretch gap-3">
        <button
          type="button"
          onClick={onTogglePlay}
          className="btn-primary timeline-play-btn inline-grid place-items-center h-12 w-12 rounded-full focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 flex-none self-center"
          aria-pressed={isPlaying}
          aria-label={isPlaying ? "Pauzeer" : "Speel af"}
        >
          {isPlaying ? <PauseIcon /> : <PlayIcon />}
        </button>
        <div className="flex-1 flex flex-col gap-1 min-w-0">
          <TrackWithBars
            frames={frames}
            currentIndex={currentIndex}
            nowIndex={nowIndex}
            rainSamples={rainSamples}
            onSeek={onSeek}
            onKeyDown={handleKeyDown}
            sliderRef={sliderRef}
          />
          <TimeTicks
            frames={frames}
            cursorAtNow={
              typeof nowIndex === "number" && currentIndex === nowIndex
            }
          />
        </div>
      </div>
    </div>
  );
}

interface TrackProps {
  frames: Frame[];
  currentIndex: number;
  nowIndex?: number;
  rainSamples?: readonly RainSample[];
  onSeek: (index: number) => void;
  onKeyDown: (e: React.KeyboardEvent<HTMLInputElement>) => void;
  sliderRef: React.RefObject<HTMLInputElement | null>;
}

/**
 * Combined slider + intensity-bar track. The bars sit *behind* a transparent
 * native range input that handles drag, focus, and keyboard navigation.
 */
function TrackWithBars({
  frames,
  currentIndex,
  nowIndex,
  rainSamples,
  onSeek,
  onKeyDown,
  sliderRef,
}: TrackProps) {
  const bars = useMemo(
    () => buildIntensityBars(frames, rainSamples ?? []),
    [frames, rainSamples],
  );
  const cursorPct = pctForIndex(currentIndex, frames.length);
  const nowPct =
    typeof nowIndex === "number" ? pctForIndex(nowIndex, frames.length) : null;

  const cursorFrame = frames[currentIndex];
  const cursorLabel = cursorFrame ? formatHm(cursorFrame.ts) : "";
  const isAtNow = cursorPct === nowPct;

  return (
    <div className="relative h-14 pt-3">
      {/* Bars */}
      <div
        data-testid="intensity-bars"
        aria-hidden="true"
        className="absolute inset-x-0 bottom-0 top-3 flex items-end gap-[2px] px-[1px]"
      >
        {bars.map((b) => (
          <span
            key={b.key}
            className="flex-1 rounded-sm"
            style={{
              height: `${b.heightPct}%`,
              minHeight: "3px",
              background: b.color,
              opacity: b.dimmed ? 0.35 : 1,
            }}
          />
        ))}
      </div>

      {/* Baseline rule */}
      <div
        aria-hidden="true"
        className="absolute inset-x-0 bottom-0 h-px bg-[--color-ink-200]"
      />

      {/* "Nu" marker — dashed vertical line spanning the full track. */}
      {nowPct !== null ? (
        <div
          aria-hidden="true"
          className="absolute top-3 bottom-0 pointer-events-none"
          style={{
            left: `${nowPct}%`,
            width: "1px",
            backgroundImage:
              "linear-gradient(to bottom, var(--color-accent-600) 50%, transparent 50%)",
            backgroundSize: "1px 6px",
            opacity: isAtNow ? 0 : 0.55,
          }}
        />
      ) : null}

      {/* Cursor — time pill, thick line, and bottom handle. */}
      <div
        aria-hidden="true"
        className="absolute top-0 bottom-0 -translate-x-1/2 pointer-events-none flex flex-col items-center"
        style={{ left: `${cursorPct}%` }}
      >
        <span className="timeline-cursor-pill">
          {isAtNow ? "Nu" : cursorLabel}
        </span>
        <span className="mt-0.5 block flex-1 w-[3px] bg-[--color-accent-600] rounded-full shadow-[0_0_0_1px_rgba(0,0,0,0.25)]" />
        <span className="block h-2 w-2 -mb-0.5 rounded-full bg-[--color-accent-600] ring-2 ring-[--color-overlay] shadow" />
      </div>

      {/* Transparent native slider on top */}
      <input
        ref={sliderRef}
        type="range"
        min={0}
        max={frames.length - 1}
        step={1}
        value={currentIndex}
        onChange={(e) => onSeek(Number(e.target.value))}
        onKeyDown={onKeyDown}
        className="timeline-range absolute inset-0 w-full h-full cursor-pointer"
        aria-label="Tijdkiezer voor de regenradar"
        aria-valuemin={0}
        aria-valuemax={frames.length - 1}
        aria-valuenow={currentIndex}
      />
    </div>
  );
}

interface IntensityBar {
  key: string;
  heightPct: number;
  color: string;
  dimmed: boolean;
}

/**
 * Build per-frame intensity bars sized by the frame's nearest 10-minute
 * rain bucket. Frames outside the nowcast sample range render as dimmed
 * minimal bars (we don't have point-rain data for past observations).
 */
function buildIntensityBars(
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
    return {
      key: f.id,
      heightPct,
      color: hasData ? colorFor(intensity) : "var(--color-ink-200)",
      dimmed: !hasData,
    };
  });
}

/** Bucket samples to 10-min boundaries, keeping the max mm/h per bucket. */
function bucketSamplesByTenMinutes(
  samples: readonly RainSample[],
): Map<number, number> {
  const buckets = new Map<number, number>();
  for (const s of samples) {
    const ts = new Date(s.valid_at).getTime();
    if (Number.isNaN(ts)) continue;
    const key = roundToTenMinutes(ts);
    const prev = buckets.get(key) ?? 0;
    if (s.mm_per_h > prev) buckets.set(key, s.mm_per_h);
  }
  return buckets;
}

function roundToTenMinutes(ms: number): number {
  return Math.round(ms / TEN_MIN_MS) * TEN_MIN_MS;
}

function pctForIndex(index: number, count: number): number {
  if (count <= 1) return 0;
  return (index / (count - 1)) * 100;
}

function colorFor(mm: number): string {
  // Mirrors RainGraph + backend colormap stops.
  if (mm < 0.1) return "var(--color-no-rain)";
  if (mm < 0.5) return "rgb(155,195,241)";
  if (mm < 1.0) return "rgb(92,142,232)";
  if (mm < 2.0) return "rgb(31,93,208)";
  if (mm < 5.0) return "rgb(45,184,74)";
  if (mm < 10.0) return "rgb(245,213,45)";
  if (mm < 20.0) return "rgb(245,159,45)";
  if (mm < 50.0) return "rgb(230,53,61)";
  return "rgb(192,38,211)";
}

interface Tick {
  ts: number;
  label: string;
  pct: number;
  isNow: boolean;
  /** 30-min ticks get a slightly taller mark. */
  isMajor: boolean;
  /** Only ticks on the hour boundary get a visible time label. */
  isLabeled: boolean;
}

const NOW_LABEL_GUARD_MS = 35 * 60 * 1000;

function buildTenMinuteTicks(
  frames: Frame[],
  nowMs: number,
  /** When true the bottom "Nu" tick label is suppressed elsewhere — no
   * need to guard adjacent hour labels against collision with it. */
  skipNowGuard: boolean = false,
): Tick[] {
  if (frames.length < 2) return [];
  const startTs = new Date(frames[0].ts).getTime();
  const endTs = new Date(frames[frames.length - 1].ts).getTime();
  const span = endTs - startTs;
  if (span <= 0) return [];
  const first = Math.ceil(startTs / TEN_MIN_MS) * TEN_MIN_MS;
  const ticks: Tick[] = [];
  for (let t = first; t <= endTs; t += TEN_MIN_MS) {
    const minute = new Date(t).getMinutes();
    const isNow = Math.abs(t - nowMs) < TEN_MIN_MS / 2;
    const collidesWithNow =
      !skipNowGuard &&
      !isNow &&
      Math.abs(t - nowMs) < NOW_LABEL_GUARD_MS;
    ticks.push({
      ts: t,
      label: formatHm(new Date(t).toISOString()),
      pct: ((t - startTs) / span) * 100,
      isNow,
      isMajor: minute % 30 === 0,
      isLabeled: minute === 0 && !collidesWithNow,
    });
  }
  return ticks;
}

function TimeTicks({
  frames,
  cursorAtNow,
}: {
  frames: Frame[];
  cursorAtNow: boolean;
}) {
  // When the cursor sits on Nu, the bottom "Nu" label is suppressed (the
  // cursor pill above already says "Nu"). In that case there is no risk
  // of a Nu/hour-label collision, so we can show all hour labels.
  const ticks = useMemo(
    () => buildTenMinuteTicks(frames, Date.now(), cursorAtNow),
    [frames, cursorAtNow],
  );
  if (!ticks.length) return null;
  return (
    <div aria-hidden="true" className="relative h-5 select-none">
      {ticks.map((t) => {
        const showNuLabel = t.isNow && !cursorAtNow;
        const showLabel = t.isLabeled || showNuLabel;
        return (
          <span
            key={t.ts}
            className="absolute top-0 -translate-x-1/2 flex flex-col items-center gap-0.5 leading-none"
            style={{ left: `${t.pct}%` }}
          >
            <span
              className={`block w-px ${
                t.isNow
                  ? "h-2 bg-[--color-accent-600]"
                  : t.isMajor
                    ? "h-1.5 bg-[--color-ink-500]/60"
                    : "h-1 bg-[--color-ink-500]/35"
              }`}
            />
            {showLabel ? (
              <span
                className={`text-[10px] tabular-nums whitespace-nowrap ${
                  t.isNow
                    ? "font-semibold text-[--color-accent-600]"
                    : "text-[--color-ink-500]"
                }`}
              >
                {t.isNow ? "Nu" : t.label}
              </span>
            ) : null}
          </span>
        );
      })}
    </div>
  );
}

function liveLabel(frame: Frame, minutesFromNow: number): string {
  return `${formatHm(frame.ts)}, ${formatRelativeOffset(minutesFromNow)}, ${FRAME_LABELS[frame.kind]}`;
}

function PlayIcon() {
  return (
    <svg viewBox="0 0 24 24" className="h-4 w-4" aria-hidden="true">
      <path fill="currentColor" d="M7 5l13 7-13 7z" />
    </svg>
  );
}

function PauseIcon() {
  return (
    <svg viewBox="0 0 24 24" className="h-4 w-4" aria-hidden="true">
      <rect x="6" y="5" width="4" height="14" rx="1" fill="currentColor" />
      <rect x="14" y="5" width="4" height="14" rx="1" fill="currentColor" />
    </svg>
  );
}
