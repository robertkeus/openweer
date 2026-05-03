/**
 * Theme module — light/dark/system toggle with localStorage persistence.
 *
 * No React context: there's only ever one toggle in the header, and the
 * `<html class="dark">` mutation is observed directly by anything that
 * needs to react (e.g. RadarMap basemap switching).
 *
 * The companion anti-FOUC script in root.tsx duplicates the resolution
 * logic so the correct class lands on `<html>` *before* hydration.
 */

import { useEffect, useState } from "react";

export type ThemeMode = "light" | "dark" | "system";
export type ResolvedTheme = "light" | "dark";

export const STORAGE_KEY = "openweer-theme";
const DARK_QUERY = "(prefers-color-scheme: dark)";

export function getStoredTheme(): ThemeMode {
  if (typeof window === "undefined") return "system";
  const v = window.localStorage.getItem(STORAGE_KEY);
  return v === "light" || v === "dark" || v === "system" ? v : "system";
}

export function setStoredTheme(mode: ThemeMode): void {
  if (typeof window === "undefined") return;
  window.localStorage.setItem(STORAGE_KEY, mode);
}

export function resolveTheme(
  mode: ThemeMode,
  systemPrefersDark = typeof window !== "undefined" &&
    window.matchMedia(DARK_QUERY).matches,
): ResolvedTheme {
  if (mode === "system") return systemPrefersDark ? "dark" : "light";
  return mode;
}

export function applyTheme(resolved: ResolvedTheme): void {
  if (typeof document === "undefined") return;
  document.documentElement.classList.toggle("dark", resolved === "dark");
}

/**
 * Reactive hook for the toggle UI. Owns persistence + live response to
 * OS-level changes when in `system` mode.
 */
export function useTheme(): {
  mode: ThemeMode;
  resolved: ResolvedTheme;
  setMode: (m: ThemeMode) => void;
  cycle: () => void;
} {
  const [mode, setModeState] = useState<ThemeMode>("system");
  const [resolved, setResolved] = useState<ResolvedTheme>("light");

  // Hydrate from storage on mount (avoids SSR mismatch).
  useEffect(() => {
    const stored = getStoredTheme();
    setModeState(stored);
    setResolved(resolveTheme(stored));
  }, []);

  // Track OS-level changes when following the system preference.
  useEffect(() => {
    if (mode !== "system") return;
    const mq = window.matchMedia(DARK_QUERY);
    const onChange = () => {
      const next: ResolvedTheme = mq.matches ? "dark" : "light";
      setResolved(next);
      applyTheme(next);
    };
    mq.addEventListener("change", onChange);
    return () => mq.removeEventListener("change", onChange);
  }, [mode]);

  function setMode(next: ThemeMode) {
    setModeState(next);
    setStoredTheme(next);
    const r = resolveTheme(next);
    setResolved(r);
    applyTheme(r);
  }

  function cycle() {
    setMode(mode === "light" ? "dark" : mode === "dark" ? "system" : "light");
  }

  return { mode, resolved, setMode, cycle };
}

/**
 * Inline script source — injected into <head> by root.tsx as
 * `<script dangerouslySetInnerHTML={{ __html: ANTI_FOUC_SCRIPT }} />`.
 * Runs synchronously before first paint, so the `dark` class is set before
 * the browser ever shows light-mode pixels.
 */
export const ANTI_FOUC_SCRIPT = `(function(){try{var s=localStorage.getItem('${STORAGE_KEY}');var m=(s==='light'||s==='dark'||s==='system')?s:'system';var dark=m==='dark'||(m==='system'&&window.matchMedia('${DARK_QUERY}').matches);document.documentElement.classList.toggle('dark',dark);}catch(e){}})();`;
