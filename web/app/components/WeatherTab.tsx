/**
 * Weer tab — current observations from the nearest KNMI station + a
 * placeholder for the multi-day outlook (HARMONIE pipeline lands later).
 */

import type {
  ConditionKind,
  CurrentWeather,
  DailyForecast,
  ForecastResponse,
  WeatherResponse,
} from "~/lib/api";
import { formatHm } from "~/lib/format";

interface Props {
  weather: WeatherResponse | null;
  forecast: ForecastResponse | null;
  loading?: boolean;
  errorMessage?: string;
  forecastErrorMessage?: string;
}

export function WeatherTab({
  weather,
  forecast,
  loading,
  errorMessage,
  forecastErrorMessage,
}: Props) {
  if (errorMessage) {
    return <p className="p-4 text-sm text-[--color-ink-700]">{errorMessage}</p>;
  }
  if (loading || !weather) {
    return <p className="p-4 text-sm text-[--color-ink-700]">Weer laden…</p>;
  }
  const { current, station } = weather;
  return (
    <div className="p-4 space-y-5">
      <NowCard current={current} stationName={station.name} />
      <StatGrid current={current} />
      <ComingDays forecast={forecast} errorMessage={forecastErrorMessage} />
      <p className="text-[11px] text-[--color-ink-700]">
        Waarneming {formatHm(current.observed_at)} · KNMI station{" "}
        <span className="font-medium">{station.name}</span>
        {station.distance_km > 0
          ? ` — ${station.distance_km.toFixed(0)} km`
          : ""}
        {forecast ? " · meerdaags via Open-Meteo" : ""}
      </p>
    </div>
  );
}

function NowCard({
  current,
  stationName,
}: {
  current: CurrentWeather;
  stationName: string;
}) {
  return (
    <div className="rounded-2xl border border-[--color-border] p-4 flex items-center gap-4 weather-now">
      <ConditionGlyph kind={current.condition} className="h-14 w-14 flex-none" />
      <div className="flex-1 min-w-0">
        <p className="text-xs uppercase tracking-wider text-[--color-ink-700]">
          Nu in {stationName.split(" ")[0]}
        </p>
        <p className="mt-0.5 text-4xl font-semibold tracking-tight tabular-nums leading-none">
          {fmtTemp(current.temperature_c)}
        </p>
        <p className="mt-1 text-sm text-[--color-ink-700]">
          {current.condition_label}
          {current.feels_like_c !== null &&
          current.temperature_c !== null &&
          Math.abs(current.feels_like_c - current.temperature_c) >= 1
            ? ` · voelt als ${fmtTemp(current.feels_like_c)}`
            : ""}
        </p>
      </div>
    </div>
  );
}

function StatGrid({ current }: { current: CurrentWeather }) {
  const stats: Array<[string, string]> = [
    [
      "Wind",
      current.wind_speed_bft !== null
        ? `${current.wind_speed_bft} Bft${current.wind_direction_compass ? ` · ${current.wind_direction_compass}` : ""}`
        : "—",
    ],
    [
      "Luchtvochtigheid",
      current.humidity_pct !== null ? `${current.humidity_pct.toFixed(0)}%` : "—",
    ],
    [
      "Regen 24u",
      current.rainfall_24h_mm !== null
        ? `${current.rainfall_24h_mm.toFixed(1)} mm`
        : "—",
    ],
    [
      "Luchtdruk",
      current.pressure_hpa !== null
        ? `${current.pressure_hpa.toFixed(0)} hPa`
        : "—",
    ],
  ];
  return (
    <dl className="grid grid-cols-2 gap-3 text-sm">
      {stats.map(([label, value]) => (
        <div
          key={label}
          className="rounded-xl border border-[--color-border] px-3 py-2"
        >
          <dt className="text-[--color-ink-700] uppercase text-xs tracking-wider">
            {label}
          </dt>
          <dd className="mt-1 font-medium tabular-nums">{value}</dd>
        </div>
      ))}
      <div className="col-span-2 rounded-xl border border-[--color-border] px-3 py-2">
        <dt className="text-[--color-ink-700] uppercase text-xs tracking-wider">
          Bewolking · zicht
        </dt>
        <dd className="mt-1 font-medium tabular-nums">
          {fmtCloudVisibility(current)}
        </dd>
      </div>
    </dl>
  );
}

