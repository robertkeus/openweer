/**
 * Dutch number/time formatting helpers. Intentionally tiny — no Intl wrappers
 * leak into components.
 */

const NL = "nl-NL";

/** Format mm/h with one decimal, Dutch comma. */
export function formatMmPerHour(mm: number): string {
  return `${new Intl.NumberFormat(NL, {
    minimumFractionDigits: 1,
    maximumFractionDigits: 1,
  }).format(mm)} mm/u`;
}

/** Verdict matching the convention from popular rain radar companies: dry / light / moderate / heavy. */
export type RainVerdict = "droog" | "licht" | "matig" | "zwaar";

const THRESHOLDS: ReadonlyArray<readonly [number, RainVerdict]> = [
  [0.1, "droog"],
  [1.0, "licht"],
  [5.0, "matig"],
  [Infinity, "zwaar"],
];

export function rainVerdict(mmPerHour: number): RainVerdict {
  for (const [upper, verdict] of THRESHOLDS) {
    if (mmPerHour < upper) return verdict;
  }
  return "zwaar";
}

/** "06:30" — short Dutch local time from an ISO timestamp. */
export function formatHm(iso: string): string {
  const date = new Date(iso);
  return new Intl.DateTimeFormat(NL, {
    hour: "2-digit",
    minute: "2-digit",
    hour12: false,
    timeZone: "Europe/Amsterdam",
  }).format(date);
}

/** "+1u 35m" — relative offset in hours+minutes for the slider tooltip. */
export function formatRelativeOffset(minutes: number): string {
  const sign = minutes < 0 ? "-" : "+";
  const abs = Math.abs(minutes);
  const h = Math.floor(abs / 60);
  const m = abs % 60;
  if (h === 0) return `${sign}${m}m`;
  if (m === 0) return `${sign}${h}u`;
  return `${sign}${h}u ${m.toString().padStart(2, "0")}m`;
}
