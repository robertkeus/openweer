/**
 * 2-hour minute-by-minute rain bar chart. SVG, no chart library — keeps the
 * bundle tight and the rendering 100% controllable.
 */

import { useState, type ReactNode } from "react";
import type { RainSample } from "~/lib/api";
import { formatHm, formatMmPerHour, rainVerdict } from "~/lib/format";
import { rainColor } from "~/lib/rain-color";

interface Props {
  samples: readonly RainSample[];
  /** Total height in CSS pixels. */
  height?: number;
}

// Gap between bars in viewBox units. Stays small relative to a typical bar
// (~3.5 units wide for 24 5-min samples spanning width=100) so bars dominate
// and a passing shower reads as a chunky cluster rather than thin pinstripes.
const BAR_GAP = 0.4;

/** RainGraph + RainSummary are the "next 2 hours" surface. With the +24 h
 *  HARMONIE extension landing in `/api/rain`, the response now carries
 *  ~136 samples. Squeezing all of them into the chart's narrow viewBox
 *  collapses each bar to a negative width and the chart goes blank —
 *  and the summary's peak/total stop describing what the chart shows.
 *  Cap both to the radar-nowcast window. */
const MAX_MINUTES_AHEAD = 120;

function within2h(samples: readonly RainSample[]): readonly RainSample[] {
  return samples.filter((s) => s.minutes_ahead <= MAX_MINUTES_AHEAD);
}

function maxBound(samples: readonly RainSample[]): number {
  const observed = Math.max(...samples.map((s) => s.mm_per_h), 0);
  // Always show at least 2 mm/h on the y-axis so dry forecasts have visual context.
  return Math.max(2.0, Math.ceil(observed * 1.2));
}

export function RainGraph({ samples: input, height = 140 }: Props) {
  // Hook must run unconditionally — keep above any early returns (rules-of-hooks).
  const [hovered, setHovered] = useState<number | null>(null);

  const samples = within2h(input);
  if (!samples.length) return null;

  const allDry = samples.every((s) => s.mm_per_h < 0.1);
  if (allDry) {
    return (
      <figure className="w-full">
        <div
          role="img"
          aria-label="Geen neerslag verwacht in de komende 2 uur"
          className="grid place-items-center gap-3 text-center text-[--color-ink-700]"
          style={{ height: `${height}px` }}
        >
          <SunCloudIcon className="h-10 w-10 text-[--color-accent-600]" />
          <p className="text-sm font-medium">Geen neerslag verwacht</p>
        </div>
        <figcaption className="mt-2 flex items-center justify-between text-xs text-[--color-ink-700]">
          <span>{formatHm(samples[0].valid_at)}</span>
          <span>nu &nbsp;→&nbsp; +2&nbsp;uur</span>
          <span>{formatHm(samples[samples.length - 1].valid_at)}</span>
        </figcaption>
      </figure>
    );
  }

  const yMax = maxBound(samples);
  const width = 100; // viewBox width — scales to container.
  const barWidth = (width - BAR_GAP * (samples.length - 1)) / samples.length;

  const titleId = `rain-graph-title-${samples[0].valid_at}`;
  const descId = `rain-graph-desc-${samples[0].valid_at}`;
  const totalMm = (samples.reduce((s, x) => s + x.mm_per_h, 0) / 12).toFixed(1);

  const hoveredSample = hovered !== null ? samples[hovered] : null;

  return (
    <figure className="w-full">
      <svg
        viewBox={`0 0 ${width} ${height}`}
        preserveAspectRatio="none"
        role="img"
        aria-labelledby={titleId}
        aria-describedby={descId}
        className="w-full h-[140px]"
        onPointerLeave={() => setHovered(null)}
      >
        <title id={titleId}>Neerslag de komende 2 uur</title>
        <desc id={descId}>
          Verwachte neerslag in millimeter per uur, in stappen van 5 minuten.
          Totaal naar verwachting {totalMm} mm.
        </desc>

        {/* Bars + invisible hit areas spanning the full chart height so
            very thin (near-zero) bars are still hoverable. */}
        {samples.map((s, i) => {
          const x = i * (barWidth + BAR_GAP);
          const h = Math.max(
            1,
            (Math.min(s.mm_per_h, yMax) / yMax) * (height - 18),
          );
          const y = height - h - 4;
          const isHovered = hovered === i;
          return (
            <g key={s.valid_at}>
              <rect
                data-rain-bar=""
                x={x}
                y={y}
                width={barWidth}
                height={h}
                fill={rainColor(s.mm_per_h)}
                rx="0.4"
                opacity={hovered !== null && !isHovered ? 0.55 : 1}
              />
              <rect
                x={x - BAR_GAP / 2}
                y={0}
                width={barWidth + BAR_GAP}
                height={height}
                fill="transparent"
                className="cursor-crosshair focus:outline-none"
                tabIndex={0}
                role="button"
                aria-label={`${formatHm(s.valid_at)}: ${formatMmPerHour(s.mm_per_h)}`}
                onPointerEnter={() => setHovered(i)}
                onFocus={() => setHovered(i)}
                onBlur={() => setHovered(null)}
              >
                <title>{`${formatHm(s.valid_at)} — ${formatMmPerHour(s.mm_per_h)}`}</title>
              </rect>
            </g>
          );
        })}
      </svg>
      <figcaption
        className="mt-2 flex items-center justify-between text-xs text-[--color-ink-700] tabular-nums min-h-[1rem]"
        aria-live="polite"
      >
        {hoveredSample ? (
          <span className="text-[--color-ink-900] font-medium">
            {formatHm(hoveredSample.valid_at)}
            <span className="mx-2 text-[--color-ink-700]">·</span>
            {formatMmPerHour(hoveredSample.mm_per_h)}
          </span>
        ) : (
          <>
            <span>{formatHm(samples[0].valid_at)}</span>
            <span>nu &nbsp;→&nbsp; +2&nbsp;uur</span>
            <span>{formatHm(samples[samples.length - 1].valid_at)}</span>
          </>
        )}
      </figcaption>
    </figure>
  );
}

