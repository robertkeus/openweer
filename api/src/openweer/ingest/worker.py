"""Ingest worker — combines KNMI MQTT push with an HTTP polling fallback.

Architecture:
  - One asyncio TaskGroup runs three coroutines concurrently:
      1. `_mqtt_loop`        — subscribes to `created` for every configured dataset.
      2. `_polling_loop`     — every `polling_interval_s`, lists newest file per
                                dataset over HTTPS and ingests if our manifest is
                                stale (covers MQTT outages and bootstrap).
      3. `_retention_loop`   — every 5 min, deletes raw files older than retention.
  - Ingestion is idempotent: if the file is already on disk we skip download.

Failures in any single ingest are logged and swallowed so the worker keeps running.
"""

from __future__ import annotations

import asyncio
from collections.abc import Iterable
from dataclasses import dataclass

from openweer._logging import get_logger
from openweer.ingest.storage import IngestStorage, ManifestEntry
from openweer.knmi.client import KnmiClient, KnmiClientError
from openweer.knmi.datasets import Dataset, find_dataset
from openweer.knmi.mqtt import KnmiMqttSubscriber, MqttFileEvent

DEFAULT_POLLING_INTERVAL_S = 60.0
DEFAULT_RETENTION_HOURS = 3.0
DEFAULT_RETENTION_SWEEP_INTERVAL_S = 300.0

log = get_logger(__name__)


@dataclass(slots=True)
class IngestWorker:
    """Drives KNMI ingestion from MQTT events + HTTP polling fallback."""

    client: KnmiClient
    subscriber: KnmiMqttSubscriber
    storage: IngestStorage
    datasets: tuple[Dataset, ...]
    polling_interval_s: float = DEFAULT_POLLING_INTERVAL_S
    retention_hours: float = DEFAULT_RETENTION_HOURS
    retention_sweep_interval_s: float = DEFAULT_RETENTION_SWEEP_INTERVAL_S

    async def run(self) -> None:
        """Run all loops concurrently until cancelled."""
        log.info(
            "ingest.start",
            datasets=[d.key for d in self.datasets],
            polling_interval_s=self.polling_interval_s,
            retention_hours=self.retention_hours,
        )
        async with asyncio.TaskGroup() as tg:
            tg.create_task(self._mqtt_loop(), name="ingest.mqtt")
            tg.create_task(self._polling_loop(), name="ingest.poll")
            tg.create_task(self._retention_loop(), name="ingest.gc")

    # ---- loops ----

    async def _mqtt_loop(self) -> None:
        """Forever: listen for `created` events and ingest each one."""
        while True:
            try:
                async for event in self.subscriber.stream():
                    await self._handle_event(event)
            except asyncio.CancelledError:
                raise
            except Exception:
                log.exception("ingest.mqtt.error_reconnecting_in_5s")
                await asyncio.sleep(5.0)

    async def _polling_loop(self) -> None:
        """Forever: every `polling_interval_s`, ingest the newest file per dataset."""
        while True:
            for dataset in self.datasets:
                try:
                    await self._poll_one(dataset)
                except Exception:
                    log.exception("ingest.poll.dataset_failed", dataset=dataset.key)
            await asyncio.sleep(self.polling_interval_s)

    async def _retention_loop(self) -> None:
        """Forever: prune raw files older than `retention_hours`."""
        max_age = self.retention_hours * 3600.0
        while True:
            for dataset in self.datasets:
                removed = self.storage.prune_raw_older_than(dataset, max_age)
                if removed:
                    log.info("ingest.gc.pruned", dataset=dataset.key, removed=removed)
            await asyncio.sleep(self.retention_sweep_interval_s)

    # ---- ingestion ----

    async def _handle_event(self, event: MqttFileEvent) -> None:
        dataset = find_dataset(event.dataset_name, event.dataset_version)
        if dataset is None:
            log.debug(
                "ingest.event.unknown_dataset",
                dataset_name=event.dataset_name,
                dataset_version=event.dataset_version,
            )
            return
        if dataset not in self.datasets:
            return
        await self._ingest(dataset, event.filename)

    async def _poll_one(self, dataset: Dataset) -> None:
        files = await self.client.list_files(dataset, max_keys=1)
        if not files:
            return
        latest = files[0]
        manifest = self.storage.read_manifest(dataset)
        if manifest is not None and manifest.filename == latest.filename:
            return
        await self._ingest(dataset, latest.filename)

    async def _ingest(self, dataset: Dataset, filename: str) -> None:
        if self.storage.already_ingested(dataset, filename):
            log.debug("ingest.skip_existing", dataset=dataset.key, filename=filename)
            return

        log.info("ingest.start_file", dataset=dataset.key, filename=filename)
        try:
            url = await self.client.get_download_url(dataset, filename)
            bytes_written = await self.storage.write_raw_file(
                dataset, filename, self.client.stream_download(url)
            )
        except KnmiClientError:
            log.exception("ingest.download_failed", dataset=dataset.key, filename=filename)
            return

        entry = ManifestEntry(
            dataset_name=dataset.name,
            dataset_version=dataset.version,
            filename=filename,
            bytes_written=bytes_written,
        )
        self.storage.write_manifest(dataset, entry)
        log.info("ingest.done", dataset=dataset.key, filename=filename, bytes=bytes_written)


def build_subscriber(
    api_key: str, datasets: Iterable[Dataset], client_id: str
) -> KnmiMqttSubscriber:
    return KnmiMqttSubscriber(
        api_key=api_key,
        client_id=client_id,
        datasets=tuple(datasets),
    )
