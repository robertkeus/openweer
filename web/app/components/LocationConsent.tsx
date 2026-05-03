import { useEffect, useId, useRef } from "react";

interface Props {
  onAccept: () => void;
  onDismiss: () => void;
  resolving: boolean;
  error: string | null;
}

/**
 * Centered modal asking the user to share their location. Backdrop dims the
 * map; ESC dismisses; the primary button auto-focuses for keyboard users.
 */
export function LocationConsent({
  onAccept,
  onDismiss,
  resolving,
  error,
}: Props) {
  const titleId = useId();
  const descId = useId();
  const acceptRef = useRef<HTMLButtonElement>(null);

  useEffect(() => {
    acceptRef.current?.focus();
    function onKey(e: KeyboardEvent) {
      if (e.key === "Escape") onDismiss();
    }
    document.addEventListener("keydown", onKey);
    return () => document.removeEventListener("keydown", onKey);
  }, [onDismiss]);

  return (
    <div className="location-consent-root fixed inset-0 z-40 grid place-items-center px-4">
      <button
        type="button"
        aria-label="Sluit dialoog"
        onClick={onDismiss}
        className="absolute inset-0 bg-[--color-ink-900]/30 backdrop-blur-[2px] motion-safe:animate-[fadeIn_200ms_ease]"
      />
      <div
        role="dialog"
        aria-modal="true"
        aria-labelledby={titleId}
        aria-describedby={descId}
        className="relative w-full max-w-md rounded-3xl bg-[--color-surface] shadow-2xl border border-[--color-border] motion-safe:animate-[popIn_220ms_cubic-bezier(0.32,0.72,0,1)] overflow-hidden"
      >
        <div className="px-6 pt-7 pb-6 text-center">
          <Illustration className="mx-auto h-20 w-20" aria-hidden="true" />
          <h2
            id={titleId}
            className="mt-4 text-xl font-semibold tracking-tight text-[--color-ink-900]"
          >
            Toon de regen voor jouw locatie
          </h2>
          <p
            id={descId}
            className="mt-2 text-sm text-[--color-ink-700] leading-relaxed"
          >
            We gebruiken je coördinaten alleen om de minutenvoorspelling op
            jouw plek te laten zien. Niets wordt opgeslagen of gedeeld.
          </p>
          {error ? (
            <p
              role="alert"
              className="mt-4 rounded-xl bg-[--color-danger-bg] px-3 py-2 text-sm text-[--color-danger-fg]"
            >
              {error}
            </p>
          ) : null}
        </div>
        <div className="px-6 pb-6 flex flex-col gap-2">
          <button
            ref={acceptRef}
            type="button"
            onClick={onAccept}
            disabled={resolving}
            className="btn-primary inline-flex items-center justify-center gap-2 h-12 rounded-2xl text-base font-semibold focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2"
          >
            {resolving ? <SpinnerIcon /> : <CrosshairIcon className="h-5 w-5" />}
            {resolving ? "Locatie zoeken…" : "Ja, gebruik mijn locatie"}
          </button>
          <button
            type="button"
            onClick={onDismiss}
            className="btn-secondary h-11 rounded-2xl text-sm font-medium focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2"
          >
            Niet nu
          </button>
        </div>
      </div>
    </div>
  );
}

function Illustration(props: React.SVGProps<SVGSVGElement>) {
  return (
    <svg viewBox="0 0 80 80" fill="none" {...props}>
      <defs>
        <radialGradient id="lc-glow" cx="40" cy="44" r="34" gradientUnits="userSpaceOnUse">
          <stop offset="0" stopColor="var(--color-accent-500)" stopOpacity="0.35" />
          <stop offset="1" stopColor="var(--color-accent-500)" stopOpacity="0" />
        </radialGradient>
      </defs>
      <circle cx="40" cy="44" r="34" fill="url(#lc-glow)" />
      <circle cx="40" cy="44" r="22" stroke="var(--color-accent-600)" strokeWidth="1.5" strokeDasharray="2 4" opacity="0.55" />
      <path
        d="M40 18c-8.8 0-16 7-16 15.6 0 11 16 26.4 16 26.4s16-15.4 16-26.4C56 25 48.8 18 40 18Z"
        fill="var(--color-accent-600)"
      />
      <circle cx="40" cy="33" r="5.5" fill="white" />
    </svg>
  );
}

function CrosshairIcon(props: React.SVGProps<SVGSVGElement>) {
  return (
    <svg viewBox="0 0 24 24" fill="none" {...props}>
      <circle cx="12" cy="12" r="4" stroke="currentColor" strokeWidth="2" />
      <path
        d="M12 2v3M12 19v3M2 12h3M19 12h3"
        stroke="currentColor"
        strokeWidth="2"
        strokeLinecap="round"
      />
    </svg>
  );
}

function SpinnerIcon() {
  return (
    <svg
      viewBox="0 0 24 24"
      fill="none"
      className="h-5 w-5 animate-spin"
      aria-hidden="true"
    >
      <circle
        cx="12"
        cy="12"
        r="10"
        stroke="currentColor"
        strokeWidth="2"
        opacity="0.3"
      />
      <path
        d="M22 12a10 10 0 0 0-10-10"
        stroke="currentColor"
        strokeWidth="2"
        strokeLinecap="round"
      />
    </svg>
  );
}
