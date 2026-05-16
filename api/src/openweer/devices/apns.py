"""APNs push sender (JWT auth + HTTP/2).

Wraps `aioapns` so the rest of the codebase doesn't depend on its API.
Failures are classified into:
  - `Unregistered` / `BadDeviceToken` → the device row is deleted so we
    stop spamming a dead token.
  - everything else → logged and swallowed so a single bad push doesn't
    take down the loop.

If APNs config is missing the client is a no-op stub: lets the rest of
the system run in dev without an Apple Developer account.
"""

from __future__ import annotations

from dataclasses import dataclass
from pathlib import Path
from typing import Protocol

from openweer._logging import get_logger
from openweer.devices.evaluator import Alert

log = get_logger(__name__)

# Tokens APNs reports as terminal. We delete the row when we see one.
TERMINAL_REASONS: frozenset[str] = frozenset(
    {
        "BadDeviceToken",
        "Unregistered",
        "DeviceTokenNotForTopic",
    }
)


class DeviceRowDeleter(Protocol):
    async def delete_device(self, device_id: str) -> bool: ...


@dataclass(slots=True, frozen=True)
class APNsConfig:
    bundle_id: str
    key_id: str
    team_id: str
    private_key_path: Path
    use_sandbox: bool


class APNsClient:
    """Sends payloads built from `Alert`s. Subclassed for tests."""

    def __init__(self, config: APNsConfig | None) -> None:
        self._config = config
        self._client = self._build_client(config) if config is not None else None

    @property
    def configured(self) -> bool:
        return self._client is not None

    def _build_client(self, config: APNsConfig) -> object:
        # aioapns 4.x passes `key=` straight into PyJWT, which expects the
        # PEM contents — not a path. Read the .p8 once at boot and hand
        # the string in.
        from aioapns import APNs

        pem = config.private_key_path.read_text(encoding="utf-8")
        return APNs(
            key=pem,
            key_id=config.key_id,
            team_id=config.team_id,
            topic=config.bundle_id,
            use_sandbox=config.use_sandbox,
        )

    async def send(self, alert: Alert, *, on_terminal: DeviceRowDeleter) -> bool:
        """Send one push. Returns True on success, False otherwise."""
        if self._client is None:
            log.info(
                "devices.apns.skipped_no_config",
                device_id=_redact(alert.device_id),
                favorite_id=alert.favorite.favorite_id,
            )
            return False
        payload = build_payload(alert)
        try:
            response = await self._send_with_aioapns(alert.device_id, payload)
        except Exception:
            log.exception(
                "devices.apns.send_failed",
                device_id=_redact(alert.device_id),
                favorite_id=alert.favorite.favorite_id,
            )
            return False
        is_successful = bool(getattr(response, "is_successful", False))
        description = str(getattr(response, "description", "") or "")
        if is_successful:
            return True
        if description in TERMINAL_REASONS:
            log.warning(
                "devices.apns.terminal_token",
                device_id=_redact(alert.device_id),
                reason=description,
            )
            await on_terminal.delete_device(alert.device_id)
            return False
        log.warning(
            "devices.apns.transient_failure",
            device_id=_redact(alert.device_id),
            reason=description,
        )
        return False

    async def _send_with_aioapns(self, token: str, payload: dict[str, object]) -> object:
        from aioapns import NotificationRequest

        request = NotificationRequest(device_token=token, message=payload)
        client = self._client
        assert client is not None  # checked by caller
        send: object = client.send_notification  # type: ignore[attr-defined]
        return await send(request)  # type: ignore[operator]


def build_payload(alert: Alert) -> dict[str, object]:
    """Build the APNs JSON body for a rain alert."""
    return {
        "aps": {
            "alert": {
                "title-loc-key": "push.rain.title",
                "loc-key": "push.rain.body",
                "loc-args": [
                    alert.favorite.label,
                    str(alert.lead_minutes),
                    alert.intensity,
                ],
            },
            "sound": "default",
            "interruption-level": "time-sensitive",
            "thread-id": f"rain-{alert.favorite.favorite_id}",
        },
        "favorite_id": alert.favorite.favorite_id,
        "lead_minutes": alert.lead_minutes,
        "intensity": alert.intensity,
        "mm_per_h": round(alert.mm_per_h, 2),
    }


def _redact(token: str) -> str:
    """Show only the trailing 6 chars so log lines stay greppable but tokens stay private."""
    return f"…{token[-6:]}" if len(token) > 6 else "…"


__all__ = ["APNsClient", "APNsConfig", "DeviceRowDeleter", "build_payload"]
