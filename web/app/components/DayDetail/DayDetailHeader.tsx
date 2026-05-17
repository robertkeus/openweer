import type { DailyForecast, HourlySlot } from "~/lib/api";
import { ConditionGlyph } from "~/components/ConditionGlyph";
import {
  conditionLabelNl,
  fmtTemp,
  formatLongDate,
  wmoToCondition,
} from "./util";

interface Props {
  day: DailyForecast;
  slots: readonly HourlySlot[];
}

/** Top card on the day-detail dialog. Renders synchronously from `day`,
 *  so the dialog has visible content immediately on open. */
export function DayDetailHeader({ day, slots }: Props) {
  const kind = wmoToCondition(day.weather_code);
  return (
    <div className="rounded-2xl border border-[--color-border] p-4 flex items-start gap-4">
      <div className="flex-1 min-w-0">
        <p className="text-xs uppercase tracking-wider text-[--color-ink-700]">
          {formatLongDate(day.date)}
        </p>
        <p className="mt-0.5 text-lg font-semibold text-[--color-ink-900]">
          {conditionLabelNl(kind)}
        </p>
        {summaryLine(day, slots) ? (
          <p className="mt-1 text-sm text-[--color-ink-700]">
            {summaryLine(day, slots)}
          </p>
        ) : null}
      </div>
      <div className="flex-none text-right">
        <div className="flex items-start gap-2 justify-end">
          <span className="text-4xl font-semibold tabular-nums tracking-tight text-[--color-ink-900]">
            {fmtTemp(day.temperature_max_c)}
          </span>
          <ConditionGlyph kind={kind} className="h-10 w-10" />
        </div>
        <p className="mt-1 text-xs text-[--color-ink-700] tabular-nums">
          min {fmtTemp(day.temperature_min_c)}
        </p>
      </div>
    </div>
  );
}

function summaryLine(
  day: DailyForecast,
  slots: readonly HourlySlot[],
): string | null {
  if (slots.length > 0) {
    const total = slots.reduce((s, x) => s + (x.precipitation_mm ?? 0), 0);
    const peakProb = slots.reduce(
      (m, s) => Math.max(m, s.precipitation_probability_pct ?? 0),
      0,
    );
    if (total >= 0.1) {
      return `${total.toFixed(1)} mm regen verwacht, piekkans ${peakProb}%`;
    }
    if (peakProb >= 30) return `Kans op een bui, piek ${peakProb}%`;
    return "Geen regen verwacht";
  }
  if (day.precipitation_sum_mm !== null && day.precipitation_sum_mm >= 0.1) {
    return `${day.precipitation_sum_mm.toFixed(1)} mm regen verwacht`;
  }
  if (
    day.precipitation_probability_pct !== null &&
    day.precipitation_probability_pct >= 30
  ) {
    return `Kans op een bui (${day.precipitation_probability_pct}%)`;
  }
  return null;
}
