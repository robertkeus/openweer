import type { Route } from "./+types/locatie";
import { data } from "react-router";
import { api, ApiError } from "~/lib/api";
import { RainForecastCard } from "~/components/RainForecastCard";
import { SiteFooter } from "~/components/SiteFooter";
import { SiteHeader } from "~/components/SiteHeader";
import { WeatherNowCard } from "~/components/WeatherNowCard";
import { findLocationBySlug } from "~/lib/locations";

export function meta({ params, data: loaderData }: Route.MetaArgs) {
  const name = loaderData?.location.name ?? params.slug;
  return [
    { title: `OpenWeer — regen in ${name}` },
    {
      name: "description",
      content: `Live regenradar en de minutenvoorspelling voor ${name}, op basis van KNMI open data.`,
    },
  ];
}

export async function loader({ params }: Route.LoaderArgs) {
  const location = findLocationBySlug(params.slug);
  if (!location) {
    throw data("Locatie onbekend", { status: 404 });
  }

  const rain = await api.rain(location.lat, location.lon).catch((err) => {
    if (err instanceof ApiError) return null;
    throw err;
  });

  return { location, rain };
}

export default function Locatie({ loaderData }: Route.ComponentProps) {
  const { location, rain } = loaderData;
  return (
    <>
      <SiteHeader />
      <main className="flex-1">
        <section className="mx-auto max-w-3xl px-4 sm:px-6 py-12">
          <p className="text-sm font-medium uppercase tracking-wider text-[--color-accent-600]">
            Locatie
          </p>
          <h1 className="mt-2 text-4xl font-semibold tracking-tight">
            Weer in {location.name}
          </h1>
          <p className="mt-3 text-[--color-ink-700]">
            Coördinaten: {location.lat.toFixed(2)}°N, {location.lon.toFixed(2)}°O
          </p>
          <div className="mt-8 grid gap-4 sm:grid-cols-2">
            <WeatherNowCard locationName={location.name} rain={rain} />
            <RainForecastCard locationName={location.name} rain={rain} />
          </div>
        </section>
      </main>
      <SiteFooter />
    </>
  );
}
