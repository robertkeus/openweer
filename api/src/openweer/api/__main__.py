"""Entry point: ``python -m openweer.api`` — runs uvicorn."""

from __future__ import annotations

import uvicorn

from openweer._logging import configure_logging
from openweer.settings import get_settings


def main() -> None:
    settings = get_settings()
    configure_logging(settings.log_level)
    uvicorn.run(
        "openweer.api.app:create_app",
        factory=True,
        host="0.0.0.0",  # noqa: S104 — bound by Docker/Caddy in prod, local-only in dev.
        port=8000,
        log_config=None,
        proxy_headers=True,
        forwarded_allow_ips="*",
        # Suppress the `server: uvicorn` banner — minor info-leak avoidance.
        server_header=False,
        date_header=True,
    )


if __name__ == "__main__":
    main()
