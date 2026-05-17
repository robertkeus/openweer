/**
 * Weer tab — current observations from the nearest KNMI station + the
 * 8-day daily outlook. Tapping a day opens a drill-down dialog with
 * hour-by-hour conditions (HourlyRainChart, stats grid, etc.).
 */

import { useState } from "react";
import type {
  ConditionKind,
  CurrentWeather,
  DailyForecast,
  ForecastResponse,
  WeatherResponse,
} from "~/lib/api";
import { formatHm } from "~/lib/format";
import { ConditionGlyph } from "~/components/ConditionGlyph";
import {
  DayDetailView,
  type HourlyCacheEntry,
} from "~/components/DayDetail/DayDetailView";

interface Props {
  weather: WeatherResponse | null;
  forecast: ForecastResponse | null;
  coord: { lat: number; lon: number };
  loading?: boolean;
  errorMessage?: string;
  forecastErrorMessage?: string;
}

export function WeatherTab({
  weather,
  forecast,
  coord,
  loading,
  errorMessage,
  forecastErrorMessage,
}: Props) {
  const [selectedDay, setSelectedDay] = useState<DailyForecast | null>(null);
  // Cache the hourly response so re-opening a day within ~10 min renders
  // synchronously. The dialog ignores entries whose lat/lon don't match
  // the active coord, so no explicit invalidation is needed on location
  // change.
  const [hourlyCache, setHourlyCache] = useState<HourlyCacheEntry | null>(null);

  if (errorMessage) {
    return <p className="p-4 text-sm text-[--color-ink-700]">{errorMessage}</p>;
  }
  if (loading || !weather) {
    return <p className="p-4 text-sm text-[--color-ink-700]">Weer laden…</p>;
  }

  // When a day is selected, the same panel slot renders the detail view
  // instead of the daily list — no modal, no backdrop. "Terug" goes back.
  if (selectedDay) {
    return (
      <DayDetailView
        day={selectedDay}
        coord={coord}
        hourlyCache={hourlyCache}
        onClose={() => setSelectedDay(null)}
        onHourlyLoaded={setHourlyCache}
      />
    );
  }

  const { current, station } = weather;
  return (
    <div className="p-4 space-y-5">
      <NowCard current={current} stationName={station.name} />
      <ComingDays
        forecast={forecast}
        errorMessage={forecastErrorMessage}
        onSelect={setSelectedDay}
      />
      <StatGrid current={current} />
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
      <ConditionGlyph
        kind={current.condition}
        className="h-14 w-14 flex-none"
      />
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
      current.humidity_pct !== null
        ? `${current.humidity_pct.toFixed(0)}%`
        : "—",
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
  onSelect,
}: {
  forecast: ForecastResponse | null;
  errorMessage?: string;
  onSelect: (day: DailyForecast) => void;
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
            <li key={day.date}>
              <DayRow day={day} index={i} onSelect={onSelect} />
            </li>
          ))}
        </ul>
      )}
    </section>
  );
}

function DayRow({
  day,
  index,
  onSelect,
}: {
  day: DailyForecast;
  index: number;
  onSelect: (day: DailyForecast) => void;
}) {
  const kind = wmoToCondition(day.weather_code);
  return (
    <button
      type="button"
      onClick={() => onSelect(day)}
      aria-haspopup="dialog"
      aria-label={`Details voor ${dayLabel(day.date, index)}`}
      className="w-full flex items-center gap-3 px-3 py-2.5 text-sm text-left hover:bg-[--color-border]/40 focus:bg-[--color-border]/40 focus:outline-none transition"
    >
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
      <span
        aria-hidden="true"
        className="flex-none text-[--color-ink-700] opacity-60"
      >
        ›
      </span>
    </button>
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
