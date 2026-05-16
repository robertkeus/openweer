"""APNs client wrapper — terminal-token handling, payload structure, no-config skip."""

from __future__ import annotations

from dataclasses import dataclass
from datetime import UTC, datetime
from typing import Any

import pytest

from openweer.devices.apns import APNsClient, build_payload
from openweer.devices.evaluator import Alert
from openweer.devices.models import AlertPrefs, Favorite


def _alert(token: str = "deadbeef" * 8) -> Alert:
    favorite = Favorite(
        favorite_id=1,
        label="Home",
        latitude=52.37,
        longitude=4.89,
        alert_prefs=AlertPrefs(),
        created_at=datetime.now(UTC),
    )
    return Alert(
        device_id=token,
        favorite=favorite,
        lead_minutes=15,
        intensity="moderate",
        mm_per_h=2.1,
        dedupe_key="1:2026-05-16T14:15:00:moderate",
        language="nl",
    )


@dataclass
class FakeDeleter:
    deleted: list[str]

    async def delete_device(self, device_id: str) -> bool:
        self.deleted.append(device_id)
        return True


@dataclass
class FakeApnsResponse:
    is_successful: bool
    description: str = ""


class _SendStub:
    def __init__(self, response: FakeApnsResponse) -> None:
        self.response = response
        self.calls: list[tuple[str, dict[str, Any]]] = []

    async def __call__(self, token: str, payload: dict[str, Any]) -> FakeApnsResponse:
        self.calls.append((token, payload))
        return self.response


def test_build_payload_shape_nl() -> None:
    payload = build_payload(_alert())
    aps = payload["aps"]
    assert aps["alert"]["title"] == "Regen in aantocht"
    assert aps["alert"]["body"] == "Bij Home start over 15 min matige regen."
    assert aps["interruption-level"] == "time-sensitive"
    assert payload["intensity"] == "moderate"
    assert payload["lead_minutes"] == 15


def test_build_payload_shape_en() -> None:
    # Same alert but with the device registered as English.
    favorite = Favorite(
        favorite_id=1,
        label="Home",
        latitude=52.37,
        longitude=4.89,
        alert_prefs=AlertPrefs(),
        created_at=datetime.now(UTC),
    )
    alert = Alert(
        device_id="x" * 64,
        favorite=favorite,
        lead_minutes=30,
        intensity="heavy",
        mm_per_h=5.0,
        dedupe_key="k",
        language="en",
    )
    aps = build_payload(alert)["aps"]
    assert aps["alert"]["title"] == "Rain incoming"
    assert aps["alert"]["body"] == "At Home, heavy rain starts in 30 min."


def test_build_payload_falls_back_to_nl_for_unknown_language() -> None:
    favorite = Favorite(
        favorite_id=1,
        label="Home",
        latitude=52.37,
        longitude=4.89,
        alert_prefs=AlertPrefs(),
        created_at=datetime.now(UTC),
    )
    alert = Alert(
        device_id="x" * 64,
        favorite=favorite,
        lead_minutes=15,
        intensity="moderate",
        mm_per_h=2.1,
        dedupe_key="k",
        language="zz",  # unknown
    )
    assert build_payload(alert)["aps"]["alert"]["title"] == "Regen in aantocht"


async def test_no_config_is_a_noop() -> None:
    client = APNsClient(config=None)
    deleter = FakeDeleter(deleted=[])
    ok = await client.send(_alert(), on_terminal=deleter)
    assert ok is False
    assert deleter.deleted == []


async def test_terminal_token_triggers_delete(monkeypatch: pytest.MonkeyPatch) -> None:
    client = APNsClient(config=None)
    # Pretend the client is configured.
    monkeypatch.setattr(client, "_client", object())
    stub = _SendStub(FakeApnsResponse(is_successful=False, description="BadDeviceToken"))
    monkeypatch.setattr(client, "_send_with_aioapns", stub)
    deleter = FakeDeleter(deleted=[])
    token = "f" * 64
    ok = await client.send(_alert(token=token), on_terminal=deleter)
    assert ok is False
    assert deleter.deleted == [token]


async def test_transient_failure_does_not_delete(monkeypatch: pytest.MonkeyPatch) -> None:
    client = APNsClient(config=None)
    monkeypatch.setattr(client, "_client", object())
    stub = _SendStub(FakeApnsResponse(is_successful=False, description="InternalServerError"))
    monkeypatch.setattr(client, "_send_with_aioapns", stub)
    deleter = FakeDeleter(deleted=[])
    ok = await client.send(_alert(), on_terminal=deleter)
    assert ok is False
    assert deleter.deleted == []


async def test_successful_send_returns_true(monkeypatch: pytest.MonkeyPatch) -> None:
    client = APNsClient(config=None)
    monkeypatch.setattr(client, "_client", object())
    stub = _SendStub(FakeApnsResponse(is_successful=True))
    monkeypatch.setattr(client, "_send_with_aioapns", stub)
    deleter = FakeDeleter(deleted=[])
    ok = await client.send(_alert(), on_terminal=deleter)
    assert ok is True
    assert len(stub.calls) == 1
