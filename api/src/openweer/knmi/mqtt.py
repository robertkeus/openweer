"""KNMI Notification Service — MQTT 5.0 over WSS/TLS.

Connects to `mqtt.dataplatform.knmi.nl:443` over a WebSocket-over-TLS transport.
Per the KNMI dev portal: username must be the literal string ``"token"``, password
is the Notification Service API key. We use a **stable client_id** so KNMI's QoS-1
offline queue (24 h) buffers events while we're disconnected.
"""

from __future__ import annotations

import json
import ssl
from collections.abc import AsyncIterator
from dataclasses import dataclass, field
from datetime import datetime
from typing import Any

import aiomqtt
from pydantic import BaseModel, ConfigDict, Field

from openweer.knmi.datasets import Dataset

MQTT_HOST = "mqtt.dataplatform.knmi.nl"
MQTT_PORT = 443
MQTT_TRANSPORT = "websockets"
MQTT_USERNAME = "token"  # KNMI convention; the actual secret is the password.
MQTT_VERSION = aiomqtt.ProtocolVersion.V5
DEFAULT_KEEPALIVE = 60
DEFAULT_QOS = 1


class MqttFileEvent(BaseModel):
    """One `created` event for a new KNMI file."""

    model_config = ConfigDict(extra="ignore", frozen=True)

    dataset_name: str = Field(validation_alias="datasetName")
    dataset_version: str = Field(validation_alias="datasetVersion")
    filename: str
    url: str | None = None
    created: datetime | None = None


@dataclass(slots=True)
class KnmiMqttSubscriber:
    """Async MQTT subscriber for KNMI file-event notifications."""

    api_key: str
    client_id: str
    datasets: tuple[Dataset, ...]
    keepalive: int = DEFAULT_KEEPALIVE
    qos: int = DEFAULT_QOS
    _tls_context: ssl.SSLContext = field(default_factory=ssl.create_default_context)

    def __post_init__(self) -> None:
        if not self.api_key:
            raise ValueError("KnmiMqttSubscriber requires a non-empty api_key")
        if not self.client_id:
            raise ValueError("KnmiMqttSubscriber requires a stable client_id")
        if not self.datasets:
            raise ValueError("KnmiMqttSubscriber requires at least one dataset")

    @property
    def topics(self) -> tuple[str, ...]:
        return tuple(d.mqtt_topic for d in self.datasets)

    async def stream(self) -> AsyncIterator[MqttFileEvent]:
        """Yield file events forever. Caller is responsible for cancellation."""
        async with aiomqtt.Client(
            hostname=MQTT_HOST,
            port=MQTT_PORT,
            transport=MQTT_TRANSPORT,
            tls_context=self._tls_context,
            protocol=MQTT_VERSION,
            identifier=self.client_id,
            username=MQTT_USERNAME,
            password=self.api_key,
            keepalive=self.keepalive,
        ) as client:
            for topic in self.topics:
                await client.subscribe(topic, qos=self.qos)
            async for message in client.messages:
                event = parse_event(message.payload)
                if event is not None:
                    yield event


def parse_event(payload: Any) -> MqttFileEvent | None:
    """Parse a KNMI MQTT payload into a typed event, returning None on garbage.

    Keeping this pure makes it trivially unit-testable without the network.
    """
    raw = _coerce_to_text(payload)
    if raw is None:
        return None
    try:
        body = json.loads(raw)
    except json.JSONDecodeError:
        return None
    if not isinstance(body, dict):
        return None
    data = body.get("data") if isinstance(body.get("data"), dict) else body
    try:
        return MqttFileEvent.model_validate(data)
    except (TypeError, ValueError):
        return None


def _coerce_to_text(payload: Any) -> str | None:
    if isinstance(payload, str):
        return payload
    if isinstance(payload, (bytes, bytearray)):
        try:
            return payload.decode("utf-8")
        except UnicodeDecodeError:
            return None
    return None