function ComingDays({
  forecast,
  errorMessage,
}: {
  forecast: ForecastResponse | null;
  errorMessage?: string;
}) {
  return (
    <section aria-labelledby="coming-days">
      <h3
        id="coming-days"
        className="text-[--color-ink-700] uppercase text-xs tracking-wider"
      >
        Komende dagen
      </h3>
      {errorMessage ? (
        <p className="mt-1 text-sm text-[--color-ink-700]">{errorMessage}</p>
      ) : !forecast || forecast.days.length === 0 ? (
        <p className="mt-1 text-sm text-[--color-ink-700]">
          Verwachting laden…
        </p>
      ) : (
        <ul className="mt-2 divide-y divide-[--color-border] rounded-2xl border border-[--color-border] overflow-hidden">
          {forecast.days.map((day, i) => (
            <DayRow key={day.date} day={day} index={i} />
          ))}
        </ul>
      )}
    </section>
  );
}

function DayRow({ day, index }: { day: DailyForecast; index: number }) {
  const kind = wmoToCondition(day.weather_code);
  return (
    <li className="flex items-center gap-3 px-3 py-2.5 text-sm">
      <span className="w-16 flex-none text-[--color-ink-900] font-medium">
        {dayLabel(day.date, index)}
      </span>
      <ConditionGlyph kind={kind} className="h-7 w-7 flex-none" />
      <span className="flex-1 text-[--color-ink-700] truncate">
        {conditionLabelNl(kind)}
      </span>
      {day.precipitation_probability_pct !== null &&
      day.precipitation_probability_pct >= 10 ? (
        <span className="flex-none text-xs text-[--color-accent-600] tabular-nums">
          {day.precipitation_probability_pct}%
        </span>
      ) : null}
      <span className="flex-none w-20 text-right tabular-nums">
        <span className="font-semibold text-[--color-ink-900]">
          {fmtTemp(day.temperature_max_c)}
        </span>
        <span className="ml-1 text-[--color-ink-700]">
          {fmtTemp(day.temperature_min_c)}
        </span>
      </span>
    </li>
  );
}

const _DUTCH_WEEKDAYS = ["zo", "ma", "di", "wo", "do", "vr", "za"] as const;

function dayLabel(iso: string, index: number): string {
  if (index === 0) return "Vandaag";
  if (index === 1) return "Morgen";
  // ISO date; constructing local Date avoids timezone drift since YYYY-MM-DD
  // is parsed as UTC midnight, but for weekday display that's fine in NL.
  const d = new Date(iso);
  const wd = _DUTCH_WEEKDAYS[d.getUTCDay()] ?? "";
  return `${wd} ${d.getUTCDate()}`;
}

function wmoToCondition(code: number | null | undefined): ConditionKind {
  if (code === null || code === undefined) return "unknown";
  if (code === 0) return "clear";
  if (code <= 3) return "partly-cloudy";
  if (code === 45 || code === 48) return "fog";
  if (code >= 51 && code <= 57) return "drizzle";
  if (code >= 61 && code <= 67) return "rain";
  if (code >= 71 && code <= 77) return "snow";
  if (code >= 80 && code <= 82) return "rain";
  if (code === 85 || code === 86) return "snow";
  if (code >= 95) return "thunder";
  return "cloudy";
}

function conditionLabelNl(kind: ConditionKind): string {
  return {
    clear: "Helder",
    "partly-cloudy": "Half bewolkt",
    cloudy: "Bewolkt",
    fog: "Mist",
    drizzle: "Motregen",
    rain: "Regen",
    thunder: "Onweer",
    snow: "Sneeuw",
    unknown: "—",
  }[kind];
}

function fmtTemp(c: number | null): string {
  if (c === null) return "—";
  return `${c.toFixed(0).replace("-", "−")}°`;
}

function fmtCloudVisibility(c: CurrentWeather): string {
  const parts: string[] = [];
  if (c.cloud_cover_octas !== null) {
    parts.push(`${c.cloud_cover_octas.toFixed(0)}/8 bewolkt`);
  }
  if (c.visibility_m !== null) {
    parts.push(
      c.visibility_m >= 1000
        ? `zicht ${(c.visibility_m / 1000).toFixed(0)} km`
        : `zicht ${c.visibility_m.toFixed(0)} m`,
    );
  }
  return parts.length ? parts.join(" · ") : "—";
}

