/**
 * Bottom sheet that hosts the rain timeline and (when expanded) the weather
 * detail cards. Mobile: pointer-driven drag with three snap states. Desktop
 * (lg+): fixed bottom-left card with a chevron toggle.
 */

import {
  useCallback,
  useEffect,
  useRef,
  useState,
  type ReactNode,
} from "react";

type Snap = "peek" | "half" | "full";

const SNAP_VAR: Record<Snap, string> = {
  peek: "var(--sheet-peek)",
  half: "var(--sheet-half)",
  full: "var(--sheet-full)",
};

interface Props {
  /** Always-visible content shown at the peek state. */
  peek: ReactNode;
  /** Extra content revealed when expanded. */
  expanded: ReactNode;
}

export function RainSheet({ peek, expanded }: Props) {
  const [snap, setSnap] = useState<Snap>("peek");
  const [dragOffset, setDragOffset] = useState<number | null>(null);
  const startYRef = useRef(0);
  const startSnapRef = useRef<Snap>("peek");
  const sheetRef = useRef<HTMLDivElement>(null);

  const onPointerDown = useCallback(
    (e: React.PointerEvent<HTMLElement>) => {
      (e.currentTarget as Element).setPointerCapture?.(e.pointerId);
      startYRef.current = e.clientY;
      startSnapRef.current = snap;
      setDragOffset(0);
    },
    [snap],
  );

  const onPointerMove = useCallback(
    (e: React.PointerEvent<HTMLElement>) => {
      if (dragOffset === null) return;
      setDragOffset(e.clientY - startYRef.current);
    },
    [dragOffset],
  );

  const onPointerUp = useCallback(
    (e: React.PointerEvent<HTMLElement>) => {
      if (dragOffset === null) return;
      const dy = e.clientY - startYRef.current;
      const startSnap = startSnapRef.current;

      // Threshold-based snapping: every ~80px of travel jumps one step.
      let next: Snap = startSnap;
      const order: Snap[] = ["peek", "half", "full"];
      const idx = order.indexOf(startSnap);
      if (dy < -60) next = order[Math.min(idx + 1, order.length - 1)];
      else if (dy > 60) next = order[Math.max(idx - 1, 0)];
      setSnap(next);
      setDragOffset(null);
    },
    [dragOffset],
  );

  // Keyboard: Up/Down on the handle moves between snap points.
  const onKeyDown = useCallback((e: React.KeyboardEvent<HTMLButtonElement>) => {
    const order: Snap[] = ["peek", "half", "full"];
    if (e.key === "ArrowUp" || e.key === "PageUp") {
      e.preventDefault();
      setSnap((s) => order[Math.min(order.indexOf(s) + 1, order.length - 1)]);
    } else if (e.key === "ArrowDown" || e.key === "PageDown") {
      e.preventDefault();
      setSnap((s) => order[Math.max(order.indexOf(s) - 1, 0)]);
    }
  }, []);

  // Match the prefers-reduced-motion media query for transition control.
  const [reducedMotion, setReducedMotion] = useState(false);
  useEffect(() => {
    if (typeof window === "undefined") return;
    const mq = window.matchMedia("(prefers-reduced-motion: reduce)");
    const update = () => setReducedMotion(mq.matches);
    update();
    mq.addEventListener("change", update);
    return () => mq.removeEventListener("change", update);
  }, []);

  const expanded_ = snap !== "peek";

  return (
    <>
      {/* ---- Mobile / tablet sheet (hidden on lg+) ---- */}
      <div
        ref={sheetRef}
        role="dialog"
        aria-label="Regen­voorspelling"
        className="lg:hidden fixed inset-x-0 bottom-0 z-30 glass-card rounded-b-none rounded-t-2xl will-change-[height,transform] flex flex-col"
        style={{
          height: SNAP_VAR[snap],
          transform: dragOffset !== null ? `translateY(${dragOffset}px)` : undefined,
          transition:
            dragOffset !== null || reducedMotion
              ? "none"
              : "height 220ms cubic-bezier(0.32,0.72,0,1)",
        }}
      >
        <button
          type="button"
          aria-label={`Sleep om uit te klappen — huidige stand: ${snap}`}
          onPointerDown={onPointerDown}
          onPointerMove={onPointerMove}
          onPointerUp={onPointerUp}
          onPointerCancel={onPointerUp}
          onKeyDown={onKeyDown}
          className="w-full pt-2 pb-1 flex justify-center cursor-grab active:cursor-grabbing touch-none focus-visible:outline-none"
        >
          <span
            aria-hidden="true"
            className="block h-1.5 w-10 rounded-full bg-[--color-ink-200]"
          />
        </button>
        <div className="flex-1 overflow-y-auto px-4 pb-[max(env(safe-area-inset-bottom,0),16px)]">
          {peek}
          {expanded_ ? (
            <div className="mt-4 space-y-4 pb-4">{expanded}</div>
          ) : null}
        </div>
      </div>

      {/* ---- Desktop (lg+) bottom-left floating card ---- */}
      <div className="hidden lg:flex fixed left-4 bottom-4 z-30 glass-card flex-col w-[28rem] max-h-[calc(100vh-7rem)]">
        <div className="flex-1 overflow-y-auto p-4">
          {peek}
          {expanded_ ? <div className="mt-4 space-y-4">{expanded}</div> : null}
        </div>
        <button
          type="button"
          onClick={() => setSnap(expanded_ ? "peek" : "full")}
          aria-expanded={expanded_}
          aria-label={
            expanded_ ? "Klap voorspelling in" : "Klap voorspelling uit"
          }
          className="px-4 py-2 border-t border-[--color-ink-100] text-sm font-medium text-[--color-ink-700] hover:bg-[--color-ink-50] focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-[-2px] focus-visible:outline-[--color-accent-500] flex items-center justify-center gap-2"
        >
          {expanded_ ? "Minder details" : "Meer details"}
          <ChevronIcon
            className={`h-3 w-3 transition-transform ${expanded_ ? "rotate-180" : ""}`}
          />
        </button>
      </div>
    </>
  );
}

function ChevronIcon(props: React.SVGProps<SVGSVGElement>) {
  return (
    <svg viewBox="0 0 24 24" fill="none" {...props}>
      <path
        d="M18 15l-6-6-6 6"
        stroke="currentColor"
        strokeWidth="2"
        strokeLinecap="round"
        strokeLinejoin="round"
      />
    </svg>
  );
}
