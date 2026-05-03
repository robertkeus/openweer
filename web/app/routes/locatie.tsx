import type { Route } from "./+types/locatie";
import { SiteFooter } from "~/components/SiteFooter";
import { SiteHeader } from "~/components/SiteHeader";

export function meta({ params }: Route.MetaArgs) {
  return [
    { title: `OpenWeer — weer in ${params.slug}` },
    {
      name: "description",
      content: `Actuele regen, temperatuur en wind voor ${params.slug}.`,
    },
  ];
}

export default function Locatie({ params }: Route.ComponentProps) {
  return (
    <>
      <SiteHeader />
      <main className="flex-1">
        <section className="mx-auto max-w-6xl px-4 sm:px-6 py-16">
          <p className="text-sm font-medium uppercase tracking-wider text-[--color-accent-600]">
            Locatie
          </p>
          <h1 className="mt-2 text-4xl font-semibold tracking-tight">
            Weer in {params.slug}
          </h1>
          <p className="mt-4 text-[--color-ink-700]">
            Actuele waarnemingen en de regenkaart voor deze locatie volgen in
            een volgende build.
          </p>
        </section>
      </main>
      <SiteFooter />
    </>
  );
}
