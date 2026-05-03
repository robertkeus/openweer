"""Entry point: ``python -m openweer.ingest``.

Boots the ingest worker for the four configured datasets, using the MQTT
notification key + the open-data REST key from the environment.
"""

from __future__ import annotations

import asyncio
import socket

from openweer._logging import configure_logging, get_logger
from openweer.ingest.storage import IngestStorage
from openweer.ingest.worker import IngestWorker, build_subscriber
from openweer.knmi.client import KnmiClient
from openweer.knmi.datasets import DATASETS
from openweer.settings import get_settings


async def amain() -> None:
    settings = get_settings()
    configure_logging(settings.log_level)
    log = get_logger("openweer.ingest")

    open_data_key = settings.require_open_data_key()
    notification_key = settings.require_notification_key()

    datasets = tuple(DATASETS.values())
    storage = IngestStorage(settings.data_dir)
    client_id = f"openweer-ingest-{socket.gethostname()}"
    subscriber = build_subscriber(notification_key, datasets, client_id=client_id)

    async with KnmiClient.create(open_data_key).session() as client:
        worker = IngestWorker(
            client=client,
            subscriber=subscriber,
            storage=storage,
            datasets=datasets,
        )
        log.info("openweer.ingest.boot", data_dir=str(storage.root))
        await worker.run()


def main() -> None:
    try:
        asyncio.run(amain())
    except KeyboardInterrupt:
        pass


if __name__ == "__main__":
    main()
