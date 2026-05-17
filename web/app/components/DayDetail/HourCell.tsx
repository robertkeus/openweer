import type { ConditionKind } from "~/lib/api";
import { ConditionGlyph } from "~/components/ConditionGlyph";
import { conditionLabelNl, fmtTemp } from "./util";

interface Props {
  label: string;
  kind: ConditionKind;
  temperatureC: number | null;
  precipitationProbabilityPct: number | null;
  isHighlighted: boolean;
}

/** Single column inside the horizontal hourly strip — fixed 56 px wide. */
export function HourCell({
  label,
  kind,
  temperatureC,
  precipitationProbabilityPct,
  isHighlighted,
}: Props) {
  const showPct =
    precipitationProbabilityPct !== null && precipitationProbabilityPct >= 10;
  const parts = [
    label,
    conditionLabelNl(kind).toLowerCase(),
    temperatureC === null
      ? null
      : `${Math.round(temperatureC)} graden`,
    showPct ? `${precipitationProbabilityPct} procent kans op regen` : null,
  ].filter(Boolean);
  return (
    <div
      role="listitem"
      aria-label={parts.join(", ")}
      className="flex-none w-14 flex flex-col items-center gap-1.5 select-none"
    >
      <span
        className={`text-xs tabular-nums ${
          isHighlighted
            ? "font-semibold text-[--color-accent-600]"
            : "font-medium text-[--color-ink-700]"
        }`}
      >
        {label}
      </span>
      <ConditionGlyph kind={kind} className="h-7 w-7" />
      <span className="h-3 text-[11px] tabular-nums text-[--color-accent-600]">
        {showPct ? `${precipitationProbabilityPct}%` : ""}
      </span>
      <span className="text-sm font-semibold tabular-nums text-[--color-ink-900]">
        {fmtTemp(temperatureC)}
      </span>
    </div>
  );
}
