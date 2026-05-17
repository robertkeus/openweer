import type { DailyForecast, HourlySlot } from "~/lib/api";
import { compassFor, formatHHmmFromIso } from "./util";

interface Props {
  day: DailyForecast;
  slots: readonly HourlySlot[];
}

/** 2x2 grid of summary tiles: Wind, Vochtigheid, UV-index, Zon. */
export function DayDetailStatsGrid({ day, slots }: Props) {
  return (
    <section aria-labelledby="day-detail-stats">
      <h3
        id="day-detail-stats"
        className="text-[--color-ink-700] uppercase text-xs tracking-wider"
      >
        Details
      </h3>
      <dl className="mt-2 grid grid-cols-2 gap-3">
        <Tile
          title="Wind"
          primary={windPrimary(day, slots)}
          caption={windCaption(day, slots)}
        />
        <Tile
          title="Vochtigheid"
          primary={humidityPrimary(slots)}
          caption={humidityCaption(slots)}
        />
        <Tile
          title="UV-index"
          primary={uvPrimary(slots)}
          caption={uvCaption(slots)}
        />
        <Tile
          title="Zon"
          primary={formatHHmmFromIso(day.sunrise) ?? "—"}
          caption={
            formatHHmmFromIso(day.sunset)
              ? `onder ${formatHHmmFromIso(day.sunset)}`
              : null
          }
        />
      </dl>
    </section>
  );
}

function Tile({
  title,
  primary,
  caption,
}: {
  title: string;
  primary: string;
  caption: string | null;
}) {
  return (
    <div className="rounded-xl border border-[--color-border] px-3 py-2">
      <dt className="text-[--color-ink-700] uppercase text-xs tracking-wider">
        {title}
      </dt>
      <dd className="mt-1">
        <span className="text-lg font-semibold tabular-nums text-[--color-ink-900]">
          {primary}
        </span>
        {caption ? (
          <span className="ml-2 text-xs text-[--color-ink-700]">
            {caption}
          </span>
        ) : null}
      </dd>
    </div>
  );
}

function windPrimary(day: DailyForecast, slots: readonly HourlySlot[]): string {
  const peak = max(slots.map((s) => s.wind_speed_kph));
  if (peak !== null) return `${Math.round(peak)} km/u`;
  if (day.wind_max_kph !== null) return `${Math.round(day.wind_max_kph)} km/u`;
  return "—";
}

function windCaption(
  day: DailyForecast,
  slots: readonly HourlySlot[],
): string | null {
  const gust = max(slots.map((s) => s.wind_gusts_kph));
  const dir =
    circularMean(slots.map((s) => s.wind_direction_deg)) ?? day.wind_direction_deg;
  const parts: string[] = [];
  const compass = compassFor(dir);
  if (compass) parts.push(compass);
  if (gust !== null && gust > 0) {
    parts.push(`windstoten ${Math.round(gust)} km/u`);
  }
  return parts.length ? parts.join(" · ") : null;
}

function humidityPrimary(slots: readonly HourlySlot[]): string {
  const vals = slots
    .map((s) => s.relative_humidity_pct)
    .filter((v): v is number => v !== null);
  if (!vals.length) return "—";
  const mean = vals.reduce((a, b) => a + b, 0) / vals.length;
  return `${Math.round(mean)}%`;
}

function humidityCaption(slots: readonly HourlySlot[]): string | null {
  const vals = slots
    .map((s) => s.relative_humidity_pct)
    .filter((v): v is number => v !== null);
  if (!vals.length) return null;
  const lo = Math.min(...vals);
  const hi = Math.max(...vals);
  return `${lo}% – ${hi}%`;
}

function uvPrimary(slots: readonly HourlySlot[]): string {
  const peak = max(slots.map((s) => s.uv_index));
  return peak === null ? "—" : `${Math.round(peak)}`;
}

function uvCaption(slots: readonly HourlySlot[]): string | null {
  const peak = max(slots.map((s) => s.uv_index));
  if (peak === null) return null;
  if (peak < 3) return "Laag";
  if (peak < 6) return "Matig";
  if (peak < 8) return "Hoog";
  if (peak < 11) return "Zeer hoog";
  return "Extreem";
}

function max(values: readonly (number | null)[]): number | null {
  const clean = values.filter((v): v is number => v !== null);
  return clean.length ? Math.max(...clean) : null;
}

function circularMean(values: readonly (number | null)[]): number | null {
  const clean = values.filter((v): v is number => v !== null);
  if (!clean.length) return null;
  let sx = 0;
  let sy = 0;
  for (const deg of clean) {
    const rad = (deg * Math.PI) / 180;
    sx += Math.cos(rad);
    sy += Math.sin(rad);
  }
  let deg = (Math.atan2(sy / clean.length, sx / clean.length) * 180) / Math.PI;
  if (deg < 0) deg += 360;
  return Math.round(deg);
}
