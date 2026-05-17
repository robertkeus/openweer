/**
 * Rain-intensity color stops shared by the radar nowcast chart (`RainGraph`)
 * and the hourly chart (`HourlyRainChart`). Mirrors the backend colormap so
 * UI bars match the tile palette pixel-for-pixel.
 */
export function rainColor(mmPerHour: number): string {
  if (mmPerHour < 0.1) return "var(--color-no-rain)";
  if (mmPerHour < 0.5) return "rgb(155,195,241)";
  if (mmPerHour < 1.0) return "rgb(92,142,232)";
  if (mmPerHour < 2.0) return "rgb(31,93,208)";
  if (mmPerHour < 5.0) return "rgb(245,213,45)";
  if (mmPerHour < 10.0) return "rgb(245,159,45)";
  if (mmPerHour < 20.0) return "rgb(230,53,61)";
  if (mmPerHour < 50.0) return "rgb(163,21,31)";
  return "rgb(192,38,211)";
}
