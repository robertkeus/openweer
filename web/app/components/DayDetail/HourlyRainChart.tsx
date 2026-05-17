import type { HourlySlot } from "~/lib/api";
import { rainColor } from "~/lib/rain-color";

interface Props {
  slots: readonly HourlySlot[];
  pending: boolean;
}

const VIEW_WIDTH = 100;
const VIEW_HEIGHT = 110;
const BAR_GAP = 0.4;
const Y_MIN = 2; // mm/h — keep dry forecasts visually grounded.

const AMS_TZ = "Europe/Amsterdam";

/** 24-bar SVG chart of `precipitation_mm` per hour, reusing the radar
 *  nowcast palette so colours match across charts. */
export function HourlyRainChart({ slots, pending }: Props) {
  if (pending && slots.length === 0) {
    return (
      <section aria-labelledby="day-detail-rain">
        <h3
          id="day-detail-rain"
          className="text-[--color-ink-700] uppercase text-xs tracking-wider"
        >
          Regen per uur
        </h3>
        <div className="mt-2 rounded-2xl border border-[--color-border] p-3 motion-safe:animate-pulse">
          <div className="h-[110px] rounded-lg bg-[--color-border]/60" />
          <div className="mt-2 h-3 w-2/3 rounded bg-[--color-border]" />
        </div>
      </section>
    );
  }
  if (slots.length === 0) return null;

  const max = Math.max(
    Y_MIN,
    Math.ceil(slots.reduce((m, s) => Math.max(m, s.precipitation_mm ?? 0), 0) * 1.2),
  );
  const total = slots.reduce((s, x) => s + (x.precipitation_mm ?? 0), 0);
  const peak = slots.reduce<HourlySlot | null>((best, s) => {
    if ((s.precipitation_mm ?? 0) <= 0) return best;
    if (!best || (s.precipitation_mm ?? 0) > (best.precipitation_mm ?? 0)) {
      return s;
    }
    return best;
  }, null);

  const barWidth = (VIEW_WIDTH - BAR_GAP * (slots.length - 1)) / slots.length;
  const titleId = `hourly-rain-title-${slots[0].time}`;
  const descId = `hourly-rain-desc-${slots[0].time}`;
  const titleText =
    total < 0.1
      ? "Geen regen verwacht vandaag"
      : peak
        ? `Totaal ${total.toFixed(1)} mm, piek ${peakLabel(peak)}`
        : `Totaal ${total.toFixed(1)} mm regen`;

  return (
    <section aria-labelledby="day-detail-rain">
      <div className="flex items-baseline justify-between">
        <h3
          id="day-detail-rain"
          className="text-[--color-ink-700] uppercase text-xs tracking-wider"
        >
          Regen per uur
        </h3>
        {peak ? (
          <span className="text-xs text-[--color-ink-700] tabular-nums">
            piek {peakLabel(peak)}
          </span>
        ) : null}
      </div>
      <figure className="mt-2 rounded-2xl border border-[--color-border] p-3">
        <svg
          viewBox={`0 0 ${VIEW_WIDTH} ${VIEW_HEIGHT}`}
          preserveAspectRatio="none"
          role="img"
          aria-labelledby={titleId}
          aria-describedby={descId}
          className="w-full h-[110px]"
        >
          <title id={titleId}>Regen per uur</title>
          <desc id={descId}>{titleText}</desc>
          {slots.map((slot, i) => {
            const mm = slot.precipitation_mm ?? 0;
            const h = Math.max(1, (Math.min(mm, max) / max) * (VIEW_HEIGHT - 18));
            const x = i * (barWidth + BAR_GAP);
            const y = VIEW_HEIGHT - h - 4;
            return (
              <rect
                key={slot.time}
                x={x}
                y={y}
                width={barWidth}
                height={h}
                rx="0.4"
                fill={rainColor(mm)}
              />
            );
          })}
        </svg>
        <figcaption className="mt-2 flex justify-between text-[10px] font-medium text-[--color-ink-700] tabular-nums">
          {timeMarkers(slots).map((label, idx) => (
            <span key={idx}>{label}</span>
          ))}
        </figcaption>
      </figure>
    </section>
  );
}

function timeMarkers(slots: readonly HourlySlot[]): string[] {
  const fmt = new Intl.DateTimeFormat("nl-NL", {
    timeZone: AMS_TZ,
    hour: "2-digit",
    minute: "2-digit",
    hour12: false,
  });
  const hourFmt = new Intl.DateTimeFormat("nl-NL", {
    timeZone: AMS_TZ,
    hour: "2-digit",
    hour12: false,
  });
  const targets = [0, 6, 12, 18];
  return targets.map((h) => {
    const slot = slots.find(
      (s) => Number.parseInt(hourFmt.format(new Date(s.time)), 10) === h,
    );
    return slot ? fmt.format(new Date(slot.time)) : "—";
  });
}

function peakLabel(slot: HourlySlot): string {
  const mm = slot.precipitation_mm ?? 0;
  const fmt = new Intl.DateTimeFormat("nl-NL", {
    timeZone: AMS_TZ,
    hour: "2-digit",
    minute: "2-digit",
    hour12: false,
  });
  return `${mm.toFixed(1)} mm bij ${fmt.format(new Date(slot.time))}`;
}
