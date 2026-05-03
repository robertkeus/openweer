# OpenWeer

> An open weather platform for the Netherlands, built on KNMI open data.

[openweer.nl](https://openweer.nl) — animated rain radar, per-location 2-hour minute-by-minute rain forecast, current observations, and short-range hourly forecast extending to ~48 hours via HARMONIE-AROME.

OpenWeer is an open-source clone of [buienradar.nl](https://buienradar.nl), powered exclusively by the [KNMI Open Data Platform](https://dataplatform.knmi.nl/) (CC-BY-4.0).

## Status

🚧 **Pre-alpha.** Building publicly, in steps. See [CLAUDE.md](./CLAUDE.md) for engineering rules.

## Architecture (1 minute)

```
   KNMI MQTT  ──►  ingest worker  ──►  raw HDF5/GRIB on disk
                                              │
                                              ▼
                                       tiler worker
                                       (HDF5 → PNG XYZ tiles)
                                              │
                                              ▼
   browser  ◄──  nginx/Caddy  ◄──┬── /tiles/* (static PNG)
                                 ├── /api/*   (FastAPI)
                                 └── /        (React Router v7 SSR)
```

A single VPS, four Docker services, no database. See the [implementation plan](https://github.com/robertkeus/openweer/issues) for milestones.

## Tech stack

| Layer | Choice |
|---|---|
| Backend | Python 3.13 · FastAPI · asyncio · httpx · aiomqtt · h5py · rasterio |
| Frontend | React Router v7 (framework mode) · MapLibre GL · Tailwind · TypeScript |
| Reverse proxy | Caddy (auto-TLS) |
| Deploy | Docker Compose on a single VPS (Hetzner / DigitalOcean) |

## Quickstart

```bash
git clone git@github.com:robertkeus/openweer.git
cd openweer
cp .env.example .env       # edit KNMI_API_KEY
docker compose up
```

Full local-dev instructions land with [Step 6](./CLAUDE.md).

## Development

The `api/` and `web/` packages can be developed independently.

```bash
# Backend
cd api
uv sync --all-extras
uv run pytest
uv run ruff check .

# Frontend (Step 5+)
cd web
npm ci
npm run dev
```

## Attribution

Weather data © [KNMI](https://www.knmi.nl), [CC-BY-4.0](https://creativecommons.org/licenses/by/4.0/). See [DATA_LICENSE.md](./DATA_LICENSE.md).

OpenWeer source code is MIT-licensed. See [LICENSE](./LICENSE).
