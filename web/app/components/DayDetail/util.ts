/**
 * Shared helpers for the day-detail dialog and its children.
 */

import type { ConditionKind, DailyForecast, HourlySlot } from "~/lib/api";

const AMS_TZ = "Europe/Amsterdam";

/** Slots whose `time` falls on the given `yyyy-MM-dd` date in Europe/Amsterdam. */
export function slotsForDate(
  slots: readonly HourlySlot[],
  isoDate: string,
): HourlySlot[] {
  const target = isoDate;
  const formatter = new Intl.DateTimeFormat("en-CA", {
    timeZone: AMS_TZ,
    year: "numeric",
    month: "2-digit",
    day: "2-digit",
  });
  return slots.filter((s) => {
    const d = new Date(s.time);
    if (Number.isNaN(d.getTime())) return false;
    return formatter.format(d) === target;
  });
}

/** "yyyy-MM-dd" for today in Europe/Amsterdam. */
export function todayIso(): string {
  return new Intl.DateTimeFormat("en-CA", {
    timeZone: AMS_TZ,
    year: "numeric",
    month: "2-digit",
    day: "2-digit",
  }).format(new Date());
}

/** "yyyy-MM-dd" for tomorrow in Europe/Amsterdam. */
export function tomorrowIso(): string {
  const t = new Date(Date.now() + 86_400_000);
  return new Intl.DateTimeFormat("en-CA", {
    timeZone: AMS_TZ,
    year: "numeric",
    month: "2-digit",
    day: "2-digit",
  }).format(t);
}

/** "Vandaag", "Morgen", or "Zaterdag 17 mei". */
export function navigationTitleFor(day: DailyForecast): string {
  if (day.date === todayIso()) return "Vandaag";
  if (day.date === tomorrowIso()) return "Morgen";
  return formatLongDate(day.date);
}

export function formatLongDate(isoDate: string): string {
  const d = parseIsoDate(isoDate);
  if (!d) return isoDate;
  return new Intl.DateTimeFormat("nl-NL", {
    timeZone: AMS_TZ,
    weekday: "long",
    day: "numeric",
    month: "long",
  })
    .format(d)
    .replace(/^./, (c) => c.toUpperCase());
}

/** Parses a "yyyy-MM-dd" string as Europe/Amsterdam midnight, returns Date. */
function parseIsoDate(isoDate: string): Date | null {
  const m = /^(\d{4})-(\d{2})-(\d{2})$/.exec(isoDate);
  if (!m) return null;
  // Construct using UTC midnight; for display via Intl.DateTimeFormat in
  // Europe/Amsterdam this lands on the right calendar day.
  return new Date(Date.UTC(Number(m[1]), Number(m[2]) - 1, Number(m[3]), 12));
}

export function fmtTemp(c: number | null | undefined): string {
  if (c === null || c === undefined) return "—";
  return `${c.toFixed(0).replace("-", "−")}°`;
}

export function wmoToCondition(
  code: number | null | undefined,
): ConditionKind {
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

export function conditionLabelNl(kind: ConditionKind): string {
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

const COMPASS = ["N", "NO", "O", "ZO", "Z", "ZW", "W", "NW"];

export function compassFor(deg: number | null | undefined): string | null {
  if (deg === null || deg === undefined) return null;
  const normalised = ((deg % 360) + 360) % 360;
  const idx = Math.floor((normalised + 22.5) / 45) % 8;
  return COMPASS[idx] ?? null;
}

/** "HH" (24h) in Europe/Amsterdam. */
export function hourOfSlot(slot: HourlySlot): number {
  const d = new Date(slot.time);
  if (Number.isNaN(d.getTime())) return -1;
  const fmt = new Intl.DateTimeFormat("nl-NL", {
    timeZone: AMS_TZ,
    hour: "2-digit",
    hour12: false,
  });
  return Number.parseInt(fmt.format(d), 10);
}

export function formatHourLabel(slot: HourlySlot): string {
  return new Intl.DateTimeFormat("nl-NL", {
    timeZone: AMS_TZ,
    hour: "2-digit",
    hour12: false,
  }).format(new Date(slot.time));
}

export function formatHHmmFromIso(iso: string | null | undefined): string | null {
  if (!iso) return null;
  // Open-Meteo emits sunrise/sunset as "yyyy-MM-ddTHH:mm" with no tz; just slice.
  const t = iso.indexOf("T");
  if (t < 0) return null;
  return iso.slice(t + 1, t + 6);
}

export function parseHourFromIso(iso: string | null | undefined): number | null {
  const hhmm = formatHHmmFromIso(iso);
  if (!hhmm) return null;
  const h = Number.parseInt(hhmm.slice(0, 2), 10);
  return Number.isFinite(h) ? h : null;
}
