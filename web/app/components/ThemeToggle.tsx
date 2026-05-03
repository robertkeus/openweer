/**
 * ThemeToggle — 3-state cycle button (light → dark → system → …).
 *
 * Two visual variants:
 *  - "header": compact, fits inline beside header nav links.
 *  - "floating": 44×44 floating-btn, designed for the map shell.
 *
 * The icon reflects the *current* mode; the aria-label announces the *next*
 * state so screen-reader users know what clicking does.
 */

import { useTheme, type ThemeMode } from "~/lib/theme";

const NEXT_LABEL: Record<ThemeMode, string> = {
  light: "Schakel naar donkere modus",
  dark: "Schakel naar systeem-modus",
  system: "Schakel naar lichte modus",
};

const CURRENT_LABEL: Record<ThemeMode, string> = {
  light: "Modus: licht",
  dark: "Modus: donker",
  system: "Modus: systeem",
};

interface Props {
  variant?: "header" | "floating";
}

export function ThemeToggle({ variant = "header" }: Props) {
  const { mode, cycle } = useTheme();

  const className =
    variant === "floating"
      ? "floating-btn text-[--color-ink-700]"
      : "grid place-items-center h-9 w-9 rounded-full text-[--color-ink-700] hover:text-[--color-accent-600] hover:bg-[--color-ink-100] transition-colors focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-[--color-accent-500]";

  return (
    <button
      type="button"
      onClick={cycle}
      aria-label={NEXT_LABEL[mode]}
      title={`${CURRENT_LABEL[mode]} — ${NEXT_LABEL[mode].toLowerCase()}`}
      data-testid="theme-toggle"
      data-theme-mode={mode}
      className={className}
    >
      <span aria-hidden="true">
        {mode === "light" ? (
          <SunIcon />
        ) : mode === "dark" ? (
          <MoonIcon />
        ) : (
          <SystemIcon />
        )}
      </span>
    </button>
  );
}

function SunIcon() {
  return (
    <svg
      viewBox="0 0 24 24"
      width="20"
      height="20"
      fill="none"
      stroke="currentColor"
      strokeWidth="1.8"
      strokeLinecap="round"
      strokeLinejoin="round"
    >
      <circle cx="12" cy="12" r="4" />
      <path d="M12 2v2M12 20v2M4.93 4.93l1.41 1.41M17.66 17.66l1.41 1.41M2 12h2M20 12h2M4.93 19.07l1.41-1.41M17.66 6.34l1.41-1.41" />
    </svg>
  );
}

function MoonIcon() {
  return (
    <svg
      viewBox="0 0 24 24"
      width="20"
      height="20"
      fill="none"
      stroke="currentColor"
      strokeWidth="1.8"
      strokeLinecap="round"
      strokeLinejoin="round"
    >
      <path d="M21 12.79A9 9 0 1 1 11.21 3a7 7 0 0 0 9.79 9.79z" />
    </svg>
  );
}

function SystemIcon() {
  return (
    <svg
      viewBox="0 0 24 24"
      width="20"
      height="20"
      fill="none"
      stroke="currentColor"
      strokeWidth="1.8"
      strokeLinecap="round"
      strokeLinejoin="round"
    >
      <rect x="3" y="4" width="18" height="13" rx="2" />
      <path d="M9 21h6M12 17v4" />
    </svg>
  );
}
