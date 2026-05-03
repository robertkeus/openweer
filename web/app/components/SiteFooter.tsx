export function SiteFooter() {
  return (
    <footer className="mt-auto border-t border-[--color-ink-100]/60">
      <div className="mx-auto max-w-6xl px-4 sm:px-6 py-6 text-sm text-[--color-ink-500] flex flex-col sm:flex-row sm:items-center sm:justify-between gap-3">
        <p>
          Weerdata ©{" "}
          <a
            href="https://www.knmi.nl"
            target="_blank"
            rel="noopener noreferrer"
            className="underline underline-offset-2 hover:text-[--color-ink-900]"
          >
            KNMI
          </a>
          ,{" "}
          <a
            href="https://creativecommons.org/licenses/by/4.0/deed.nl"
            target="_blank"
            rel="noopener noreferrer"
            className="underline underline-offset-2 hover:text-[--color-ink-900]"
          >
            CC&nbsp;BY&nbsp;4.0
          </a>
          . OpenWeer is open source onder MIT.
        </p>
        <p>
          <a
            href="https://github.com/robertkeus/openweer"
            target="_blank"
            rel="noopener noreferrer"
            className="underline underline-offset-2 hover:text-[--color-ink-900]"
          >
            github.com/robertkeus/openweer
          </a>
        </p>
      </div>
    </footer>
  );
}
