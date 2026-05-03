import { Link } from "react-router";

export function SiteHeader() {
  return (
    <header className="border-b border-[--color-ink-100]/60 backdrop-blur supports-[backdrop-filter]:bg-white/70 dark:supports-[backdrop-filter]:bg-[--color-ink-900]/60">
      <div className="mx-auto max-w-6xl px-4 sm:px-6 py-3 flex items-center justify-between">
        <Link
          to="/"
          aria-label="OpenWeer — naar de homepagina"
          className="flex items-center gap-2 font-semibold tracking-tight text-lg"
        >
          <Logo className="h-6 w-6" aria-hidden="true" />
          OpenWeer
        </Link>
        <nav aria-label="Hoofdmenu" className="flex items-center gap-4 text-sm">
          <Link
            to="/"
            className="hover:text-[--color-accent-600] transition-colors"
          >
            Radar
          </Link>
          <a
            href="https://github.com/robertkeus/openweer"
            target="_blank"
            rel="noopener noreferrer"
            className="hover:text-[--color-accent-600] transition-colors"
          >
            GitHub
          </a>
        </nav>
      </div>
    </header>
  );
}

function Logo(props: React.SVGProps<SVGSVGElement>) {
  return (
    <svg viewBox="0 0 24 24" fill="none" {...props}>
      <circle cx="12" cy="12" r="10" stroke="currentColor" strokeWidth="1.5" />
      <path
        d="M5 14a4 4 0 014-4 5 5 0 019.5 1.5A3.5 3.5 0 1118 18H8a3 3 0 01-3-4z"
        fill="currentColor"
        opacity="0.18"
        stroke="currentColor"
        strokeWidth="1.5"
        strokeLinejoin="round"
      />
    </svg>
  );
}