interface SummaryProps {
  samples: readonly RainSample[];
  /** Optional slot rendered next to the "Verwachting" eyebrow (e.g. AI trigger). */
  action?: ReactNode;
}

export function RainSummary({ samples: input, action }: SummaryProps) {
  const samples = within2h(input);
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
    <div className="grid grid-cols-1 sm:grid-cols-2 gap-3 sm:gap-4 text-sm">
      <div className="sm:col-span-2">
        <div className="flex items-center justify-between gap-3">
          <p className="text-[--color-ink-700] uppercase text-xs tracking-wider">
            Verwachting
          </p>
          {action}
        </div>
        <p className="text-base font-medium text-[--color-ink-900]">
          {headline}
        </p>
      </div>
      <div>
        <p className="text-[--color-ink-700] uppercase text-xs tracking-wider">
          Piekintensiteit
        </p>
        <p className="text-base font-medium tabular-nums">
          {formatMmPerHour(peak.mm_per_h)}{" "}
          <span className="text-[--color-ink-700]">
            ({formatHm(peak.valid_at)})
          </span>
        </p>
      </div>
      <div>
        <p className="text-[--color-ink-700] uppercase text-xs tracking-wider">
          Totaal
        </p>
        <p className="text-base font-medium tabular-nums">
          {totalMm.toFixed(1)} mm
        </p>
      </div>
    </div>
  );
}

function SunCloudIcon(props: React.SVGProps<SVGSVGElement>) {
  // Soft cumulus + warm sun. Uses gradients so it reads as a real cloud
  // rather than a stylized pictogram, but still scales cleanly to any size.
  const gradId = `cloud-fill-${Math.random().toString(36).slice(2, 8)}`;
  const sunId = `sun-fill-${Math.random().toString(36).slice(2, 8)}`;
  const haloId = `sun-halo-${Math.random().toString(36).slice(2, 8)}`;
  return (
    <svg viewBox="0 0 64 56" fill="none" {...props}>
      <defs>
        <radialGradient
          id={haloId}
          cx="44"
          cy="18"
          r="22"
          gradientUnits="userSpaceOnUse"
        >
          <stop
            offset="0"
            stopColor="var(--color-sun-400)"
            stopOpacity="0.45"
          />
          <stop offset="1" stopColor="var(--color-sun-400)" stopOpacity="0" />
        </radialGradient>
        <radialGradient
          id={sunId}
          cx="42"
          cy="16"
          r="9"
          gradientUnits="userSpaceOnUse"
        >
          <stop offset="0" stopColor="oklch(0.95 0.14 85)" />
          <stop offset="1" stopColor="var(--color-sun-400)" />
        </radialGradient>
        <linearGradient id={gradId} x1="0" y1="0" x2="0" y2="1">
          <stop offset="0" stopColor="oklch(1 0 0)" stopOpacity="0.95" />
          <stop
            offset="1"
            stopColor="oklch(0.86 0.012 250)"
            stopOpacity="0.95"
          />
        </linearGradient>
      </defs>

      {/* Soft warm halo behind the sun. */}
      <circle cx="44" cy="18" r="22" fill={`url(#${haloId})`} />

      {/* Sun disc with a gentle highlight gradient. */}
      <circle cx="42" cy="16" r="8" fill={`url(#${sunId})`} />
      <g
        stroke="var(--color-sun-400)"
        strokeWidth="1.8"
        strokeLinecap="round"
        opacity="0.85"
      >
        <line x1="42" y1="2" x2="42" y2="5.5" />
        <line x1="56.5" y1="16" x2="60" y2="16" />
        <line x1="52.5" y1="6" x2="55" y2="3.5" />
        <line x1="52.5" y1="26" x2="55" y2="28.5" />
      </g>

      {/* Soft drop shadow under the cloud. */}
      <ellipse
        cx="28"
        cy="46"
        rx="20"
        ry="2.4"
        fill="oklch(0.16 0.02 250)"
        opacity="0.18"
      />

      {/* Cumulus body — overlapping lobes give a fluffy, real-cloud silhouette. */}
      <g
        fill={`url(#${gradId})`}
        stroke="oklch(0.78 0.012 250)"
        strokeWidth="0.8"
        strokeLinejoin="round"
      >
        <path d="M12 42c-4.4 0-8-3.4-8-7.6 0-3.7 2.7-6.8 6.4-7.5a9 9 0 0117 0.5 6.5 6.5 0 014 11.6 5.5 5.5 0 01-4.4 2.9 6 6 0 01-4.7 0z" />
      </g>
      {/* Highlight lobes that catch the light from the sun's direction. */}
      <g fill="oklch(1 0 0)" opacity="0.55">
        <ellipse cx="14" cy="31" rx="4" ry="2.2" />
        <ellipse cx="22" cy="27.5" rx="5" ry="2.4" />
      </g>
    </svg>
  );
}
