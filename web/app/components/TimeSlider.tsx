import { useCallback, useEffect, useMemo, useRef } from "react";
import type { Frame } from "~/lib/api";
import { formatHm, formatRelativeOffset } from "~/lib/format";

interface Props {
  frames: Frame[];
  currentIndex: number;
  /** Index of the frame closest to wall-clock time (the "Nu" anchor). */
  nowIndex?: number;
  isPlaying: boolean;
  onSeek: (index: number) => void;
  onTogglePlay: () => void;
}

const FRAME_LABELS: Record<Frame["kind"], string> = {
  observed: "waarneming",
  nowcast: "voorspelling (5 min)",
  hourly: "voorspelling (uur)",
};

export function TimeSlider({
  frames,
  currentIndex,
  nowIndex,
  isPlaying,
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
    sliderRef.current?.setAttribute(
      "aria-valuetext",
      liveLabel(current, minutesFromNow),
    );
  }, [current, minutesFromNow]);

  if (!frames.length || !current) {
    return null;
  }

  return (
    <div className="flex items-center gap-3">
      <button
        type="button"
        onClick={onTogglePlay}
        className="btn-primary inline-grid place-items-center h-10 w-10 rounded-full shadow-sm focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 flex-none"
        aria-pressed={isPlaying}
        aria-label={isPlaying ? "Pauzeer" : "Speel af"}
      >
        {isPlaying ? <PauseIcon /> : <PlayIcon />}
      </button>
      <div className="flex-1 flex flex-col gap-1.5">
        <input
          ref={sliderRef}
          type="range"
          min={0}
          max={frames.length - 1}
          step={1}
          value={currentIndex}
          onChange={(e) => onSeek(Number(e.target.value))}
          onKeyDown={handleKeyDown}
          className="w-full accent-[--color-accent-600]"
          aria-label="Tijdkiezer voor de regenradar"
          aria-valuemin={0}
          aria-valuemax={frames.length - 1}
          aria-valuenow={currentIndex}
        />
        <TimeTicks frames={frames} />
      </div>
    </div>
  );
}

const TEN_MIN_MS = 10 * 60 * 1000;

interface Tick {
  ts: number;
  label: string;
  pct: number;
  isNow: boolean;
  /** Major ticks (every 30 min) get a visible time label. */
  isMajor: boolean;
}

function buildTenMinuteTicks(frames: Frame[], nowMs: number): Tick[] {
  if (frames.length < 2) return [];
  const startTs = new Date(frames[0].ts).getTime();
  const endTs = new Date(frames[frames.length - 1].ts).getTime();
  const span = endTs - startTs;
  if (span <= 0) return [];
  const first = Math.ceil(startTs / TEN_MIN_MS) * TEN_MIN_MS;
  const ticks: Tick[] = [];
  for (let t = first; t <= endTs; t += TEN_MIN_MS) {
    const minute = new Date(t).getMinutes();
    ticks.push({
      ts: t,
      label: formatHm(new Date(t).toISOString()),
      pct: ((t - startTs) / span) * 100,
      isNow: Math.abs(t - nowMs) < TEN_MIN_MS / 2,
      isMajor: minute % 30 === 0,
    });
  }
  return ticks;
}

/**
 * Tick strip under the slider:
 *  - vertical tick mark at every 10-minute boundary (rhythm)
 *  - time label at every 30-minute boundary (legibility on narrow widths)
 *  - "Nu" label highlighted at the current wall-clock time
 */
function TimeTicks({ frames }: { frames: Frame[] }) {
  const ticks = useMemo(
    () => buildTenMinuteTicks(frames, Date.now()),
    [frames],
  );
  if (!ticks.length) return null;
  return (
    <div aria-hidden="true" className="relative h-5 mx-1.5 select-none">
      {ticks.map((t) => {
        const showLabel = t.isMajor || t.isNow;
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
