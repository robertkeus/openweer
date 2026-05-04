/**
 * Tabbed bottom-right panel that hosts the rain forecast (Details) and the
 * AI assistant (AI Chat). Mobile: draggable bottom sheet with three snap
 * states. Desktop (lg+): fixed bottom-right glass card.
 */

import {
  useCallback,
  useEffect,
  useRef,
  useState,
  type ReactNode,
} from "react";

type Snap = "peek" | "half" | "full";
export type RainSheetTab = "chat" | "details";

const SNAP_VAR: Record<Snap, string> = {
  peek: "var(--sheet-peek)",
  half: "var(--sheet-half)",
  full: "var(--sheet-full)",
};

interface Props {
  /** Forecast / weather content rendered when the "Details" tab is active. */
  details: ReactNode;
  /** AI chat content rendered when the "AI Chat" tab is active. */
  chat: ReactNode;
  /** Which tab opens by default. */
  defaultTab?: RainSheetTab;
}

export function RainSheet({ details, chat, defaultTab = "chat" }: Props) {
  const [snap, setSnap] = useState<Snap>(defaultTab === "chat" ? "full" : "peek");
  const [tab, setTab] = useState<RainSheetTab>(defaultTab);
  const [dragOffset, setDragOffset] = useState<number | null>(null);
  const startYRef = useRef(0);
  const startSnapRef = useRef<Snap>(snap);
  const sheetRef = useRef<HTMLDivElement>(null);

  // ---- mobile drag handling ----
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

  const [reducedMotion, setReducedMotion] = useState(false);
  useEffect(() => {
    if (typeof window === "undefined") return;
    const mq = window.matchMedia("(prefers-reduced-motion: reduce)");
    const update = () => setReducedMotion(mq.matches);
    update();
    mq.addEventListener("change", update);
    return () => mq.removeEventListener("change", update);
  }, []);

  // Switching to chat on mobile auto-promotes the sheet to "full" so the
  // conversation has room to breathe.
  function pickTab(next: RainSheetTab) {
    setTab(next);
    if (next === "chat") setSnap("full");
  }

  return (
    <>
      {/* ---- Mobile / tablet sheet (hidden on lg+) ---- */}
      <div
        ref={sheetRef}
        role="dialog"
        aria-label="Weer­paneel"
        className="lg:hidden fixed inset-x-0 z-30 glass-card rounded-b-none rounded-t-2xl will-change-[height,transform] flex flex-col"
        style={{
          bottom: "var(--timeline-height)",
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
        <TabBar active={tab} onChange={pickTab} />
        <div className="flex-1 overflow-y-auto pb-[max(env(safe-area-inset-bottom,0),16px)]">
          {tab === "chat" ? chat : <DetailsScroll>{details}</DetailsScroll>}
        </div>
      </div>

      {/* ---- Desktop (lg+) bottom-right floating card ---- */}
      <div
        className="hidden lg:flex fixed right-4 z-30 glass-card flex-col w-[28rem] max-h-[calc(100vh-7rem-var(--timeline-height))]"
        style={{ bottom: "calc(var(--timeline-height) + 1rem)" }}
      >
        <TabBar active={tab} onChange={pickTab} />
        <div className="flex-1 overflow-y-auto">
          {tab === "chat" ? chat : <DetailsScroll>{details}</DetailsScroll>}
        </div>
      </div>
    </>
  );
}

function TabBar({
  active,
  onChange,
}: {
  active: RainSheetTab;
  onChange: (next: RainSheetTab) => void;
}) {
  return (
    <div
      role="tablist"
      aria-label="Paneel-tabs"
      className="flex items-stretch border-b border-[--color-border] px-2 pt-1"
    >
      <Tab
        label="AI Chat"
        active={active === "chat"}
        onClick={() => onChange("chat")}
      />
      <Tab
        label="Details"
        active={active === "details"}
        onClick={() => onChange("details")}
      />
    </div>
  );
}

function Tab({
  label,
  active,
  onClick,
}: {
  label: string;
  active: boolean;
  onClick: () => void;
}) {
  return (
    <button
      type="button"
      role="tab"
      aria-selected={active}
      onClick={onClick}
      className={`relative px-3 py-2 text-sm font-semibold transition-colors focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-[-2px] focus-visible:outline-[--color-accent-500] ${
        active ? "text-[--color-ink-900]" : "text-[--color-ink-700] hover:text-[--color-ink-900]"
      }`}
    >
      {label}
      {active ? (
        <span
          aria-hidden="true"
          className="absolute left-2 right-2 -bottom-px h-[2px] rounded-full bg-[--color-accent-600]"
        />
      ) : null}
    </button>
  );
}

function DetailsScroll({ children }: { children: ReactNode }) {
  return <div className="p-4 space-y-4">{children}</div>;
}
