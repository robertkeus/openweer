import { useId, useState, useTransition } from "react";
import {
  GeolocationError,
  getCurrentPosition,
  isInNetherlands,
} from "~/lib/geolocation";
import { KNOWN_LOCATIONS } from "~/lib/locations";

export interface SelectedLocation {
  name: string;
  lat: number;
  lon: number;
}

interface Props {
  current: SelectedLocation;
  onSelect: (loc: SelectedLocation) => void;
}

export function LocationBar({ current, onSelect }: Props) {
  const [resolving, setResolving] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [, startTransition] = useTransition();
  const errorId = useId();
  const selectId = useId();

  async function useMyLocation() {
    setError(null);
    setResolving(true);
    try {
      const pos = await getCurrentPosition();
      if (!isInNetherlands(pos)) {
        setError(
          "Je locatie ligt buiten Nederland — de radar dekt alleen de Lage Landen.",
        );
        return;
      }
      startTransition(() => {
        onSelect({ name: "Jouw locatie", lat: pos.lat, lon: pos.lon });
      });
    } catch (e) {
      setError(
        e instanceof GeolocationError
          ? e.message
          : "Er ging iets mis bij het ophalen van je locatie.",
      );
    } finally {
      setResolving(false);
    }
  }

  function pickLocation(slug: string) {
    const found = KNOWN_LOCATIONS.find((l) => l.slug === slug);
    if (found) {
      setError(null);
      startTransition(() => {
        onSelect({ name: found.name, lat: found.lat, lon: found.lon });
      });
    }
  }

  return (
    <div
      role="region"
      aria-label="Locatiekiezer"
      className="rounded-2xl border border-[--color-ink-100] bg-white p-3 shadow-sm flex flex-col sm:flex-row sm:items-center gap-3"
    >
      <div className="flex items-center gap-3 flex-1 min-w-0">
        <span
          aria-hidden="true"
          className="grid place-items-center h-9 w-9 rounded-xl bg-[--color-accent-500]/10 text-[--color-accent-600]"
        >
          <PinIcon className="h-5 w-5" />
        </span>
        <div className="min-w-0">
          <p className="text-xs uppercase tracking-wider text-[--color-ink-500]">
            Locatie
          </p>
          <p className="text-base font-semibold leading-tight truncate">
            {current.name}
          </p>
        </div>
      </div>

      <div className="flex flex-col sm:flex-row sm:items-center gap-2 sm:gap-3">
        <button
          type="button"
          onClick={useMyLocation}
          disabled={resolving}
          aria-describedby={error ? errorId : undefined}
          className="inline-flex items-center justify-center gap-2 rounded-xl bg-[--color-accent-600] hover:bg-[--color-accent-500] disabled:opacity-60 text-white px-4 py-2 text-sm font-medium transition-colors focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-[--color-accent-500]"
        >
          {resolving ? <SpinnerIcon /> : <PinIcon className="h-4 w-4" />}
          {resolving ? "Locatie zoeken…" : "Mijn locatie"}
        </button>
        <label htmlFor={selectId} className="sr-only">
          Kies een plaats
        </label>
        <select
          id={selectId}
          onChange={(e) => pickLocation(e.target.value)}
          value=""
          className="rounded-xl border border-[--color-ink-100] bg-white px-3 py-2 text-sm font-medium text-[--color-ink-900] focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-[--color-accent-500]"
        >
          <option value="" disabled>
            Andere plaats…
          </option>
          {KNOWN_LOCATIONS.map((l) => (
            <option key={l.slug} value={l.slug}>
              {l.name}
            </option>
          ))}
        </select>
      </div>

      {error ? (
        <p
          id={errorId}
          role="alert"
          className="text-sm text-red-600 sm:basis-full sm:order-last"
        >
          {error}
        </p>
      ) : null}
    </div>
  );
}

function PinIcon(props: React.SVGProps<SVGSVGElement>) {
  return (
    <svg viewBox="0 0 24 24" fill="none" {...props}>
      <path
        d="M12 21s-7-7.5-7-12a7 7 0 1 1 14 0c0 4.5-7 12-7 12z"
        stroke="currentColor"
        strokeWidth="1.6"
        strokeLinejoin="round"
      />
      <circle cx="12" cy="9" r="2.5" fill="currentColor" />
    </svg>
  );
}

function SpinnerIcon() {
  return (
    <svg
      viewBox="0 0 24 24"
      fill="none"
      className="h-4 w-4 animate-spin"
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
