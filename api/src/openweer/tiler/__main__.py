"""Entry point: ``python -m openweer.tiler`` — runs the radar tiler worker."""

from __future__ import annotations

import asyncio

from openweer._logging import configure_logging, get_logger
from openweer.settings import get_settings
from openweer.tiler.worker import build_default_worker


async def amain() -> None:
    settings = get_settings()
    configure_logging(settings.log_level)
    log = get_logger("openweer.tiler")
    worker = build_default_worker(settings.data_dir)
    log.info("openweer.tiler.boot", data_dir=str(settings.data_dir))
    await worker.run()


def main() -> None:
    try:
        asyncio.run(amain())
    except KeyboardInterrupt:
        pass


if __name__ == "__main__":
    main()
