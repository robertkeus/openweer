"""Entry point: ``python -m openweer.ingest``.

Boots the ingest worker for the four configured datasets, using the MQTT
notification key + the open-data REST key from the environment.
"""

from __future__ import annotations

import asyncio
import socket

from openweer._logging import configure_logging, get_logger
from openweer.devices.apns import APNsClient, APNsConfig
from openweer.devices.repository import DeviceRepository
from openweer.devices.worker import PusherLoop
from openweer.ingest.storage import IngestStorage
from openweer.ingest.worker import IngestWorker, build_subscriber
from openweer.knmi.client import KnmiClient
from openweer.knmi.datasets import DATASETS
from openweer.settings import Settings, get_settings


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

    repository = DeviceRepository.open(settings.data_dir / "devices.db")
    apns = APNsClient(_apns_config(settings))
    pusher = PusherLoop(
        repository=repository,
        apns=apns,
        storage=storage,
        interval_seconds=settings.pusher_interval_seconds,
        dedupe_window_minutes=settings.pusher_dedupe_window_minutes,
    )

    async with KnmiClient.create(open_data_key).session() as client:
        worker = IngestWorker(
            client=client,
            subscriber=subscriber,
            storage=storage,
            datasets=datasets,
            pusher=pusher,
        )
        log.info(
            "openweer.ingest.boot",
            data_dir=str(storage.root),
            apns_configured=apns.configured,
        )
        try:
            await worker.run()
        finally:
            repository.close()


def _apns_config(settings: Settings) -> APNsConfig | None:
    if (
        settings.apns_key_id is None
        or settings.apns_team_id is None
        or settings.apns_private_key_path is None
    ):
        return None
    return APNsConfig(
        bundle_id=settings.apns_bundle_id,
        key_id=settings.apns_key_id,
        team_id=settings.apns_team_id,
        private_key_path=settings.apns_private_key_path,
        use_sandbox=settings.apns_environment == "sandbox",
    )


def main() -> None:
    try:
        asyncio.run(amain())
    except KeyboardInterrupt:
        pass


if __name__ == "__main__":
    main()
