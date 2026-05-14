# OpenWeer — API

The Python backend for [openweer.nl](https://openweer.nl): ingests KNMI open data over MQTT, renders raster tiles, and serves a small JSON API to the web and iOS clients.

For the project overview, license, and architecture diagram see the [root README](../README.md) and [CONTRIBUTING.md](../CONTRIBUTING.md).

## Stack

Python 3.12+ · FastAPI · asyncio · httpx · aiomqtt · h5py · rasterio · Pillow · structlog · Pydantic v2.

## Layout

```
src/openweer/
├── settings.py        # pydantic-settings, loaded from .env
├── _logging.py        # structlog JSON config
├── knmi/              # KNMI Open Data Platform client (HTTPS + MQTT)
│   ├── client.py        REST + dataset downloads
│   ├── mqtt.py          MQTT notification subscriber
│   ├── datasets.py      dataset/version registry
│   └── _security.py     SSRF allowlist + path-traversal guards
├── ingest/            # MQTT → raw HDF5/GRIB on disk (atomic-mv)
├── tiler/             # raw files → PNG XYZ tiles
│   ├── radar_hdf5.py    KNMI radar nowcast
│   ├── harmonie_grib.py HARMONIE-AROME +48h
│   ├── colormap.py      KNMI dBZ colour ramp
│   ├── manifest.py      published-frames index
│   └── pipeline.py      orchestration
├── forecast/          # per-location rain timeseries (2h nowcast + HARMONIE)
└── api/               # FastAPI app
    ├── app.py           lifespan, middleware, CSP, rate limit
    ├── dependencies.py  shared deps
    ├── security.py      input validation, NL bbox check
    └── routes/          health, frames, rain, weather, forecast, chat
```

## Local development

Requires Python 3.12+ and [`uv`](https://docs.astral.sh/uv/).

```bash
cd api
uv sync --all-extras
cp ../.env.example ../.env       # add KNMI_API_KEY
uv run uvicorn openweer.api.app:app --reload --port 8000
```

The ingest and tiler workers run as separate processes (the same way `docker compose` orchestrates them):

```bash
uv run python -m openweer.ingest    # KNMI MQTT → data/raw/
uv run python -m openweer.tiler     # data/raw/ → data/tiles/
```

For most frontend work, `docker compose up api ingest tiler` from the repo root is simpler than running them by hand.

## Endpoints

All endpoints are public, read-only, JSON. Rate-limited at the Caddy edge in production.

| Path | Purpose |
|---|---|
| `GET /api/health` | liveness; checks dependencies and last KNMI frame age |
| `GET /api/frames` | timeline of published radar/HARMONIE frames |
| `GET /api/rain` | per-location 2-hour minute-by-minute rain forecast |
| `GET /api/weather` | current observations for a coordinate |
| `GET /api/forecast` | short-range hourly forecast (HARMONIE +48h) |
| `POST /api/chat` | AI chat over weather context (Anthropic) |
| `GET /tiles/{layer}/{z}/{x}/{y}.png` | XYZ tiles, served by Caddy directly |

Coordinates must fall inside the NL bbox; filenames are validated against path traversal. See [`api/security.py`](src/openweer/api/security.py) and the OWASP commitments in [`../CLAUDE.md`](../CLAUDE.md).

## Scripts

```bash
uv run pytest                # full test suite (~14s, 158 tests)
uv run ruff check .          # lint
uv run ruff format .         # format
uv run mypy src              # type-check (strict)
```

All four run in CI on every push — see [`../.github/workflows/ci.yml`](../.github/workflows/ci.yml).

## Production

Built and run via [`Dockerfile`](Dockerfile) under [`../docker-compose.yml`](../docker-compose.yml). Operations docs (first deploy, logs, rollback, disk cleanup) live in [`../deploy/README.md`](../deploy/README.md).
