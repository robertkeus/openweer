import { useEffect, useId, useMemo, useRef, useState } from "react";
import { KNOWN_LOCATIONS } from "~/lib/locations";
import { useGeolocation } from "~/lib/use-geolocation";

export interface SelectedLocation {
  name: string;
  lat: number;
  lon: number;
}

interface Props {
  current: SelectedLocation;
  onSelect: (loc: SelectedLocation) => void;
}

interface Suggestion {
  key: string;
  name: string;
  detail?: string;
  lat: number;
  lon: number;
}

const NL_VIEWBOX = "3.0,53.7,7.4,50.6"; // left,top,right,bottom for Nominatim

interface NominatimResult {
  display_name?: string;
  lat: string;
  lon: string;
  name?: string;
  osm_id?: number;
  place_id?: number;
  address?: { state?: string; county?: string; city?: string; town?: string; village?: string; municipality?: string; country?: string };
}

async function searchNominatim(
  q: string,
  signal: AbortSignal,
): Promise<Suggestion[]> {
  const url = new URL("https://nominatim.openstreetmap.org/search");
  url.searchParams.set("q", q);
  url.searchParams.set("countrycodes", "nl");
  url.searchParams.set("limit", "6");
  url.searchParams.set("format", "jsonv2");
  url.searchParams.set("addressdetails", "1");
  url.searchParams.set("viewbox", NL_VIEWBOX);
  url.searchParams.set("bounded", "1");
  const res = await fetch(url, {
    signal,
    headers: { "Accept-Language": "nl,en" },
  });
  if (!res.ok) return [];
  const data = (await res.json()) as NominatimResult[];
  return data.map((r) => {
    const a = r.address ?? {};
    const name =
      a.city ?? a.town ?? a.village ?? a.municipality ?? r.name ?? r.display_name?.split(",")[0] ?? "Onbekend";
    const detail = a.state ?? a.county ?? "";
    return {
      key: `osm-${r.osm_id ?? r.place_id ?? `${r.lat}-${r.lon}`}`,
      name,
      detail,
      lat: parseFloat(r.lat),
      lon: parseFloat(r.lon),
    };
  });
}

