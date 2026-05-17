/**
 * Inline SVG weather glyph driven by a `ConditionKind`. Uses CSS variables
 * so it adapts to the light/dark palette automatically.
 */

import type { ConditionKind } from "~/lib/api";

export function ConditionGlyph({
  kind,
  className,
}: {
  kind: ConditionKind;
  className?: string;
}) {
  // Unique ids per render so multiple glyphs on a page don't clash.
  const id = (suffix: string) =>
    `${suffix}-${Math.random().toString(36).slice(2, 8)}`;
  const sunGrad = id("sun");
  const cloudGrad = id("cloud");
  return (
    <svg
      viewBox="0 0 64 64"
      fill="none"
      className={className}
      aria-hidden="true"
    >
      <defs>
        <radialGradient
          id={sunGrad}
          cx="32"
          cy="28"
          r="14"
          gradientUnits="userSpaceOnUse"
        >
          <stop offset="0" stopColor="oklch(0.95 0.14 85)" />
          <stop offset="1" stopColor="var(--color-sun-400)" />
        </radialGradient>
        <linearGradient id={cloudGrad} x1="0" y1="0" x2="0" y2="1">
          <stop offset="0" stopColor="oklch(1 0 0)" stopOpacity="0.95" />
          <stop
            offset="1"
            stopColor="oklch(0.86 0.012 250)"
            stopOpacity="0.95"
          />
        </linearGradient>
      </defs>

      {(kind === "clear" || kind === "partly-cloudy") && (
        <>
          <circle cx="32" cy="28" r="11" fill={`url(#${sunGrad})`} />
          <g
            stroke="var(--color-sun-400)"
            strokeWidth="2"
            strokeLinecap="round"
            opacity="0.85"
          >
            <line x1="32" y1="6" x2="32" y2="11" />
            <line x1="50" y1="28" x2="55" y2="28" />
            <line x1="9" y1="28" x2="14" y2="28" />
            <line x1="46" y1="14" x2="50" y2="10" />
            <line x1="18" y1="14" x2="14" y2="10" />
          </g>
        </>
      )}
      {(kind === "partly-cloudy" ||
        kind === "cloudy" ||
        kind === "rain" ||
        kind === "drizzle" ||
        kind === "thunder" ||
        kind === "snow" ||
        kind === "fog" ||
        kind === "unknown") && (
        <g
          fill={`url(#${cloudGrad})`}
          stroke="oklch(0.78 0.012 250)"
          strokeWidth="0.8"
          strokeLinejoin="round"
        >
          <path d="M14 50c-5 0-9-4-9-8.6 0-4.2 3-7.7 7.2-8.5a10 10 0 0119.2 0.6 7.5 7.5 0 014.6 13.2 6 6 0 01-5 3.3 7 7 0 01-5.4 0z" />
        </g>
      )}
      {kind === "rain" && (
        <g
          stroke="var(--color-accent-600)"
          strokeWidth="2"
          strokeLinecap="round"
        >
          <line x1="20" y1="54" x2="18" y2="60" />
          <line x1="28" y1="54" x2="26" y2="60" />
          <line x1="36" y1="54" x2="34" y2="60" />
        </g>
      )}
      {kind === "drizzle" && (
        <g
          stroke="var(--color-accent-500)"
          strokeWidth="1.5"
          strokeLinecap="round"
        >
          <line x1="20" y1="54" x2="19" y2="58" />
          <line x1="28" y1="54" x2="27" y2="58" />
          <line x1="36" y1="54" x2="35" y2="58" />
        </g>
      )}
      {kind === "snow" && (
        <g fill="var(--color-ink-700)">
          <circle cx="20" cy="56" r="1.4" />
          <circle cx="28" cy="58" r="1.4" />
          <circle cx="36" cy="56" r="1.4" />
        </g>
      )}
      {kind === "thunder" && (
        <path
          d="M30 50l-3 7h4l-2 6 7-9h-4l2-4z"
          fill="var(--color-sun-400)"
          stroke="oklch(0.55 0.18 75)"
          strokeWidth="0.8"
          strokeLinejoin="round"
        />
      )}
      {kind === "fog" && (
        <g
          stroke="var(--color-ink-500)"
          strokeWidth="1.6"
          strokeLinecap="round"
        >
          <line x1="10" y1="56" x2="42" y2="56" />
          <line x1="14" y1="60" x2="46" y2="60" />
        </g>
      )}
    </svg>
  );
}
