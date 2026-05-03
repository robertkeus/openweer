import type { Route } from "./+types/home";
import { api, ApiError } from "~/lib/api";
import { LocationCard } from "~/components/LocationCard";
import { MapMount } from "~/components/MapMount";
import { SiteFooter } from "~/components/SiteFooter";
import { SiteHeader } from "~/components/SiteHeader";
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
  // SSR: fetch the manifest + the default-location rain forecast so the page
  // has meaningful content before the client-side map mounts. Failures degrade
  // gracefully (the page still renders).
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
  const { frames, framesErrored, rain, rainError } = loaderData;
  const playable = defaultPlayableFrames(frames.frames);

  return (
    <>
      <SiteHeader />
      <main className="flex-1">
        <section className="mx-auto max-w-6xl px-4 sm:px-6 pt-10 sm:pt-12 pb-6 sm:pb-8">
          <p className="text-sm font-medium uppercase tracking-wider text-[--color-accent-600]">
            Regenradar Nederland
          </p>
          <h1 className="mt-2 text-4xl sm:text-5xl font-semibold tracking-tight leading-tight">
            Hoe laat valt er regen op jouw plek?
          </h1>
          <p className="mt-4 text-lg text-[--color-ink-700] max-w-2xl">
            Een open, snel en advertentievrij weerplatform voor Nederland.
            Data komt rechtstreeks van het{" "}
            <a
              href="https://www.knmi.nl"
              target="_blank"
              rel="noopener noreferrer"
              className="underline underline-offset-4 hover:text-[--color-accent-600]"
            >
              KNMI
            </a>{" "}
            en wordt elke 5 minuten ververst.
          </p>
        </section>

        <section
          aria-label="Regenvoorspelling en radar"
          className="mx-auto max-w-6xl px-4 sm:px-6 pb-16 grid gap-6 lg:grid-cols-[minmax(0,2fr)_minmax(0,1fr)]"
        >
          <div className="relative rounded-2xl border border-[--color-ink-100] bg-white shadow-sm overflow-hidden dark:bg-[--color-ink-900] dark:border-[--color-ink-700] order-2 lg:order-1">
            <div className="relative aspect-[4/3] sm:aspect-[16/9] lg:aspect-auto lg:h-full lg:min-h-[480px]">
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
          <div className="order-1 lg:order-2">
            <LocationCard
              locationName={DEFAULT_LOCATION.name}
              rain={rain}
              errorMessage={rainError}
            />
          </div>
        </section>
      </main>
      <SiteFooter />
    </>
  );
}