function ConditionGlyph({
  kind,
  className,
}: {
  kind: ConditionKind;
  className?: string;
}) {
  // Unique ids per render so multiple glyphs on a page don't clash.
  const id = (suffix: string) =>
    `${suffix}-${Math.random().toString(36).slice(2, 8)}`;
  const sunGrad = id("sun");
  const cloudGrad = id("cloud");
  return (
    <svg viewBox="0 0 64 64" fill="none" className={className} aria-hidden="true">
      <defs>
        <radialGradient id={sunGrad} cx="32" cy="28" r="14" gradientUnits="userSpaceOnUse">
          <stop offset="0" stopColor="oklch(0.95 0.14 85)" />
          <stop offset="1" stopColor="var(--color-sun-400)" />
        </radialGradient>
        <linearGradient id={cloudGrad} x1="0" y1="0" x2="0" y2="1">
          <stop offset="0" stopColor="oklch(1 0 0)" stopOpacity="0.95" />
          <stop offset="1" stopColor="oklch(0.86 0.012 250)" stopOpacity="0.95" />
        </linearGradient>
      </defs>

      {(kind === "clear" || kind === "partly-cloudy") && (
        <>
          <circle cx="32" cy="28" r="11" fill={`url(#${sunGrad})`} />
          <g
            stroke="var(--color-sun-400)"
            strokeWidth="2"
            strokeLinecap="round"
            opacity="0.85"
          >
            <line x1="32" y1="6" x2="32" y2="11" />
            <line x1="50" y1="28" x2="55" y2="28" />
            <line x1="9" y1="28" x2="14" y2="28" />
            <line x1="46" y1="14" x2="50" y2="10" />
            <line x1="18" y1="14" x2="14" y2="10" />
          </g>
        </>
      )}
      {(kind === "partly-cloudy" || kind === "cloudy" || kind === "rain" ||
        kind === "drizzle" || kind === "thunder" || kind === "snow" ||
        kind === "fog" || kind === "unknown") && (
        <g
          fill={`url(#${cloudGrad})`}
          stroke="oklch(0.78 0.012 250)"
          strokeWidth="0.8"
          strokeLinejoin="round"
        >
          <path d="M14 50c-5 0-9-4-9-8.6 0-4.2 3-7.7 7.2-8.5a10 10 0 0119.2 0.6 7.5 7.5 0 014.6 13.2 6 6 0 01-5 3.3 7 7 0 01-5.4 0z" />
        </g>
      )}
      {kind === "rain" && (
        <g
          stroke="var(--color-accent-600)"
          strokeWidth="2"
          strokeLinecap="round"
        >
          <line x1="20" y1="54" x2="18" y2="60" />
          <line x1="28" y1="54" x2="26" y2="60" />
          <line x1="36" y1="54" x2="34" y2="60" />
        </g>
      )}
      {kind === "drizzle" && (
        <g
          stroke="var(--color-accent-500)"
          strokeWidth="1.5"
          strokeLinecap="round"
        >
          <line x1="20" y1="54" x2="19" y2="58" />
          <line x1="28" y1="54" x2="27" y2="58" />
          <line x1="36" y1="54" x2="35" y2="58" />
        </g>
      )}
      {kind === "snow" && (
        <g fill="var(--color-ink-700)">
          <circle cx="20" cy="56" r="1.4" />
          <circle cx="28" cy="58" r="1.4" />
          <circle cx="36" cy="56" r="1.4" />
        </g>
      )}
      {kind === "thunder" && (
        <path
          d="M30 50l-3 7h4l-2 6 7-9h-4l2-4z"
          fill="var(--color-sun-400)"
          stroke="oklch(0.55 0.18 75)"
          strokeWidth="0.8"
          strokeLinejoin="round"
        />
      )}
      {kind === "fog" && (
        <g
          stroke="var(--color-ink-500)"
          strokeWidth="1.6"
          strokeLinecap="round"
        >
          <line x1="10" y1="56" x2="42" y2="56" />
          <line x1="14" y1="60" x2="46" y2="60" />
        </g>
      )}
    </svg>
  );
}
