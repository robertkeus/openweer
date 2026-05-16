import type { Route } from "./+types/terms";
import { SiteFooter } from "~/components/SiteFooter";
import { SiteHeader } from "~/components/SiteHeader";

export function meta(_: Route.MetaArgs) {
  return [
    { title: "OpenWeer — Voorwaarden" },
    {
      name: "description",
      content:
        "Gebruiksvoorwaarden van OpenWeer: een gratis open-source weerproject zonder garanties.",
    },
  ];
}

export default function Terms() {
  return (
    <>
      <SiteHeader />
      <main className="flex-1">
        <article className="mx-auto max-w-3xl px-4 sm:px-6 py-12">
          <p className="text-sm font-medium uppercase tracking-wider text-[--color-accent-600]">
            Juridisch
          </p>
          <h1 className="mt-2 text-4xl font-semibold tracking-tight">
            Gebruiksvoorwaarden
          </h1>
          <p className="mt-3 text-[--color-ink-500]">
            Laatst bijgewerkt: 16 mei 2026
          </p>

          <section className="mt-10 space-y-4 text-[--color-ink-700] leading-relaxed">
            <h2 className="text-2xl font-semibold tracking-tight text-[--color-ink-900]">
              Over OpenWeer
            </h2>
            <p>
              OpenWeer is een gratis, open-source weerplatform voor
              Nederland. Het is een persoonlijk project van Robert Keus en
              wordt zonder winstoogmerk aangeboden. De broncode staat onder
              de{" "}
              <a
                href="https://opensource.org/license/mit"
                target="_blank"
                rel="noopener noreferrer"
                className="underline underline-offset-2 hover:text-[--color-ink-900]"
              >
                MIT-licentie
              </a>{" "}
              op{" "}
              <a
                href="https://github.com/robertkeus/openweer"
                target="_blank"
                rel="noopener noreferrer"
                className="underline underline-offset-2 hover:text-[--color-ink-900]"
              >
                GitHub
              </a>
              .
            </p>
          </section>

          <section className="mt-10 space-y-4 text-[--color-ink-700] leading-relaxed">
            <h2 className="text-2xl font-semibold tracking-tight text-[--color-ink-900]">
              Acceptatie
            </h2>
            <p>
              Door OpenWeer (de website of de iOS-app) te gebruiken ga je
              akkoord met deze voorwaarden. Gebruik je OpenWeer niet als je
              het er niet mee eens bent.
            </p>
          </section>

          <section className="mt-10 space-y-4 text-[--color-ink-700] leading-relaxed">
            <h2 className="text-2xl font-semibold tracking-tight text-[--color-ink-900]">
              Geen garanties
            </h2>
            <p>
              OpenWeer wordt aangeboden &ldquo;as is&rdquo;. We doen ons best
              om actuele weerinformatie te tonen, maar geven{" "}
              <strong>geen garanties</strong> over juistheid, volledigheid,
              actualiteit of beschikbaarheid van de service. Er is geen
              service level agreement (SLA): downtime, fouten in de
              voorspelling en storingen kunnen voorkomen.
            </p>
            <p>
              Voor levens- of veiligheidskritische beslissingen (vliegverkeer,
              scheepvaart, hulpdiensten, evenementenbeveiliging) moet je
              altijd officiële bronnen raadplegen, zoals het{" "}
              <a
                href="https://www.knmi.nl/nederland-nu/weer/waarschuwingen"
                target="_blank"
                rel="noopener noreferrer"
                className="underline underline-offset-2 hover:text-[--color-ink-900]"
              >
                KNMI-waarschuwingen
              </a>
              .
            </p>
          </section>

          <section className="mt-10 space-y-4 text-[--color-ink-700] leading-relaxed">
            <h2 className="text-2xl font-semibold tracking-tight text-[--color-ink-900]">
              Aansprakelijkheid
            </h2>
            <p>
              Voor zover wettelijk toegestaan is OpenWeer (Robert Keus) niet
              aansprakelijk voor directe of indirecte schade die voortkomt
              uit gebruik of het niet kunnen gebruiken van de service,
              inclusief schade door (uitblijvende) weersvoorspellingen.
            </p>
          </section>

          <section className="mt-10 space-y-4 text-[--color-ink-700] leading-relaxed">
            <h2 className="text-2xl font-semibold tracking-tight text-[--color-ink-900]">
              Gebruik & rate-limiting
            </h2>
            <p>
              De API is bedoeld voor persoonlijk en niet-commercieel gebruik.
              Geautomatiseerd massaal verkeer, scraping van tile-endpoints en
              andere vormen van overmatig gebruik kunnen worden geblokkeerd
              of gerate-limit zonder voorafgaande kennisgeving.
            </p>
          </section>

          <section className="mt-10 space-y-4 text-[--color-ink-700] leading-relaxed">
            <h2 className="text-2xl font-semibold tracking-tight text-[--color-ink-900]">
              Bronvermelding KNMI
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
              . OpenWeer is geen onderdeel van het KNMI en is niet door het
              KNMI goedgekeurd of gesponsord.
            </p>
          </section>

          <section className="mt-10 space-y-4 text-[--color-ink-700] leading-relaxed">
            <h2 className="text-2xl font-semibold tracking-tight text-[--color-ink-900]">
              Wijzigingen
            </h2>
            <p>
              Deze voorwaarden kunnen op elk moment worden aangepast. De
              actuele versie is altijd op deze pagina te vinden, met de
              datum &ldquo;Laatst bijgewerkt&rdquo; bovenaan.
            </p>
          </section>

          <section className="mt-10 space-y-4 text-[--color-ink-700] leading-relaxed">
            <h2 className="text-2xl font-semibold tracking-tight text-[--color-ink-900]">
              Toepasselijk recht
            </h2>
            <p>
              Op deze voorwaarden is Nederlands recht van toepassing.
              Geschillen worden voorgelegd aan de bevoegde rechter in
              Nederland.
            </p>
          </section>

          <section className="mt-10 space-y-4 text-[--color-ink-700] leading-relaxed">
            <h2 className="text-2xl font-semibold tracking-tight text-[--color-ink-900]">
              Contact
            </h2>
            <p>
              Vragen?{" "}
              <a
                href="mailto:info@openweer.nl"
                className="underline underline-offset-2 hover:text-[--color-ink-900]"
              >
                info@openweer.nl
              </a>
              .
            </p>
          </section>

          <section className="mt-12 pt-8 border-t border-[--color-ink-100] space-y-3 text-[--color-ink-500] text-sm leading-relaxed">
            <h2 className="text-base font-semibold text-[--color-ink-700]">
              English summary
            </h2>
            <p>
              OpenWeer is a free, open-source (MIT) personal project by
              Robert Keus. The service is provided &ldquo;as is&rdquo;,
              without warranties or any SLA, and you must rely on official
              KNMI warnings for safety-critical decisions. To the extent
              permitted by law, no liability is accepted for damages
              resulting from use of the service or from inaccurate
              forecasts. Weather data is © KNMI, CC&nbsp;BY&nbsp;4.0; OpenWeer
              is not affiliated with KNMI. Dutch law applies.
            </p>
          </section>
        </article>
      </main>
      <SiteFooter />
    </>
  );
}
