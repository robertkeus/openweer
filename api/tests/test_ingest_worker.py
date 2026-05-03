"""IngestWorker — happy-path with mocked client + MQTT, no real network."""

from __future__ import annotations

from collections.abc import AsyncIterator
from dataclasses import dataclass, field
from pathlib import Path
from typing import Any

from openweer.ingest.storage import IngestStorage
from openweer.ingest.worker import IngestWorker
from openweer.knmi.client import KnmiClient, KnmiFile
from openweer.knmi.datasets import Dataset, get_dataset
from openweer.knmi.mqtt import KnmiMqttSubscriber, MqttFileEvent

RADAR = get_dataset("radar_forecast")


@dataclass
class FakeKnmiClient:
    """Test double that records calls and returns canned download bytes."""

    list_files_response: list[KnmiFile] = field(default_factory=list)
    download_url_response: str = "https://knmi.s3.amazonaws.com/file"
    download_chunks: list[bytes] = field(default_factory=lambda: [b"hello", b"world"])
    list_calls: list[Dataset] = field(default_factory=list)
    download_url_calls: list[tuple[Dataset, str]] = field(default_factory=list)

    async def list_files(self, dataset: Dataset, **_: Any) -> list[KnmiFile]:
        self.list_calls.append(dataset)
        return self.list_files_response

    async def get_download_url(self, dataset: Dataset, filename: str) -> str:
        self.download_url_calls.append((dataset, filename))
        return self.download_url_response

    async def stream_download(self, url: str) -> AsyncIterator[bytes]:
        for c in self.download_chunks:
            yield c


def _make_worker(
    tmp_path: Path,
    client: FakeKnmiClient,
    subscriber: KnmiMqttSubscriber | None = None,
) -> tuple[IngestWorker, IngestStorage]:
    storage = IngestStorage(tmp_path)
    sub = subscriber or KnmiMqttSubscriber(api_key="x", client_id="t", datasets=(RADAR,))
    worker = IngestWorker(
        client=client,  # type: ignore[arg-type]
        subscriber=sub,
        storage=storage,
        datasets=(RADAR,),
    )
    return worker, storage


async def test_handle_event_downloads_and_writes_manifest(tmp_path: Path) -> None:
    client = FakeKnmiClient(download_chunks=[b"abc", b"def"])
    worker, storage = _make_worker(tmp_path, client)

    event = MqttFileEvent(
        datasetName=RADAR.name,
        datasetVersion=RADAR.version,
        filename="RAD_NL25_RAC_FM_202604031200.h5",
    )
    await worker._handle_event(event)

    target = storage.raw_path(RADAR, event.filename)
    assert target.read_bytes() == b"abcdef"

    manifest = storage.read_manifest(RADAR)
    assert manifest is not None
    assert manifest.filename == event.filename
    assert manifest.bytes_written == 6


async def test_handle_event_ignores_unknown_dataset(tmp_path: Path) -> None:
    client = FakeKnmiClient()
    worker, _ = _make_worker(tmp_path, client)

    await worker._handle_event(
        MqttFileEvent(datasetName="some_other_dataset", datasetVersion="1.0", filename="x.h5")
    )
    assert client.download_url_calls == []


async def test_handle_event_skips_already_ingested_file(tmp_path: Path) -> None:
    client = FakeKnmiClient()
    worker, storage = _make_worker(tmp_path, client)

    raw = storage.raw_path(RADAR, "already.h5")
    raw.parent.mkdir(parents=True, exist_ok=True)
    raw.write_bytes(b"existing")

    await worker._handle_event(
        MqttFileEvent(datasetName=RADAR.name, datasetVersion=RADAR.version, filename="already.h5")
    )
    assert client.download_url_calls == []
    assert raw.read_bytes() == b"existing"


async def test_poll_one_ingests_when_manifest_is_stale(tmp_path: Path) -> None:
    new_file = KnmiFile.model_validate(
        {
            "filename": "RAD_NL25_RAC_FM_202604031200.h5",
            "size": 100,
            "lastModified": "2026-04-03T12:00:00Z",
            "created": "2026-04-03T12:00:01Z",
        }
    )
    client = FakeKnmiClient(list_files_response=[new_file])
    worker, storage = _make_worker(tmp_path, client)

    await worker._poll_one(RADAR)
    assert client.download_url_calls == [(RADAR, new_file.filename)]
    assert storage.read_manifest(RADAR) is not None


async def test_poll_one_is_noop_when_manifest_matches_latest(tmp_path: Path) -> None:
    new_file = KnmiFile.model_validate(
        {
            "filename": "current.h5",
            "size": 100,
            "lastModified": "2026-04-03T12:00:00Z",
            "created": "2026-04-03T12:00:01Z",
        }
    )
    client = FakeKnmiClient(list_files_response=[new_file])
    worker, storage = _make_worker(tmp_path, client)

    # Pre-write the manifest so the worker thinks current.h5 is already ingested.
    raw = storage.raw_path(RADAR, "current.h5")
    raw.parent.mkdir(parents=True, exist_ok=True)
    raw.write_bytes(b"x")
    from openweer.ingest.storage import ManifestEntry

    storage.write_manifest(
        RADAR,
        ManifestEntry(
            dataset_name=RADAR.name,
            dataset_version=RADAR.version,
            filename="current.h5",
            bytes_written=1,
        ),
    )

    await worker._poll_one(RADAR)
    assert client.download_url_calls == []


def test_kniclient_protocol_is_satisfied_by_real_client() -> None:
    """Compile-time-ish: ensure the real KnmiClient has the methods we call."""
    for attr in ("list_files", "get_download_url", "stream_download"):
        assert hasattr(KnmiClient, attr), f"KnmiClient missing {attr}"
