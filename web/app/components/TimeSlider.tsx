import { useCallback, useEffect, useMemo, useRef } from "react";
import type { Frame } from "~/lib/api";
import { formatHm, formatRelativeOffset } from "~/lib/format";

interface Props {
  frames: Frame[];
  currentIndex: number;
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
  isPlaying,
  onSeek,
  onTogglePlay,
}: Props) {
  const sliderRef = useRef<HTMLInputElement>(null);

  const current = frames[currentIndex];
  const baseTs = useMemo(() => {
    if (!frames.length) return null;
    const observedNow = frames.find((f, i) => f.kind === "observed" && i === currentIndex)
      ? frames[currentIndex]
      : frames.find((f) => f.kind === "nowcast") ?? frames[0];
    return new Date(observedNow.ts).getTime();
  }, [frames, currentIndex]);

  const minutesFromNow = useMemo(() => {
    if (!current || baseTs === null) return 0;
    return Math.round((new Date(current.ts).getTime() - baseTs) / 60000);
  }, [current, baseTs]);

  // Keyboard shortcuts: ←/→ step, space toggles.
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
    sliderRef.current?.setAttribute("aria-valuetext", liveLabel(current, minutesFromNow));
  }, [current, minutesFromNow]);

  if (!frames.length || !current) {
    return null;
  }

  return (
    <div className="px-4 sm:px-6 py-4 bg-white/95 dark:bg-[--color-ink-900]/95 backdrop-blur border-t border-[--color-ink-100] dark:border-[--color-ink-700]">
      <div className="flex items-center justify-between gap-4 mb-3">
        <button
          type="button"
          onClick={onTogglePlay}
          className="inline-flex items-center gap-2 rounded-full bg-[--color-accent-600] hover:bg-[--color-accent-500] text-white px-4 py-2 text-sm font-medium shadow-sm transition-colors focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-[--color-accent-500]"
          aria-pressed={isPlaying}
          aria-label={isPlaying ? "Pauzeer" : "Speel af"}
        >
          {isPlaying ? <PauseIcon /> : <PlayIcon />}
          <span>{isPlaying ? "Pauze" : "Afspelen"}</span>
        </button>
        <div className="text-sm tabular-nums text-[--color-ink-700] dark:text-[--color-ink-100]">
          <span className="font-medium">{formatHm(current.ts)}</span>
          <span className="ml-2 text-[--color-ink-500]">
            ({formatRelativeOffset(minutesFromNow)} · {FRAME_LABELS[current.kind]})
          </span>
        </div>
      </div>
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
