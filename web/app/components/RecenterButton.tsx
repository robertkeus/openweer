import { useGeolocation, type ResolvedLocation } from "~/lib/use-geolocation";

interface Props {
  onLocate: (loc: ResolvedLocation) => void;
}

/** Bottom-right circular button: triggers geolocation and recenters the map. */
export function RecenterButton({ onLocate }: Props) {
  const { resolving, error, resolve } = useGeolocation(onLocate);
  return (
    <div className="flex flex-col items-end gap-2">
      <button
        type="button"
        onClick={() => void resolve()}
        disabled={resolving}
        aria-label="Centreer op mijn locatie"
        className="floating-btn text-[--color-accent-600]"
      >
        {resolving ? (
          <SpinnerIcon className="h-5 w-5 animate-spin" />
        ) : (
          <NavIcon className="h-5 w-5" />
        )}
      </button>
      {error ? (
        <p
          role="alert"
          className="glass-card max-w-[16rem] px-3 py-2 text-xs text-[--color-danger]"
        >
          {error}
        </p>
      ) : null}
    </div>
  );
}

function NavIcon(props: React.SVGProps<SVGSVGElement>) {
  return (
    <svg viewBox="0 0 24 24" fill="none" {...props}>
      <path
        d="M3 11l18-8-8 18-2-8-8-2z"
        stroke="currentColor"
        strokeWidth="1.6"
        strokeLinejoin="round"
        fill="currentColor"
        fillOpacity="0.15"
      />
    </svg>
  );
}

function SpinnerIcon(props: React.SVGProps<SVGSVGElement>) {
  return (
    <svg viewBox="0 0 24 24" fill="none" aria-hidden="true" {...props}>
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
