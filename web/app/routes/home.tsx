import { useCallback, useEffect, useState } from "react";
import type { Route } from "./+types/home";
import { ApiError, api, type RainResponse } from "~/lib/api";
import { LocationBar, type SelectedLocation } from "~/components/LocationBar";
import { MapMount } from "~/components/MapMount";
import { RainForecastCard } from "~/components/RainForecastCard";
import { SiteFooter } from "~/components/SiteFooter";
import { SiteHeader } from "~/components/SiteHeader";
import { WeatherNowCard } from "~/components/WeatherNowCard";
import { defaultPlayableFrames } from "~/lib/frames";
import { DEFAULT_LOCATION } from "~/lib/locations";

export function meta() {
  return [
    { title: "OpenWeer — actueel weerbeeld voor Nederland" },
    {
      name: "description",
      content:
        "Live regenradar en neerslagverwachting voor heel Nederland, op basis van KNMI open data.",
    },
  ];
}

export async function loader() {
  const [frames, rain] = await Promise.allSettled([
    api.frames(),
    api.rain(DEFAULT_LOCATION.lat, DEFAULT_LOCATION.lon),
  ]);

  return {
    frames:
      frames.status === "fulfilled"
        ? frames.value
        : { frames: [], generated_at: "" },
    framesErrored: frames.status === "rejected",
    rain: rain.status === "fulfilled" ? rain.value : null,
    rainError:
      rain.status === "rejected" && rain.reason instanceof ApiError
        ? rain.reason.status === 503
          ? "Nog geen radardata beschikbaar — we proberen het automatisch opnieuw."
          : "De voorspelling is even niet bereikbaar."
        : undefined,
  };
}

export default function Home({ loaderData }: Route.ComponentProps) {
  const { frames, framesErrored, rain: initialRain, rainError } = loaderData;
  const playable = defaultPlayableFrames(frames.frames);

  const [location, setLocation] = useState<SelectedLocation>(DEFAULT_LOCATION);
  const [rain, setRain] = useState<RainResponse | null>(initialRain);
  const [rainLoading, setRainLoading] = useState(false);
  const [rainErrMsg, setRainErrMsg] = useState<string | undefined>(rainError);

  const refetchRain = useCallback(
    async (lat: number, lon: number, signal: AbortSignal) => {
      setRainLoading(true);
      setRainErrMsg(undefined);
      try {
        const data = await api.rain(lat, lon);
        if (!signal.aborted) setRain(data);
      } catch (err) {
        if (signal.aborted) return;
        if (err instanceof ApiError && err.status === 503) {
          setRainErrMsg("Nog geen radardata beschikbaar.");
        } else {
          setRainErrMsg("De voorspelling is even niet bereikbaar.");
        }
        setRain(null);
      } finally {
        if (!signal.aborted) setRainLoading(false);
      }
    },
    [],
  );

  useEffect(() => {
    if (
      location.lat === DEFAULT_LOCATION.lat &&
      location.lon === DEFAULT_LOCATION.lon
    ) {
      // The SSR loader already filled `rain` for the default location.
      return;
    }
    const ctrl = new AbortController();
    refetchRain(location.lat, location.lon, ctrl.signal);
    return () => ctrl.abort();
  }, [location.lat, location.lon, refetchRain]);

  return (
    <>
      <SiteHeader />
      <main className="flex-1">
        <section
          aria-label="Plaats kiezen"
          className="mx-auto max-w-6xl px-4 sm:px-6 pt-6 sm:pt-8"
        >
          <LocationBar current={location} onSelect={setLocation} />
        </section>

        <section
          aria-labelledby="hero-title"
          className="mx-auto max-w-6xl px-4 sm:px-6 pt-8 pb-4"
        >
          <p className="text-xs uppercase tracking-[0.22em] text-[--color-accent-600] font-semibold">
            Regenradar Nederland
          </p>
          <h1
            id="hero-title"
            className="mt-2 text-4xl sm:text-5xl font-semibold tracking-tight leading-[1.05]"
          >
            Hoe laat valt er regen?
          </h1>
          <p className="mt-3 text-base sm:text-lg text-[--color-ink-700] max-w-2xl">
            Open weerplatform voor Nederland. Data direct van het{" "}
            <a
              href="https://www.knmi.nl"
              target="_blank"
              rel="noopener noreferrer"
              className="underline underline-offset-4 hover:text-[--color-accent-600]"
            >
              KNMI
            </a>
            , elke 5 minuten ververst.
          </p>
        </section>

        <section
          aria-label="Regenradar"
          className="mx-auto max-w-6xl px-4 sm:px-6 pb-6"
        >
          <div className="relative w-full rounded-3xl border border-[--color-ink-100] bg-white shadow-sm overflow-hidden">
            <div className="relative w-full aspect-[16/10] sm:aspect-[16/7] lg:aspect-[21/9]">
              {framesErrored ? (
                <div className="absolute inset-0 grid place-items-center p-8 text-sm text-[--color-ink-500]">
                  De radar is even niet bereikbaar — we proberen het
                  automatisch opnieuw.
                </div>
              ) : (
                <MapMount frames={playable} />
              )}
            </div>
          </div>
        </section>

        <section
          aria-label="Weersinformatie"
          className="mx-auto max-w-6xl px-4 sm:px-6 pb-16 grid gap-4 lg:grid-cols-2"
        >
          <WeatherNowCard
            locationName={location.name}
            rain={rain}
            loading={rainLoading}
          />
          <RainForecastCard
            locationName={location.name}
            rain={rain}
            loading={rainLoading}
            errorMessage={rainErrMsg}
          />
        </section>
      </main>
      <SiteFooter />
    </>
  );
}
