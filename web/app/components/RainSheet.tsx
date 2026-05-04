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
export type RainSheetTab = "chat" | "weather" | "details";

const SNAP_VAR: Record<Snap, string> = {
  peek: "var(--sheet-peek)",
  half: "var(--sheet-half)",
  full: "var(--sheet-full)",
};

interface Props {
  /** Forecast / radar detail content rendered when the "Details" tab is active. */
  details: ReactNode;
  /** AI chat content rendered when the "AI Chat" tab is active. */
  chat: ReactNode;
  /** Current weather observations rendered when the "Weer" tab is active. */
  weather: ReactNode;
  /** Which tab opens by default. */
  defaultTab?: RainSheetTab;
}

export function RainSheet({ details, chat, weather, defaultTab = "chat" }: Props) {
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
          {tab === "chat"
            ? chat
            : tab === "weather"
              ? weather
              : <DetailsScroll>{details}</DetailsScroll>}
        </div>
      </div>

      {/* ---- Desktop (lg+) bottom-right floating card ---- */}
      <div
        className="hidden lg:flex fixed right-4 z-30 glass-card flex-col w-[28rem] max-h-[calc(100vh-7rem-var(--timeline-height))]"
        style={{ bottom: "calc(var(--timeline-height) + 1rem)" }}
      >
        <TabBar active={tab} onChange={pickTab} />
        <div className="flex-1 overflow-y-auto">
          {tab === "chat"
            ? chat
            : tab === "weather"
              ? weather
              : <DetailsScroll>{details}</DetailsScroll>}
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
      className="flex items-stretch gap-1 border-b border-[--color-border] px-2 pt-1.5"
    >
      <Tab
        label="AI Chat"
        active={active === "chat"}
        onClick={() => onChange("chat")}
        icon={<ChatTabIcon className="h-4 w-4" />}
      />
      <Tab
        label="Weer"
        active={active === "weather"}
        onClick={() => onChange("weather")}
        icon={<WeatherTabIcon className="h-4 w-4" />}
      />
      <Tab
        label="Details"
        active={active === "details"}
        onClick={() => onChange("details")}
        icon={<DetailsTabIcon className="h-4 w-4" />}
      />
    </div>
  );
}

function Tab({
  label,
  active,
  onClick,
  icon,
}: {
  label: string;
  active: boolean;
  onClick: () => void;
  icon: React.ReactNode;
}) {
  return (
    <button
      type="button"
      role="tab"
      aria-selected={active}
      onClick={onClick}
      className={`tab-pill ${active ? "tab-pill--active" : ""}`}
    >
      <span aria-hidden="true" className="tab-pill__icon">
        {icon}
      </span>
      <span>{label}</span>
    </button>
  );
}

function ChatTabIcon(props: React.SVGProps<SVGSVGElement>) {
  return (
    <svg viewBox="0 0 24 24" fill="none" {...props}>
      <path
        d="M5 5h14a2 2 0 012 2v8a2 2 0 01-2 2h-8l-4 4v-4H5a2 2 0 01-2-2V7a2 2 0 012-2z"
        stroke="currentColor"
        strokeWidth="1.6"
        strokeLinejoin="round"
        fill="currentColor"
        fillOpacity="0.14"
      />
      <circle cx="9" cy="11" r="0.9" fill="currentColor" />
      <circle cx="13" cy="11" r="0.9" fill="currentColor" />
      <circle cx="17" cy="11" r="0.9" fill="currentColor" />
    </svg>
  );
}

function WeatherTabIcon(props: React.SVGProps<SVGSVGElement>) {
  return (
    <svg viewBox="0 0 24 24" fill="none" {...props}>
      <circle cx="9" cy="10" r="3.4" fill="currentColor" fillOpacity="0.18" stroke="currentColor" strokeWidth="1.4" />
      <path
        d="M11 18a4 4 0 010-8 5 5 0 019.4 0.6 3.5 3.5 0 012 6.4A3 3 0 0119 18z"
        fill="currentColor"
        fillOpacity="0.18"
        stroke="currentColor"
        strokeWidth="1.4"
        strokeLinejoin="round"
      />
    </svg>
  );
}

function DetailsTabIcon(props: React.SVGProps<SVGSVGElement>) {
  return (
    <svg viewBox="0 0 24 24" fill="none" {...props}>
      <rect
        x="3.5"
        y="13"
        width="3"
        height="7"
        rx="0.6"
        fill="currentColor"
        fillOpacity="0.18"
        stroke="currentColor"
        strokeWidth="1.4"
      />
      <rect
        x="10.5"
        y="9"
        width="3"
        height="11"
        rx="0.6"
        fill="currentColor"
        fillOpacity="0.18"
        stroke="currentColor"
        strokeWidth="1.4"
      />
      <rect
        x="17.5"
        y="5"
        width="3"
        height="15"
        rx="0.6"
        fill="currentColor"
        fillOpacity="0.18"
        stroke="currentColor"
        strokeWidth="1.4"
      />
    </svg>
  );
}

function DetailsScroll({ children }: { children: ReactNode }) {
  return <div className="p-4 space-y-4">{children}</div>;
}
