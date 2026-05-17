import type { DailyForecast, HourlySlot } from "~/lib/api";
import { HourCell } from "./HourCell";
import {
  formatHHmmFromIso,
  formatHourLabel,
  hourOfSlot,
  parseHourFromIso,
  todayIso,
  wmoToCondition,
} from "./util";

interface Props {
  slots: readonly HourlySlot[];
  day: DailyForecast;
  pending: boolean;
}

type Item =
  | { kind: "hour"; slot: HourlySlot; index: number }
  | { kind: "sun"; symbol: "sunrise" | "sunset"; label: string; key: string };

const NOW = () => new Date();

/** Horizontal scroll of hour cells with inline sunrise/sunset markers. */
export function HourlyStrip({ slots, day, pending }: Props) {
  const isToday = day.date === todayIso();
  const currentHour = isToday ? hourOfNow() : null;
  const sunriseHour = parseHourFromIso(day.sunrise);
  const sunsetHour = parseHourFromIso(day.sunset);

  if (pending && slots.length === 0) {
    return (
      <section aria-labelledby="day-detail-hourly">
        <h3
          id="day-detail-hourly"
          className="text-[--color-ink-700] uppercase text-xs tracking-wider"
        >
          Per uur
        </h3>
        <ul className="mt-2 flex gap-2 overflow-x-auto rounded-2xl border border-[--color-border] px-3 py-3">
          {Array.from({ length: 10 }, (_, i) => (
            <li
              key={i}
              className="flex-none w-14 flex flex-col items-center gap-1.5 motion-safe:animate-pulse"
            >
              <span className="h-3 w-7 rounded bg-[--color-border]" />
              <span className="h-7 w-7 rounded-full bg-[--color-border]" />
              <span className="h-3 w-6 rounded bg-[--color-border]/60" />
              <span className="h-4 w-7 rounded bg-[--color-border]" />
            </li>
          ))}
        </ul>
      </section>
    );
  }

  const items: Item[] = [];
  slots.forEach((slot, index) => {
    items.push({ kind: "hour", slot, index });
    const hour = hourOfSlot(slot);
    if (sunriseHour !== null && sunriseHour === hour) {
      const label = formatHHmmFromIso(day.sunrise);
      if (label) {
        items.push({
          kind: "sun",
          symbol: "sunrise",
          label,
          key: `sunrise-${slot.time}`,
        });
      }
    }
    if (sunsetHour !== null && sunsetHour === hour) {
      const label = formatHHmmFromIso(day.sunset);
      if (label) {
        items.push({
          kind: "sun",
          symbol: "sunset",
          label,
          key: `sunset-${slot.time}`,
        });
      }
    }
  });

  return (
    <section aria-labelledby="day-detail-hourly">
      <h3
        id="day-detail-hourly"
        className="text-[--color-ink-700] uppercase text-xs tracking-wider"
      >
        Per uur
      </h3>
      <ul className="thin-scroll mt-2 flex gap-2 overflow-x-auto rounded-2xl border border-[--color-border] px-3 py-3 snap-x scroll-px-3">
        {items.map((item) => {
          if (item.kind === "hour") {
            const slot = item.slot;
            const isCurrent =
              isToday &&
              currentHour !== null &&
              hourOfSlot(slot) === currentHour;
            return (
              <div key={slot.time} className="snap-start">
                <HourCell
                  label={isCurrent ? "Nu" : formatHourLabel(slot)}
                  kind={wmoToCondition(slot.weather_code)}
                  temperatureC={slot.temperature_c}
                  precipitationProbabilityPct={slot.precipitation_probability_pct}
                  isHighlighted={isCurrent}
                />
              </div>
            );
          }
          return (
            <SunCell
              key={item.key}
              symbol={item.symbol}
              label={item.label}
            />
          );
        })}
      </ul>
    </section>
  );
}

function SunCell({
  symbol,
  label,
}: {
  symbol: "sunrise" | "sunset";
  label: string;
}) {
  const a11y =
    symbol === "sunrise" ? `Zonsopgang ${label}` : `Zonsondergang ${label}`;
  return (
    <div
      role="listitem"
      aria-label={a11y}
      className="flex-none w-14 flex flex-col items-center gap-1.5 select-none snap-start"
    >
      <span className="text-xs font-medium text-[--color-ink-700]">
        {symbol === "sunrise" ? "Op" : "Onder"}
      </span>
      <SunSvg
        kind={symbol}
        className="h-7 w-7 text-[--color-sun-400]"
        aria-hidden="true"
      />
      <span className="h-3" />
      <span className="text-sm font-semibold tabular-nums text-[--color-ink-900]">
        {label}
      </span>
    </div>
  );
}

function SunSvg({
  kind,
  className,
  ...rest
}: {
  kind: "sunrise" | "sunset";
  className?: string;
} & React.SVGProps<SVGSVGElement>) {
  return (
    <svg
      viewBox="0 0 24 24"
      fill="none"
      stroke="currentColor"
      strokeWidth="1.75"
      strokeLinecap="round"
      strokeLinejoin="round"
      className={className}
      {...rest}
    >
      <circle cx="12" cy="14" r="3.4" fill="currentColor" stroke="none" />
      <line x1="4" y1="20" x2="20" y2="20" />
      {kind === "sunrise" ? (
        <>
          <line x1="12" y1="3.5" x2="12" y2="7" />
          <line x1="9.5" y1="5.5" x2="11" y2="7" />
          <line x1="14.5" y1="5.5" x2="13" y2="7" />
        </>
      ) : (
        <>
          <line x1="12" y1="7" x2="12" y2="3.5" />
          <line x1="10" y1="5" x2="12" y2="7" />
          <line x1="14" y1="5" x2="12" y2="7" />
        </>
      )}
    </svg>
  );
}

function hourOfNow(): number {
  const fmt = new Intl.DateTimeFormat("nl-NL", {
    timeZone: "Europe/Amsterdam",
    hour: "2-digit",
    hour12: false,
  });
  return Number.parseInt(fmt.format(NOW()), 10);
}
