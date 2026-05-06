import { useEffect, useMemo, useState } from "react";
import type { Frame } from "./api";
import { defaultPlayableFrames, findCurrentIndex } from "./frames";

const FRAME_INTERVAL_MS = 500;

export interface RadarTimeline {
  frames: Frame[];
  currentIndex: number;
  nowIndex: number;
  current: Frame | undefined;
  isPlaying: boolean;
  seek: (index: number) => void;
  togglePlay: () => void;
}

/**
 * Owns the slider state + animation loop. The map, slider, and time chip
 * all read from the same source of truth.
 */
export function useRadarTimeline(allFrames: readonly Frame[]): RadarTimeline {
  const frames = useMemo(() => defaultPlayableFrames(allFrames), [allFrames]);

  const nowIndex = useMemo(() => findCurrentIndex(frames), [frames]);
  const [currentIndex, setCurrentIndex] = useState(nowIndex);
  const [isPlaying, setIsPlaying] = useState(false);

  // Re-anchor at "now" whenever the playable range changes.
  useEffect(() => {
    setCurrentIndex(nowIndex);
  }, [nowIndex]);

  useEffect(() => {
    if (!isPlaying || frames.length < 2) return;
    const id = setInterval(() => {
      setCurrentIndex((prev) => {
        const next = prev + 1;
        if (next >= frames.length) {
          setIsPlaying(false);
          return nowIndex;
        }
        return next;
      });
    }, FRAME_INTERVAL_MS);
    return () => clearInterval(id);
  }, [isPlaying, frames.length, nowIndex]);

  return {
    frames,
    currentIndex,
    nowIndex,
    current: frames[currentIndex],
    isPlaying,
    seek: (i) => {
      setIsPlaying(false);
      setCurrentIndex(i);
    },
    togglePlay: () => {
      if (!isPlaying && currentIndex >= frames.length - 1) {
        setCurrentIndex(nowIndex);
      }
      setIsPlaying((p) => !p);
    },
  };
}
