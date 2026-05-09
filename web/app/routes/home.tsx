import { useCallback, useEffect, useState } from "react";
import { Link } from "react-router";
import type { Route } from "./+types/home";
import {
  ApiError,
  api,
  type ForecastResponse,
  type RainResponse,
  type WeatherResponse,
} from "~/lib/api";
import { AiChatPanel } from "~/components/AiChatPanel";
import { CurrentTimeChip } from "~/components/CurrentTimeChip";
import { LocationBar, type SelectedLocation } from "~/components/LocationBar";
import { LocationConsent } from "~/components/LocationConsent";
import { Logo } from "~/components/Logo";
import { MapMount } from "~/components/MapMount";
import { RainGraph, RainSummary } from "~/components/RainGraph";
import { RainLegend } from "~/components/RainLegend";
import { RainSheet } from "~/components/RainSheet";
import { RecenterButton } from "~/components/RecenterButton";
import { ThemeToggle } from "~/components/ThemeToggle";
import { Timeline } from "~/components/Timeline";
import { WeatherNowCard } from "~/components/WeatherNowCard";
import { WeatherTab } from "~/components/WeatherTab";
import { buildContext } from "~/lib/ai-chat";
import { DEFAULT_LOCATION } from "~/lib/locations";
import { useGeolocation } from "~/lib/use-geolocation";
import { useLiveFrames } from "~/lib/use-live-frames";
import { useRadarTimeline } from "~/lib/use-radar-timeline";
import { useTheme } from "~/lib/theme";

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
  const [frames, rain, weather, forecast] = await Promise.allSettled([
    api.frames(),
    api.rain(DEFAULT_LOCATION.lat, DEFAULT_LOCATION.lon),
    api.weather(DEFAULT_LOCATION.lat, DEFAULT_LOCATION.lon),
    api.forecast(DEFAULT_LOCATION.lat, DEFAULT_LOCATION.lon),
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
    weather: weather.status === "fulfilled" ? weather.value : null,
    weatherError:
      weather.status === "rejected"
        ? "Het weerbeeld is even niet bereikbaar."
        : undefined,
    forecast: forecast.status === "fulfilled" ? forecast.value : null,
    forecastError:
      forecast.status === "rejected"
        ? "De meerdaagse verwachting is even niet bereikbaar."
        : undefined,
  };
}

