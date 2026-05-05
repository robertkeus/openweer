import { useEffect, useRef, useState } from "react";
import { api, type Frame, type FramesResponse } from "./api";

const POLL_INTERVAL_MS = 60_000;

export function useLiveFrames(initial: FramesResponse): readonly Frame[] {
  const [frames, setFrames] = useState(initial.frames);
  const generatedAtRef = useRef(initial.generated_at);

  useEffect(() => {
    const poll = async () => {
      try {
        const data = await api.frames();
        if (data.generated_at !== generatedAtRef.current) {
          generatedAtRef.current = data.generated_at;
          setFrames(data.frames);
        }
      } catch {
        // Keep showing current frames on network error.
      }
    };
    const id = window.setInterval(poll, POLL_INTERVAL_MS);
    return () => window.clearInterval(id);
  }, []);

  return frames;
}
