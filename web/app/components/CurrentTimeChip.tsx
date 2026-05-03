import type { Frame, RainSample } from "~/lib/api";
import { formatHm } from "~/lib/format";

interface Props {
  frame: Frame | undefined;
  /** Optional rain reading at the current moment (renders a second line). */
  sample?: RainSample;
}

/** Floating chip that mirrors the slider's current time + rain reading. */
export function CurrentTimeChip({ frame, sample }: Props) {
  if (!frame) return null;
  return (
    <div
      aria-live="polite"
      className="glass-card px-3 py-2 text-right"
    >
      <p className="text-base font-semibold tabular-nums leading-none">
        {formatHm(frame.ts)}
      </p>
      {sample ? (
        <p className="mt-1 text-xs tabular-nums text-[--color-ink-700]">
          {sample.mm_per_h.toFixed(1).replace(".", ",")} mm/u
        </p>
      ) : null}
    </div>
  );
}
