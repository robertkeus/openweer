import type { Route } from "./+types/home";
import { api } from "~/lib/api";
import { MapMount } from "~/components/MapMount";
import { SiteFooter } from "~/components/SiteFooter";
import { SiteHeader } from "~/components/SiteHeader";
import { defaultPlayableFrames } from "~/lib/frames";

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
  // SSR: fetch the manifest so the page can render meaningful content even
  // before the client-side map mounts. Failures degrade gracefully.
  try {
    const frames = await api.frames();
    return { frames, errored: false as const };
  } catch (err) {
    return { frames: { frames: [], generated_at: "" }, errored: true as const };
  }
}

export default function Home({ loaderData }: Route.ComponentProps) {
  const { frames, errored } = loaderData;
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
          aria-label="Regenradar"
          className="mx-auto max-w-6xl px-4 sm:px-6 pb-16"
        >
          <div className="relative rounded-2xl border border-[--color-ink-100] bg-white shadow-sm overflow-hidden dark:bg-[--color-ink-900] dark:border-[--color-ink-700]">
            <div className="relative aspect-[4/3] sm:aspect-[16/9]">
              {errored ? (
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
      </main>
      <SiteFooter />
    </>
  );
}
