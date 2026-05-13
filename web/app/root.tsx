import {
  isRouteErrorResponse,
  Links,
  Meta,
  Outlet,
  Scripts,
  ScrollRestoration,
} from "react-router";

import type { Route } from "./+types/root";
import "./app.css";
import { ANTI_FOUC_SCRIPT } from "./lib/theme";

const SITE_NAME = "OpenWeer";
const SITE_DESCRIPTION =
  "Open weerplatform voor Nederland: regenradar, neerslagverwachting en actuele waarnemingen. Open data van het KNMI.";

export const links: Route.LinksFunction = () => [
  { rel: "icon", href: "/favicon.svg", type: "image/svg+xml" },
  { rel: "apple-touch-icon", href: "/icon-192.png" },
  { rel: "manifest", href: "/manifest.webmanifest" },
  { rel: "preconnect", href: "https://fonts.googleapis.com" },
  {
    rel: "preconnect",
    href: "https://fonts.gstatic.com",
    crossOrigin: "anonymous",
  },
  {
    rel: "stylesheet",
    href: "https://fonts.googleapis.com/css2?family=Inter:wght@400;500;600;700&display=swap",
  },
];

export const meta: Route.MetaFunction = () => [
  { title: `${SITE_NAME} — open weerplatform voor Nederland` },
  { name: "description", content: SITE_DESCRIPTION },
  {
    name: "theme-color",
    content: "#f8fafc",
    media: "(prefers-color-scheme: light)",
  },
  {
    name: "theme-color",
    content: "#0b1320",
    media: "(prefers-color-scheme: dark)",
  },
  { property: "og:title", content: SITE_NAME },
  { property: "og:description", content: SITE_DESCRIPTION },
  { property: "og:type", content: "website" },
  { property: "og:locale", content: "nl_NL" },
];

export function Layout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="nl" suppressHydrationWarning>
      <head>
        <meta charSet="utf-8" />
        <meta
          name="viewport"
          content="width=device-width, initial-scale=1, viewport-fit=cover"
        />
        <Meta />
        <Links />
        {/* Anti-FOUC: set <html class="dark"> before first paint, based on
            stored preference + prefers-color-scheme. Inline so it runs
            synchronously, ahead of hydration. */}
        <script dangerouslySetInnerHTML={{ __html: ANTI_FOUC_SCRIPT }} />
      </head>
      <body className="min-h-screen flex flex-col">
        {children}
        <ScrollRestoration />
        <Scripts />
      </body>
    </html>
  );
}

export default function App() {
  return <Outlet />;
}

export function ErrorBoundary({ error }: Route.ErrorBoundaryProps) {
  let title = "Er ging iets mis";
  let detail = "Er deed zich een onverwachte fout voor.";
  let stack: string | undefined;

  if (isRouteErrorResponse(error)) {
    title = error.status === 404 ? "Pagina niet gevonden" : "Fout";
    detail =
      error.status === 404
        ? "De pagina die je zocht bestaat (nog) niet."
        : error.statusText || detail;
  } else if (import.meta.env.DEV && error instanceof Error) {
    detail = error.message;
    stack = error.stack;
  }

  return (
    <main className="container mx-auto px-4 py-16 max-w-2xl">
      <h1 className="text-3xl font-semibold tracking-tight">{title}</h1>
      <p className="mt-2 text-lg text-[--color-ink-700]">{detail}</p>
      <a
        href="/"
        className="mt-6 inline-block underline underline-offset-4 hover:text-[--color-accent-600]"
      >
        Terug naar de homepagina
      </a>
      {stack ? (
        <pre className="mt-8 w-full p-4 overflow-x-auto text-xs bg-[--color-ink-100] rounded">
          <code>{stack}</code>
        </pre>
      ) : null}
    </main>
  );
}
