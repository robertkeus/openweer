import { useCallback, useEffect, useMemo, useRef } from "react";
import type { Frame, RainSample } from "~/lib/api";
import type { ForecastHorizonHours } from "~/lib/frames";
import { formatHm, formatRelativeOffset } from "~/lib/format";
import { HorizonButton } from "./HorizonButton";

interface Props {
  frames: Frame[];
  currentIndex: number;
  /** Index of the frame closest to wall-clock time (the "Nu" anchor). */
  nowIndex?: number;
  isPlaying: boolean;
  /** Point-rain forecast samples for the current location (5-min cadence). */
  rainSamples?: readonly RainSample[];
  /** Current forecast horizon (in hours past "Nu") + setter. When provided,
   *  a round button next to the play control opens a small picker. */
  horizonHours?: ForecastHorizonHours;
  onHorizonChange?: (next: ForecastHorizonHours) => void;
  onSeek: (index: number) => void;
  onTogglePlay: () => void;
}

const FRAME_LABELS: Record<Frame["kind"], string> = {
  observed: "waarneming",
  nowcast: "voorspelling (radar)",
  hourly: "voorspelling (HARMONIE-model)",
};

const TEN_MIN_MS = 10 * 60 * 1000;

export function Timeline({
  frames,
  currentIndex,
  nowIndex,
  isPlaying,
  rainSamples,
  horizonHours,
  onHorizonChange,
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
      <div className="flex items-stretch gap-2 sm:gap-3">
        <button
          type="button"
          onClick={onTogglePlay}
          className="btn-primary timeline-play-btn inline-grid place-items-center h-10 w-10 sm:h-12 sm:w-12 rounded-full focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 flex-none self-center"
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
          <TimeTicks frames={frames} />
        </div>
        {horizonHours !== undefined && onHorizonChange ? (
          <HorizonButton value={horizonHours} onChange={onHorizonChange} />
        ) : null}
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
              // Hatched bars (HARMONIE) get a diagonal stripe overlay so the
              // viewer reads them as a different forecast source even at
              // small sizes where the opacity drop alone is subtle.
              background: b.hatched
                ? `repeating-linear-gradient(45deg, ${b.color} 0 3px, color-mix(in srgb, ${b.color} 60%, transparent) 3px 5px)`
                : b.color,
              opacity: b.opacity,
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
        <span className="timeline-cursor-pill">{cursorLabel}</span>
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
  if (mm < 5.0) return "rgb(245,213,45)";
  if (mm < 10.0) return "rgb(245,159,45)";
  if (mm < 20.0) return "rgb(230,53,61)";
  if (mm < 50.0) return "rgb(163,21,31)";
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

const HOUR_MS = 60 * 60 * 1000;

/** Hour step between labeled ticks. Stretching to many hours collapses the
 *  labels visually; thin them out so they stay readable. */
function labelStepHours(spanMs: number): number {
  const hours = spanMs / HOUR_MS;
  if (hours <= 6) return 1;
  if (hours <= 12) return 2;
  if (hours <= 18) return 3;
  return 6;
}

function buildTenMinuteTicks(frames: Frame[], nowMs: number): Tick[] {
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

function TimeTicks({ frames }: { frames: Frame[] }) {
  const ticks = useMemo(
    () => buildTenMinuteTicks(frames, Date.now()),
    [frames],
  );
  if (!ticks.length) return null;
  return (
    <div aria-hidden="true" className="relative h-5 select-none">
      {ticks.map((t) => {
        const showLabel = t.isLabeled || t.isNow;
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
