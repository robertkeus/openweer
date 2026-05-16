import type { Route } from "./+types/privacy";
import { SiteFooter } from "~/components/SiteFooter";
import { SiteHeader } from "~/components/SiteHeader";

export function meta(_: Route.MetaArgs) {
  return [
    { title: "OpenWeer — Privacy" },
    {
      name: "description",
      content:
        "Privacybeleid van OpenWeer: welke gegevens we wel en niet verwerken, en waarom.",
    },
  ];
}

export default function Privacy() {
  return (
    <>
      <SiteHeader />
      <main className="flex-1">
        <article className="mx-auto max-w-3xl px-4 sm:px-6 py-12 prose-openweer">
          <p className="text-sm font-medium uppercase tracking-wider text-[--color-accent-600]">
            Juridisch
          </p>
          <h1 className="mt-2 text-4xl font-semibold tracking-tight">
            Privacybeleid
          </h1>
          <p className="mt-3 text-[--color-ink-500]">
            Laatst bijgewerkt: 16 mei 2026
          </p>

          <section className="mt-10 space-y-4 text-[--color-ink-700] leading-relaxed">
            <h2 className="text-2xl font-semibold tracking-tight text-[--color-ink-900]">
              Korte versie
            </h2>
            <p>
              OpenWeer is een open-source weerplatform zonder accounts, zonder
              advertenties en zonder trackers. We verzamelen geen persoonlijke
              gegevens. Weerdata komt van het KNMI (open data, CC&nbsp;BY&nbsp;4.0).
            </p>
          </section>

          <section className="mt-10 space-y-4 text-[--color-ink-700] leading-relaxed">
            <h2 className="text-2xl font-semibold tracking-tight text-[--color-ink-900]">
              Wat we niet doen
            </h2>
            <ul className="list-disc pl-6 space-y-2">
              <li>Geen gebruikersaccounts, geen inlog, geen e-mailadressen.</li>
              <li>Geen advertenties en geen advertentienetwerken.</li>
              <li>
                Geen analytics-cookies, geen tracking-pixels, geen
                derde-partij-scripts die je over websites volgen.
              </li>
              <li>Geen verkoop of deling van gegevens met derden.</li>
            </ul>
          </section>

          <section className="mt-10 space-y-4 text-[--color-ink-700] leading-relaxed">
            <h2 className="text-2xl font-semibold tracking-tight text-[--color-ink-900]">
              Wat we wel verwerken
            </h2>
            <h3 className="text-lg font-semibold text-[--color-ink-900]">
              Website (openweer.nl)
            </h3>
            <ul className="list-disc pl-6 space-y-2">
              <li>
                <strong>Serverlogs:</strong> onze webserver (nginx) houdt
                tijdelijk standaard toegangslogs bij om misbruik en
                rate-limiting af te dwingen. IP-adressen worden uitsluitend
                voor dat doel gebruikt en niet aan een persoon gekoppeld.
              </li>
              <li>
                <strong>Locatie:</strong> als je locatie deelt via de browser
                gebruiken we die alleen lokaal in je apparaat om de
                regenradar op je positie te centreren. We slaan je exacte
                coördinaten niet op op onze server.
              </li>
              <li>
                <strong>Voorkeuren:</strong> thema (licht/donker) en
                geselecteerde locatie worden in <code>localStorage</code> van
                je browser opgeslagen — die data verlaat je apparaat niet.
              </li>
            </ul>

            <h3 className="mt-6 text-lg font-semibold text-[--color-ink-900]">
              iOS-app
            </h3>
            <ul className="list-disc pl-6 space-y-2">
              <li>
                <strong>Regennotificaties (optioneel):</strong> als je
                pushmeldingen aanzet, slaat onze server je anonieme APNs
                device-token op samen met de coördinaten van je favoriete
                locaties. Daarmee kunnen we je waarschuwen voor naderende
                regen. We koppelen die token niet aan een naam, e-mailadres
                of Apple-ID — het is een ondoorzichtige identifier van
                Apple.
              </li>
              <li>
                <strong>Locatie:</strong> je actuele locatie wordt alleen op
                je apparaat verwerkt om weer en radar voor jouw positie te
                tonen. Coördinaten die naar onze API worden gestuurd voor
                weerverzoeken worden niet aan jou gekoppeld bewaard.
              </li>
              <li>
                <strong>Geen tracking-SDK&apos;s:</strong> de app bevat geen
                analytics-, crash- of advertentie-SDK&apos;s van derden.
              </li>
            </ul>
          </section>

          <section className="mt-10 space-y-4 text-[--color-ink-700] leading-relaxed">
            <h2 className="text-2xl font-semibold tracking-tight text-[--color-ink-900]">
              Bewaartermijnen
            </h2>
            <ul className="list-disc pl-6 space-y-2">
              <li>
                Serverlogs: maximaal 14 dagen, daarna automatisch verwijderd.
              </li>
              <li>
                Push device-tokens: zolang je notificaties hebt aanstaan en
                de app geïnstalleerd is. Verwijder je de app of zet je push
                uit in de app, dan wordt de token verwijderd uit onze
                database.
              </li>
            </ul>
          </section>

          <section className="mt-10 space-y-4 text-[--color-ink-700] leading-relaxed">
            <h2 className="text-2xl font-semibold tracking-tight text-[--color-ink-900]">
              Toestemming intrekken
            </h2>
            <p>
              Zet pushmeldingen uit via{" "}
              <em>Instellingen → Meldingen → Regennotificaties</em> in de
              app, of verwijder de app. In beide gevallen wordt je
              device-token bij ons verwijderd.
            </p>
          </section>

          <section className="mt-10 space-y-4 text-[--color-ink-700] leading-relaxed">
            <h2 className="text-2xl font-semibold tracking-tight text-[--color-ink-900]">
              Bronvermelding
            </h2>
            <p>
              Weerdata is afkomstig van het{" "}
              <a
                href="https://www.knmi.nl"
                target="_blank"
                rel="noopener noreferrer"
                className="underline underline-offset-2 hover:text-[--color-ink-900]"
              >
                KNMI
              </a>{" "}
              onder de{" "}
              <a
                href="https://creativecommons.org/licenses/by/4.0/deed.nl"
                target="_blank"
                rel="noopener noreferrer"
                className="underline underline-offset-2 hover:text-[--color-ink-900]"
              >
                CC&nbsp;BY&nbsp;4.0-licentie
              </a>
              . OpenWeer is geen onderdeel van het KNMI.
            </p>
          </section>

          <section className="mt-10 space-y-4 text-[--color-ink-700] leading-relaxed">
            <h2 className="text-2xl font-semibold tracking-tight text-[--color-ink-900]">
              Contact
            </h2>
            <p>
              Vragen over privacy? Mail naar{" "}
              <a
                href="mailto:privacy@openweer.nl"
                className="underline underline-offset-2 hover:text-[--color-ink-900]"
              >
                privacy@openweer.nl
              </a>
              .
            </p>
          </section>

          <section className="mt-12 pt-8 border-t border-[--color-ink-100] space-y-3 text-[--color-ink-500] text-sm leading-relaxed">
            <h2 className="text-base font-semibold text-[--color-ink-700]">
              English summary
            </h2>
            <p>
              OpenWeer is an open-source weather platform with no accounts,
              no ads and no third-party trackers. The website keeps
              short-lived nginx access logs only for rate-limiting. The iOS
              app stores an anonymous APNs device token plus your favourite
              coordinates on our server <em>only</em> when you opt in to
              rain push notifications; turning push off or deleting the app
              removes the token. Weather data is © KNMI, CC&nbsp;BY&nbsp;4.0.
              Questions: privacy@openweer.nl.
            </p>
          </section>
        </article>
      </main>
      <SiteFooter />
    </>
  );
}
