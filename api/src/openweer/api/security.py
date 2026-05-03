"""HTTP security middleware (OWASP A05).

Adds the headers every modern web app should emit, with a CSP tight enough
that an injected `<script>` cannot exfiltrate to an attacker-controlled host.
"""

from __future__ import annotations

from collections.abc import Awaitable, Callable

from starlette.middleware.base import BaseHTTPMiddleware
from starlette.requests import Request
from starlette.responses import Response

# A locked-down baseline for the JSON API. The web app (web/) sets its own,
# slightly looser CSP via Caddy/nginx because it serves HTML + WebGL.
_DEFAULT_CSP = "default-src 'none'; frame-ancestors 'none'; base-uri 'none'; form-action 'none'"

_DEFAULT_HEADERS: dict[str, str] = {
    "Strict-Transport-Security": "max-age=63072000; includeSubDomains; preload",
    "X-Content-Type-Options": "nosniff",
    "X-Frame-Options": "DENY",
    "Referrer-Policy": "strict-origin-when-cross-origin",
    "Permissions-Policy": "geolocation=(), camera=(), microphone=(), payment=()",
    "Cross-Origin-Resource-Policy": "same-site",
    "Cross-Origin-Opener-Policy": "same-origin",
    "Content-Security-Policy": _DEFAULT_CSP,
}


class SecurityHeadersMiddleware(BaseHTTPMiddleware):
    """Inject conservative security headers into every response."""

    def __init__(self, app, headers: dict[str, str] | None = None) -> None:
        super().__init__(app)
        self._headers = headers if headers is not None else _DEFAULT_HEADERS

    async def dispatch(
        self,
        request: Request,
        call_next: Callable[[Request], Awaitable[Response]],
    ) -> Response:
        response = await call_next(request)
        for name, value in self._headers.items():
            response.headers.setdefault(name, value)
        # Hide the framework banner (Starlette's MutableHeaders supports `del`).
        if "server" in response.headers:
            del response.headers["server"]
        return response


__all__ = ["SecurityHeadersMiddleware"]
