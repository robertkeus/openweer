import { useEffect, useRef, useState } from "react";
import {
  FORECAST_HORIZON_HOURS,
  type ForecastHorizonHours,
} from "~/lib/frames";

interface Props {
  value: ForecastHorizonHours;
  onChange: (next: ForecastHorizonHours) => void;
}

/**
 * Round button next to the play control that lets the user pick how far
 * forward the slider reaches. +2 h is radar-only (default); longer horizons
 * pull in HARMONIE hourly model frames.
 */
export function HorizonButton({ value, onChange }: Props) {
  const [open, setOpen] = useState(false);
  const wrapRef = useRef<HTMLDivElement>(null);

  useEffect(() => {
    if (!open) return;
    function onDocClick(e: MouseEvent) {
      if (!wrapRef.current?.contains(e.target as Node)) setOpen(false);
    }
    function onKey(e: KeyboardEvent) {
      if (e.key === "Escape") setOpen(false);
    }
    document.addEventListener("mousedown", onDocClick);
    document.addEventListener("keydown", onKey);
    return () => {
      document.removeEventListener("mousedown", onDocClick);
      document.removeEventListener("keydown", onKey);
    };
  }, [open]);

  return (
    <div ref={wrapRef} className="relative flex-none self-center">
      <button
        type="button"
        onClick={() => setOpen((o) => !o)}
        aria-haspopup="listbox"
        aria-expanded={open}
        aria-label={`Voorspelling-horizon: +${value} uur. Klik om aan te passen.`}
        className="btn-primary inline-grid place-items-center h-12 w-12 rounded-full focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 text-sm font-semibold tabular-nums"
      >
        +{value}u
      </button>
      {open ? (
        <ul
          role="listbox"
          aria-label="Kies voorspelling-horizon"
          className="absolute bottom-full mb-2 left-1/2 -translate-x-1/2 z-50 min-w-[5rem] rounded-xl border border-[--color-ink-200] bg-[--color-overlay] shadow-lg py-1 timeline-panel"
        >
          {FORECAST_HORIZON_HOURS.map((h) => (
            <li key={h}>
              <button
                type="button"
                role="option"
                aria-selected={h === value}
                onClick={() => {
                  onChange(h);
                  setOpen(false);
                }}
                className={`block w-full text-center px-3 py-1.5 text-sm tabular-nums hover:bg-[--color-ink-100] focus:bg-[--color-ink-100] focus:outline-none ${
                  h === value
                    ? "font-semibold text-[--color-accent-600]"
                    : "text-[--color-ink-700]"
                }`}
              >
                +{h} uur
              </button>
            </li>
          ))}
        </ul>
      ) : null}
    </div>
  );
}
