"""Pusher loop: every N seconds, evaluate favorites and send pushes.

Wired into `IngestWorker` as a fourth asyncio task. Reads the latest
`radar_forecast` HDF5 via `IngestStorage`, dedupes alerts that were
already pushed in the last window, and uses `APNsClient` to deliver.
"""

from __future__ import annotations

import asyncio
from dataclasses import dataclass
from datetime import UTC, datetime, timedelta
from pathlib import Path

from openweer._logging import get_logger
from openweer.devices.apns import APNsClient
from openweer.devices.evaluator import Alert, evaluate, stale_dedupe_cutoff
from openweer.devices.repository import DeviceRepository
from openweer.ingest.storage import IngestStorage
from openweer.knmi.datasets import get_dataset

log = get_logger(__name__)


@dataclass(slots=True)
class PusherLoop:
    """Owns the periodic evaluate-and-send cycle."""

    repository: DeviceRepository
    apns: APNsClient
    storage: IngestStorage
    interval_seconds: int = 300
    dedupe_window_minutes: int = 30

    async def run(self) -> None:
        """Run forever; cancels propagate through the TaskGroup."""
        log.info(
            "devices.pusher.start",
            interval_s=self.interval_seconds,
            dedupe_window_min=self.dedupe_window_minutes,
            apns_configured=self.apns.configured,
        )
        while True:
            try:
                await self._tick()
            except asyncio.CancelledError:
                raise
            except Exception:
                log.exception("devices.pusher.tick_failed")
            await asyncio.sleep(self.interval_seconds)

    async def _tick(self) -> None:
        hdf5_path = self._latest_nowcast_path()
        if hdf5_path is None:
            log.debug("devices.pusher.skip_no_nowcast")
            return
        devices = await self.repository.iter_devices_with_favorites()
        with_favs = [d for d in devices if d.favorites]
        if not with_favs:
            log.debug("devices.pusher.skip_no_favorites")
            return
        now = datetime.now(UTC)
        alerts = await asyncio.to_thread(
            evaluate, hdf5_path=hdf5_path, devices=with_favs, now=now
        )
        if not alerts:
            log.debug("devices.pusher.no_alerts")
            return
        cutoff = stale_dedupe_cutoff(now, timedelta(minutes=self.dedupe_window_minutes))
        sent = 0
        for alert in alerts:
            if await self.repository.already_sent(
                device_id=alert.device_id,
                favorite_id=alert.favorite.favorite_id,
                dedupe_key=alert.dedupe_key,
                not_before_iso=cutoff,
            ):
                continue
            if await self._deliver(alert):
                sent += 1
        # Keep the push log bounded.
        await self.repository.prune_push_log_older_than(not_before_iso=cutoff)
        log.info("devices.pusher.tick_done", evaluated=len(alerts), sent=sent)

    async def _deliver(self, alert: Alert) -> bool:
        ok = await self.apns.send(alert, on_terminal=self.repository)
        if ok:
            await self.repository.record_push_sent(
                device_id=alert.device_id,
                favorite_id=alert.favorite.favorite_id,
                dedupe_key=alert.dedupe_key,
            )
        return ok

    def _latest_nowcast_path(self) -> Path | None:
        dataset = get_dataset("radar_forecast")
        manifest = self.storage.read_manifest(dataset)
        if manifest is None:
            return None
        path = self.storage.raw_path(dataset, manifest.filename)
        return path if path.exists() else None


__all__ = ["PusherLoop"]
