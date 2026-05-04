"""FastAPI application factory."""

from __future__ import annotations

from collections.abc import AsyncIterator
from contextlib import asynccontextmanager

from fastapi import FastAPI
from fastapi.staticfiles import StaticFiles
from starlette.middleware.cors import CORSMiddleware
from starlette.middleware.gzip import GZipMiddleware

from openweer import __version__
from openweer.api.dependencies import AppState
from openweer.api.routes import chat, frames, health, rain, weather
from openweer.api.security import SecurityHeadersMiddleware
from openweer.settings import Settings, get_settings


def create_app(settings: Settings | None = None) -> FastAPI:
    """Build a fresh FastAPI app. Pass `settings` for tests; otherwise from env."""
    cfg = settings or get_settings()

    @asynccontextmanager
    async def lifespan(app: FastAPI) -> AsyncIterator[None]:
        app.state.openweer = AppState.build(cfg)
        yield

    app = FastAPI(
        title="OpenWeer API",
        version=__version__,
        description=(
            "Open-source weather data for the Netherlands, powered by KNMI open data (CC-BY-4.0)."
        ),
        docs_url="/api/docs",
        redoc_url=None,
        openapi_url="/api/openapi.json",
        lifespan=lifespan,
        # Lock down redirect behaviour so a stray slash doesn't leak query strings.
        redirect_slashes=False,
    )

    # ---- middleware (outer-most first) ----
    app.add_middleware(SecurityHeadersMiddleware)
    app.add_middleware(GZipMiddleware, minimum_size=1024)
    app.add_middleware(
        CORSMiddleware,
        allow_origins=_cors_origins(cfg),
        allow_credentials=False,
        allow_methods=["GET", "POST"],
        allow_headers=["accept", "accept-language", "content-type"],
        max_age=600,
    )

    # ---- routes ----
    app.include_router(health.router)
    app.include_router(frames.router)
    app.include_router(rain.router)
    app.include_router(weather.router)
    app.include_router(chat.router)

    # ---- /tiles/* static files (dev convenience; Caddy bypasses this in prod) ----
    tiles_dir = cfg.data_dir / "tiles"
    tiles_dir.mkdir(parents=True, exist_ok=True)
    app.mount("/tiles", StaticFiles(directory=tiles_dir, check_dir=False), name="tiles")

    return app


def _cors_origins(settings: Settings) -> list[str]:
    """Origins allowed for browser cross-origin XHR.

    Always include the configured public site, plus localhost dev defaults.
    """
    origins = {settings.public_site_url.rstrip("/")}
    origins.update(
        {
            "http://localhost:5173",
            "http://localhost:3000",
            "http://127.0.0.1:5173",
        }
    )
    return sorted(origins)
