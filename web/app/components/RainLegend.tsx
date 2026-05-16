/** Compact horizontal color scale for the rain intensity colormap. */
export function RainLegend() {
  return (
    <div className="flex items-center gap-2 text-[11px] text-[--color-ink-700] tabular-nums">
      <span className="uppercase tracking-wider">Intensiteit</span>
      <div className="flex-1 h-2 rounded-full overflow-hidden flex">
        {STOPS.map(([color]) => (
          <span
            key={color}
            aria-hidden="true"
            className="flex-1 h-full"
            style={{ background: color }}
          />
        ))}
      </div>
      <span>0,1</span>
      <span>1</span>
      <span>5</span>
      <span>20+ mm/u</span>
    </div>
  );
}

const STOPS: ReadonlyArray<readonly [string]> = [
  ["rgb(155,195,241)"],
  ["rgb(92,142,232)"],
  ["rgb(31,93,208)"],
  ["rgb(245,213,45)"],
  ["rgb(245,159,45)"],
  ["rgb(230,53,61)"],
  ["rgb(163,21,31)"],
  ["rgb(192,38,211)"],
];
