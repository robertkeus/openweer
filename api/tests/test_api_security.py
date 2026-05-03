"""Security middleware — required headers, CORS, server-banner suppression."""

from __future__ import annotations

from collections.abc import AsyncIterator
from pathlib import Path

import httpx
import pytest
from asgi_lifespan import LifespanManager

from openweer.api.app import create_app
from openweer.settings import Settings


@pytest.fixture
async def client(tmp_path: Path) -> AsyncIterator[httpx.AsyncClient]:
    settings = Settings(_env_file=None, OPENWEER_DATA_DIR=tmp_path)  # type: ignore[call-arg]
    app = create_app(settings=settings)
    async with LifespanManager(app):
        async with httpx.AsyncClient(
            transport=httpx.ASGITransport(app=app), base_url="http://test"
        ) as c:
            yield c


REQUIRED_SECURITY_HEADERS = (
    "Strict-Transport-Security",
    "X-Content-Type-Options",
    "X-Frame-Options",
    "Referrer-Policy",
    "Content-Security-Policy",
    "Permissions-Policy",
)


@pytest.mark.parametrize("header", REQUIRED_SECURITY_HEADERS)
async def test_security_header_present(client: httpx.AsyncClient, header: str) -> None:
    r = await client.get("/api/health")
    assert header in r.headers, f"missing security header: {header}"


async def test_csp_denies_default_sources(client: httpx.AsyncClient) -> None:
    r = await client.get("/api/health")
    csp = r.headers["Content-Security-Policy"]
    assert "default-src 'none'" in csp
    assert "frame-ancestors 'none'" in csp


async def test_no_server_banner(client: httpx.AsyncClient) -> None:
    r = await client.get("/api/health")
    assert "server" not in {k.lower() for k in r.headers}


async def test_cors_only_allows_configured_origins(client: httpx.AsyncClient) -> None:
    r = await client.get(
        "/api/health",
        headers={"Origin": "https://evil.example.com"},
    )
    # The request still succeeds at HTTP level, but the browser would reject due
    # to no Access-Control-Allow-Origin echo.
    assert "access-control-allow-origin" not in {k.lower() for k in r.headers}


async def test_cors_allows_localhost_dev_origin(client: httpx.AsyncClient) -> None:
    r = await client.get(
        "/api/health",
        headers={"Origin": "http://localhost:5173"},
    )
    assert r.headers.get("access-control-allow-origin") == "http://localhost:5173"
