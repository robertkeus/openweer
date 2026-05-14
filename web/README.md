# OpenWeer — Web

The React Router v7 frontend for [openweer.nl](https://openweer.nl). Renders the rain radar map, animated timeline, per-location rain forecast, current observations, and the AI chat panel.

For the project overview, license, and architecture diagram see the [root README](../README.md) and [CONTRIBUTING.md](../CONTRIBUTING.md).

## Stack

- **React Router v7** (framework mode, SSR)
- **MapLibre GL** for the radar map and tile layer
- **Tailwind CSS v4** for styling
- **TypeScript** (strict) · **Zod** for runtime validation of API payloads
- **Vitest** + Testing Library + msw for tests

## Layout

```
app/
├── root.tsx              # HTML shell, theme, global providers
├── routes.ts             # route table
├── routes/               # route modules (loaders + components)
├── components/           # UI components (see below)
└── lib/                  # formatting, API client, hooks
```

Notable components in [`app/components/`](app/components):

| Component | Role |
|---|---|
| `RadarMap.client.tsx` | MapLibre canvas, KNMI tile layer, attribution |
| `Timeline.tsx` | The hero scrubber — 60 fps, snaps to KNMI 5-minute frames |
| `HorizonButton.tsx` | Switches between nowcast (+2h) and HARMONIE (+24h / +48h) |
| `RainSheet.tsx` · `RainGraph.tsx` | Per-location minute-by-minute rain forecast |
| `WeatherNowCard.tsx` · `WeatherTab.tsx` | Current observations and short-range forecast |
| `AiChatPanel.tsx` · `ChatMarkdown.tsx` | AI chat over `/api/chat` |
| `SiteFooter.tsx` | KNMI CC-BY-4.0 + MIT attribution (required) |

## Local development

Requires Node ≥ 22.

```bash
npm ci
npm run dev          # http://localhost:5173
```

The dev server expects the FastAPI backend on `http://localhost:8000`. Start it with `docker compose up api` from the repo root, or follow the backend instructions in [`../api/README.md`](../api/README.md).

## Scripts

```bash
npm run typecheck     # react-router typegen + tsc
npm run lint          # eslint
npm run format        # prettier --write
npm run test          # vitest run
npm run test:watch    # vitest in watch mode
npm run build         # production build → build/
npm start             # serve the production build
```

All four (`typecheck`, `lint`, `format:check`, `test`) run in CI on every push — see [`.github/workflows/ci.yml`](../.github/workflows/ci.yml).

## Conventions

- Strict TypeScript; no `any`. Validate external data (KNMI, API responses) with Zod at the boundary.
- Microcopy in Dutch; keep English fallback strings where they exist.
- Accessibility: WCAG 2.2 AA. Keyboard-reachable controls, visible focus, ARIA on map controls, `prefers-reduced-motion` disables animation.
- Performance budget: LCP < 1.5 s on 4G; Lighthouse ≥ 95.

See [`../CLAUDE.md`](../CLAUDE.md) for the full engineering rules.
