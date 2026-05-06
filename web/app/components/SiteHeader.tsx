import { Link } from "react-router";
import { Logo } from "~/components/Logo";
import { ThemeToggle } from "~/components/ThemeToggle";

export function SiteHeader() {
  return (
    <header className="border-b border-[--color-border]/60 backdrop-blur supports-[backdrop-filter]:bg-[--color-surface-elevated]/70 bg-[--color-surface-elevated]">
      <div className="mx-auto max-w-6xl px-4 sm:px-6 py-3 flex items-center justify-between">
        <Link
          to="/"
          aria-label="OpenWeer — naar de homepagina"
          className="group flex items-center gap-2 font-semibold tracking-tight text-lg"
        >
          <Logo className="h-6 w-6" aria-hidden="true" />
          OpenWeer
        </Link>
        <nav aria-label="Hoofdmenu" className="flex items-center gap-3 text-sm">
          <Link
            to="/"
            className="px-1 hover:text-[--color-accent-600] transition-colors"
          >
            Radar
          </Link>
          <a
            href="https://github.com/robertkeus/openweer"
            target="_blank"
            rel="noopener noreferrer"
            className="px-1 hover:text-[--color-accent-600] transition-colors"
          >
            GitHub
          </a>
          <ThemeToggle />
        </nav>
      </div>
    </header>
  );
}
