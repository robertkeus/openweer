/**
 * Server-safe wrapper for the client-only RadarMap.
 *
 * On the server it renders a skeleton (so there's something on first paint
 * for SEO + LCP). After hydration, it dynamically imports RadarMap and
 * mounts it in place.
 */

import { useEffect, useState } from "react";
import type { Frame } from "~/lib/api";

interface Props {
  frames: Frame[];
  currentIndex: number;
  center?: { lat: number; lon: number };
  onLocationPick?: (loc: { name: string; lat: number; lon: number }) => void;
  className?: string;
}

export function MapMount(props: Props) {
  const [Component, setComponent] = useState<React.ComponentType<Props> | null>(
    null,
  );

  useEffect(() => {
    let cancelled = false;
    import("./RadarMap.client").then((mod) => {
      if (!cancelled) setComponent(() => mod.RadarMap);
    });
    return () => {
      cancelled = true;
    };
  }, []);

  if (!Component) {
    return (
      <MapSkeleton
        frameCount={props.frames.length}
        className={props.className}
      />
    );
  }
  return <Component {...props} />;
}

function MapSkeleton({
  frameCount,
  className = "absolute inset-0",
}: {
  frameCount: number;
  className?: string;
}) {
  return (
    <div
      role="status"
      aria-label="Kaart wordt geladen"
      className={`${className} grid place-items-center text-sm text-[--color-ink-500] bg-gradient-to-br from-sky-50 via-white to-white`}
    >
      <div className="text-center space-y-2">
        <SpinnerIcon className="mx-auto h-6 w-6 animate-spin text-[--color-accent-600]" />
        <p>
          Kaart laadt…{" "}
          {frameCount > 0 ? (
            <span className="text-[--color-ink-500]">
              ({frameCount} frames beschikbaar)
            </span>
          ) : null}
        </p>
      </div>
    </div>
  );
}

function SpinnerIcon(props: React.SVGProps<SVGSVGElement>) {
  return (
    <svg viewBox="0 0 24 24" fill="none" {...props}>
      <circle cx="12" cy="12" r="10" stroke="currentColor" strokeWidth="2" opacity="0.2" />
      <path
        d="M22 12a10 10 0 00-10-10"
        stroke="currentColor"
        strokeWidth="2"
        strokeLinecap="round"
      />
    </svg>
  );
}
