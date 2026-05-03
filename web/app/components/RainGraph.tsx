/**
 * 2-hour minute-by-minute rain bar chart. SVG, no chart library — keeps the
 * bundle tight and the rendering 100% controllable.
 */

import type { RainSample } from "~/lib/api";
import { formatHm, formatMmPerHour, rainVerdict } from "~/lib/format";

interface Props {
  samples: readonly RainSample[];
  /** Total height in CSS pixels. */
  height?: number;
}

const BAR_GAP = 2;
const Y_LABELS_MM = [0.5, 2.0, 5.0, 10.0];

function maxBound(samples: readonly RainSample[]): number {
  const observed = Math.max(...samples.map((s) => s.mm_per_h), 0);
  // Always show at least 2 mm/h on the y-axis so dry forecasts have visual context.
  return Math.max(2.0, Math.ceil(observed * 1.2));
}

function colorFor(mm: number): string {
  // Mirrors the backend colormap stops at 0.1 / 0.5 / 1 / 2 / 5 / 10 / 20 / 50.
  if (mm < 0.1) return "rgb(229,231,235)"; // gray-200
  if (mm < 0.5) return "rgb(155,195,241)";
  if (mm < 1.0) return "rgb(92,142,232)";
  if (mm < 2.0) return "rgb(31,93,208)";
  if (mm < 5.0) return "rgb(45,184,74)";
  if (mm < 10.0) return "rgb(245,213,45)";
  if (mm < 20.0) return "rgb(245,159,45)";
  if (mm < 50.0) return "rgb(230,53,61)";
  return "rgb(192,38,211)";
}

export function RainGraph({ samples, height = 140 }: Props) {
  if (!samples.length) return null;

  const yMax = maxBound(samples);
  const width = 100; // viewBox width — scales to container.
  const barWidth = (width - BAR_GAP * (samples.length - 1)) / samples.length;

  const titleId = `rain-graph-title-${samples[0].valid_at}`;
  const descId = `rain-graph-desc-${samples[0].valid_at}`;
  const totalMm = (samples.reduce((s, x) => s + x.mm_per_h, 0) / 12).toFixed(1);

  return (
    <figure className="w-full">
      <svg
        viewBox={`0 0 ${width} ${height}`}
        preserveAspectRatio="none"
        role="img"
        aria-labelledby={titleId}
        aria-describedby={descId}
        className="w-full h-[140px]"
      >
        <title id={titleId}>Neerslag de komende 2 uur</title>
        <desc id={descId}>
          Verwachte neerslag in millimeter per uur, in stappen van 5 minuten.
          Totaal naar verwachting {totalMm} mm.
        </desc>

        {/* Y-axis grid + labels. */}
        {Y_LABELS_MM.filter((v) => v < yMax * 1.1).map((value) => {
          const y = height - (value / yMax) * (height - 18) - 4;
          return (
            <g key={value}>
              <line
                x1={0}
                x2={width}
                y1={y}
                y2={y}
                stroke="currentColor"
                strokeOpacity="0.08"
                strokeWidth="0.4"
                vectorEffect="non-scaling-stroke"
              />
              <text
                x={0.5}
                y={y - 1}
                fontSize="3.4"
                fill="currentColor"
                opacity="0.45"
              >
                {value} mm/u
              </text>
            </g>
          );
        })}

        {/* Bars. */}
        {samples.map((s, i) => {
          const x = i * (barWidth + BAR_GAP);
          const h = Math.max(1, (Math.min(s.mm_per_h, yMax) / yMax) * (height - 18));
          const y = height - h - 4;
          return (
            <rect
              key={s.valid_at}
              x={x}
              y={y}
              width={barWidth}
              height={h}
              fill={colorFor(s.mm_per_h)}
              rx="0.4"
            />
          );
        })}
      </svg>
      <figcaption className="mt-2 flex items-center justify-between text-xs text-[--color-ink-500]">
        <span>{formatHm(samples[0].valid_at)}</span>
        <span>nu &nbsp;→&nbsp; +2&nbsp;uur</span>
        <span>{formatHm(samples[samples.length - 1].valid_at)}</span>
      </figcaption>
    </figure>
  );
}

interface SummaryProps {
  samples: readonly RainSample[];
}

export function RainSummary({ samples }: SummaryProps) {
  if (!samples.length) return null;
  const peak = samples.reduce((a, b) => (a.mm_per_h > b.mm_per_h ? a : b));
  const totalMm = samples.reduce((s, x) => s + x.mm_per_h, 0) / 12;
  const verdict = rainVerdict(peak.mm_per_h);

  const headline =
    verdict === "droog"
      ? "Het blijft droog de komende 2 uur."
      : verdict === "licht"
        ? "Lichte regen verwacht."
        : verdict === "matig"
          ? "Matige regen op komst."
          : "Zware buien verwacht.";

  return (
    <div className="grid grid-cols-2 gap-4 text-sm">
      <div>
        <p className="text-[--color-ink-500] uppercase text-xs tracking-wider">
          Verwachting
        </p>
        <p className="text-base font-medium text-[--color-ink-900] dark:text-[--color-ink-50]">
          {headline}
        </p>
      </div>
      <div>
        <p className="text-[--color-ink-500] uppercase text-xs tracking-wider">
          Piekintensiteit
        </p>
        <p className="text-base font-medium tabular-nums">
          {formatMmPerHour(peak.mm_per_h)}{" "}
          <span className="text-[--color-ink-500]">
            ({formatHm(peak.valid_at)})
          </span>
        </p>
      </div>
      <div className="col-span-2">
        <p className="text-[--color-ink-500] uppercase text-xs tracking-wider">
          Totale verwachte neerslag
        </p>
        <p className="text-base font-medium tabular-nums">
          {totalMm.toFixed(1)} mm
        </p>
      </div>
    </div>
  );
}
