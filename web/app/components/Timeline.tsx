import { useCallback, useEffect, useMemo, useRef } from "react";
import type { Frame, RainSample } from "~/lib/api";
import type { ForecastHorizonHours } from "~/lib/frames";
import { formatHm, formatRelativeOffset } from "~/lib/format";
import { HorizonButton } from "./HorizonButton";
import {
  buildIntensityBars,
  buildTenMinuteTicks,
  pctForIndex,
} from "./timeline-model";

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