export default function Home({ loaderData }: Route.ComponentProps) {
  const {
    frames,
    framesErrored,
    rain: initialRain,
    rainError,
    weather: initialWeather,
    weatherError,
  } = loaderData;

  const [location, setLocation] = useState<SelectedLocation>(DEFAULT_LOCATION);
  const [rain, setRain] = useState<RainResponse | null>(initialRain);
  const [rainLoading, setRainLoading] = useState(false);
  const [rainErrMsg, setRainErrMsg] = useState<string | undefined>(rainError);
  const [weather, setWeather] = useState<WeatherResponse | null>(
    initialWeather,
  );
  const [weatherLoading, setWeatherLoading] = useState(false);
  const [weatherErrMsg, setWeatherErrMsg] = useState<string | undefined>(
    weatherError,
  );
  const [forecast, setForecast] = useState<ForecastResponse | null>(
    loaderData.forecast,
  );
  const [forecastErrMsg, setForecastErrMsg] = useState<string | undefined>(
    loaderData.forecastError,
  );
  const [consentDismissed, setConsentDismissed] = useState(false);

  const liveFrames = useLiveFrames(frames);
  const timeline = useRadarTimeline(liveFrames);
  const { resolved: resolvedTheme } = useTheme();
  const chatContext = buildContext({
    location,
    rain,
    cursorFrame: timeline.current,
    language: "nl",
    theme: resolvedTheme,
  });

  const consent = useGeolocation((loc) => {
    setLocation(loc);
    setConsentDismissed(true);
  });
  const showConsent =
    !consentDismissed &&
    location.lat === DEFAULT_LOCATION.lat &&
    location.lon === DEFAULT_LOCATION.lon;

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

  const refetchWeather = useCallback(
    async (lat: number, lon: number, signal: AbortSignal) => {
      setWeatherLoading(true);
      setWeatherErrMsg(undefined);
      try {
        const data = await api.weather(lat, lon);
        if (!signal.aborted) setWeather(data);
      } catch (err) {
        if (signal.aborted) return;
        if (err instanceof ApiError && err.status === 503) {
          setWeatherErrMsg("Nog geen waarnemingen beschikbaar.");
        } else {
          setWeatherErrMsg("Het weerbeeld is even niet bereikbaar.");
        }
        setWeather(null);
      } finally {
        if (!signal.aborted) setWeatherLoading(false);
      }
    },
    [],
  );

  const refetchForecast = useCallback(
    async (lat: number, lon: number, signal: AbortSignal) => {
      setForecastErrMsg(undefined);
      try {
        const data = await api.forecast(lat, lon);
        if (!signal.aborted) setForecast(data);
      } catch {
        if (signal.aborted) return;
        setForecastErrMsg("De meerdaagse verwachting is even niet bereikbaar.");
        setForecast(null);
      }
    },
    [],
  );

  useEffect(() => {
    if (
      location.lat === DEFAULT_LOCATION.lat &&
      location.lon === DEFAULT_LOCATION.lon
    ) {
      return;
    }
    const ctrl = new AbortController();
    refetchRain(location.lat, location.lon, ctrl.signal);
    refetchWeather(location.lat, location.lon, ctrl.signal);
    refetchForecast(location.lat, location.lon, ctrl.signal);
    return () => ctrl.abort();
  }, [
    location.lat,
    location.lon,
    refetchRain,
    refetchWeather,
    refetchForecast,
  ]);

  return (
    <div className="map-shell fixed inset-0 overflow-hidden">
      {/* Map fills the viewport. */}
      <div className="absolute inset-0">
        {framesErrored ? (
          <div className="absolute inset-0 grid place-items-center p-8 text-sm text-[--color-ink-500] bg-gradient-to-br from-sky-50 via-white to-white">
            De radar is even niet bereikbaar — we proberen het automatisch
            opnieuw.
          </div>
        ) : (
          <MapMount
            frames={timeline.frames}
            currentIndex={timeline.currentIndex}
            center={{ lat: location.lat, lon: location.lon }}
            onLocationPick={setLocation}
            className="absolute inset-0"
          />
        )}
      </div>

      {/* Top: logo + location bar (left, capped) + current-time chip (right). */}
      <div
        className="pointer-events-none absolute inset-x-0 z-20 px-3 sm:px-4 flex flex-col items-stretch gap-2 sm:gap-3"
        style={{ top: "max(env(safe-area-inset-top, 0px) + 0.75rem, 0.75rem)" }}
      >
        <div className="flex items-center gap-2 sm:gap-3">
          <Link
            to="/"
            aria-label="OpenWeer"
            title="OpenWeer"
            className="pointer-events-auto floating-btn group flex-none"
          >
            <Logo className="h-6 w-6" aria-hidden="true" />
          </Link>
          <div className="pointer-events-auto flex-1 min-w-0 max-w-md sm:max-w-lg">
            <LocationBar current={location} onSelect={setLocation} />
          </div>
          {/* Time chip is desktop/tablet only — on mobile the slider's "Nu" pill covers this. */}
          <div className="hidden sm:block pointer-events-auto flex-none ml-auto">
            <CurrentTimeChip samples={rain?.samples} />
          </div>
          <div className="pointer-events-auto flex-none">
            <ThemeToggle variant="floating" />
          </div>
        </div>
        {showConsent ? (
          <div className="pointer-events-auto self-center w-full max-w-xl">
            <LocationConsent
              onAccept={() => {
                void consent.resolve();
              }}
              onDismiss={() => setConsentDismissed(true)}
              resolving={consent.resolving}
              error={consent.error}
            />
          </div>
        ) : null}
      </div>

      {/* Mobile-only recenter button (desktop relies on the crosshair inside the location bar).
       * Sits one slot above the chat FAB (~3.75rem button + 0.5rem gap). */}
      <div className="lg:hidden pointer-events-none absolute right-3 bottom-[calc(var(--timeline-height)+1rem+3.75rem)] z-20">
        <div className="pointer-events-auto">
          <RecenterButton onLocate={setLocation} />
        </div>
      </div>

      {/* Bottom-right tabbed panel (sits above the timeline). */}
      <RainSheet
        defaultTab="chat"
        chat={<AiChatPanel context={chatContext} />}
        weather={
          <WeatherTab
            weather={weather}
            forecast={forecast}
            loading={weatherLoading}
            errorMessage={weatherErrMsg}
            forecastErrorMessage={forecastErrMsg}
          />
        }
        details={
          <>
            {rainErrMsg ? (
              <p className="text-sm text-[--color-ink-500]">{rainErrMsg}</p>
            ) : rainLoading ? (
              <p className="text-sm text-[--color-ink-500]">
                Voorspelling laden…
              </p>
            ) : rain && rain.samples.length ? (
              <>
                <RainSummary samples={rain.samples} />
                <RainLegend />
                <div className="text-[--color-accent-600]">
                  <RainGraph samples={rain.samples} height={140} />
                </div>
                <WeatherNowCard
                  locationName={location.name}
                  rain={rain}
                  loading={rainLoading}
                />
              </>
            ) : (
              <p className="text-sm text-[--color-ink-500]">
                Geen voorspelling beschikbaar.
              </p>
            )}
          </>
        }
      />

      {/* Full-width timeline pinned to viewport bottom. */}
      <div className="pointer-events-none fixed inset-x-0 bottom-0 z-40 px-2 sm:px-3 pb-[max(env(safe-area-inset-bottom,0),0.5rem)]">
        <Timeline
          frames={timeline.frames}
          currentIndex={timeline.currentIndex}
          nowIndex={timeline.nowIndex}
          isPlaying={timeline.isPlaying}
          rainSamples={rain?.samples}
          onSeek={timeline.seek}
          onTogglePlay={timeline.togglePlay}
        />
      </div>
    </div>
  );
}