export function LocationBar({ current, onSelect }: Props) {
  const [query, setQuery] = useState("");
  const [open, setOpen] = useState(false);
  const [remote, setRemote] = useState<Suggestion[]>([]);
  const [searching, setSearching] = useState(false);
  const inputRef = useRef<HTMLInputElement>(null);
  const wrapRef = useRef<HTMLDivElement>(null);
  const errorId = useId();
  const listboxId = useId();

  const { resolving, error, resolve } = useGeolocation((loc) => {
    onSelect(loc);
    setQuery("");
    setOpen(false);
    inputRef.current?.blur();
  });

  // Close on outside click.
  useEffect(() => {
    if (!open) return;
    function onDoc(e: MouseEvent) {
      if (wrapRef.current && !wrapRef.current.contains(e.target as Node)) {
        setOpen(false);
      }
    }
    document.addEventListener("mousedown", onDoc);
    return () => document.removeEventListener("mousedown", onDoc);
  }, [open]);

  // Local fuzzy filter over the known cities — instant, no network.
  const localMatches = useMemo<Suggestion[]>(() => {
    const q = query.trim().toLowerCase();
    return KNOWN_LOCATIONS.filter((l) =>
      q ? l.name.toLowerCase().includes(q) : true,
    )
      .slice(0, 6)
      .map((l) => ({
        key: `seed-${l.slug}`,
        name: l.name,
        lat: l.lat,
        lon: l.lon,
      }));
  }, [query]);

  // Debounced Nominatim search for ≥2 chars.
  useEffect(() => {
    const q = query.trim();
    if (q.length < 2) {
      setRemote([]);
      setSearching(false);
      return;
    }
    const ctrl = new AbortController();
    setSearching(true);
    const t = window.setTimeout(() => {
      searchNominatim(q, ctrl.signal)
        .then((r) => setRemote(r))
        .catch(() => {})
        .finally(() => setSearching(false));
    }, 280);
    return () => {
      ctrl.abort();
      window.clearTimeout(t);
    };
  }, [query]);

  const suggestions = useMemo<Suggestion[]>(() => {
    const seen = new Set<string>();
    const out: Suggestion[] = [];
    for (const s of [...localMatches, ...remote]) {
      const k = `${s.name.toLowerCase()}|${s.lat.toFixed(2)},${s.lon.toFixed(2)}`;
      if (seen.has(k)) continue;
      seen.add(k);
      out.push(s);
      if (out.length >= 8) break;
    }
    return out;
  }, [localMatches, remote]);

  function pick(s: Suggestion) {
    onSelect({ name: s.name, lat: s.lat, lon: s.lon });
    setQuery("");
    setOpen(false);
    inputRef.current?.blur();
  }

  return (
    <div
      ref={wrapRef}
      role="region"
      aria-label="Locatiekiezer"
      className="relative flex flex-col items-stretch"
    >
      <div className="glass-card flex items-center gap-2 pl-3 pr-2 py-2">
        <span
          aria-hidden="true"
          className="grid place-items-center h-8 w-8 rounded-xl flex-none"
          style={{ background: "color-mix(in oklab, var(--color-accent-500) 15%, transparent)", color: "var(--color-accent-600)" }}
        >
          <SearchIcon className="h-4 w-4" />
        </span>
        <input
          ref={inputRef}
          type="search"
          role="combobox"
          aria-expanded={open}
          aria-controls={listboxId}
          aria-autocomplete="list"
          placeholder={current.name}
          value={query}
          onChange={(e) => {
            setQuery(e.target.value);
            setOpen(true);
          }}
          onFocus={() => setOpen(true)}
          onKeyDown={(e) => {
            if (e.key === "Escape") {
              setOpen(false);
              inputRef.current?.blur();
            }
          }}
          className="flex-1 min-w-0 bg-transparent text-base font-semibold leading-tight placeholder:text-[--color-ink-900] focus:outline-none"
          aria-label="Zoek een plaats"
        />
        <button
          type="button"
          onClick={() => {
            setOpen(false);
            void resolve();
          }}
          disabled={resolving}
          aria-describedby={error ? errorId : undefined}
          aria-label="Gebruik mijn huidige locatie"
          title="Mijn locatie"
          className="btn-primary grid place-items-center h-8 w-8 rounded-full flex-none focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2"
        >
          {resolving ? <SpinnerIcon /> : <CrosshairIcon className="h-4 w-4" />}
        </button>
      </div>

      {open ? (
        <ul
          id={listboxId}
          role="listbox"
          aria-label="Plaatsen"
          className="glass-card absolute top-full inset-x-0 mt-2 max-h-80 overflow-auto p-1 z-30"
        >
          {suggestions.length === 0 ? (
            <li role="none" className="px-3 py-3 text-sm text-[--color-ink-700]">
              {searching
                ? "Zoeken…"
                : query.trim()
                  ? "Geen plaats gevonden in Nederland."
                  : "Begin te typen om te zoeken."}
            </li>
          ) : (
            suggestions.map((s) => {
              const selected = s.name === current.name;
              return (
                <li key={s.key} role="none">
                  <button
                    type="button"
                    role="option"
                    aria-selected={selected}
                    onClick={() => pick(s)}
                    className={`w-full text-left px-3 py-2 rounded-xl text-sm hover:bg-[--color-ink-50] focus-visible:bg-[--color-ink-50] flex items-baseline justify-between gap-3`}
                  >
                    <span
                      className={`font-medium ${selected ? "text-[--color-accent-600]" : "text-[--color-ink-900]"}`}
                    >
                      {s.name}
                    </span>
                    {s.detail ? (
                      <span className="text-xs text-[--color-ink-700] truncate">
                        {s.detail}
                      </span>
                    ) : null}
                  </button>
                </li>
              );
            })
          )}
        </ul>
      ) : null}

      {error ? (
        <p
          id={errorId}
          role="alert"
          className="glass-card mt-2 px-3 py-2 text-sm"
          style={{ color: "var(--color-danger)" }}
        >
          {error}
        </p>
      ) : null}
    </div>
  );
}

function SearchIcon(props: React.SVGProps<SVGSVGElement>) {
  return (
    <svg viewBox="0 0 24 24" fill="none" {...props}>
      <circle cx="11" cy="11" r="6" stroke="currentColor" strokeWidth="1.8" />
      <path
        d="M20 20l-3.5-3.5"
        stroke="currentColor"
        strokeWidth="1.8"
        strokeLinecap="round"
      />
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
