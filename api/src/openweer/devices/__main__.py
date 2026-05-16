"""CLI: ``python -m openweer.devices``.

Two subcommands, both meant for operators verifying push delivery:

  send-test    fire a single push to a device token, bypassing the evaluator
  list         print the devices + favorites currently in the DB

Both load `Settings` from the environment / `.env` like the rest of the
services, so the same `APNS_*` vars that power the pusher loop power
these commands. No new config to manage.
"""

from __future__ import annotations

import argparse
import asyncio
import sys
from datetime import UTC, datetime
from typing import cast

from openweer._logging import configure_logging
from openweer.devices.apns import APNsClient, APNsConfig
from openweer.devices.evaluator import Alert
from openweer.devices.models import AlertPrefs, Favorite, Intensity, LeadTime
from openweer.devices.repository import DeviceRepository
from openweer.settings import Settings, get_settings


def main() -> None:
    parser = argparse.ArgumentParser(prog="openweer.devices")
    sub = parser.add_subparsers(dest="cmd", required=True)

    send = sub.add_parser("send-test", help="Send a one-off test push to a device token.")
    send.add_argument("--token", required=True, help="APNs device token (hex).")
    send.add_argument("--label", default="Test", help="Label shown in the push body.")
    send.add_argument(
        "--lead", type=int, default=15, choices=[15, 30, 60], help="Minutes ahead."
    )
    send.add_argument(
        "--intensity",
        default="moderate",
        choices=["light", "moderate", "heavy"],
        help="Intensity class.",
    )

    sub.add_parser("list", help="List devices + favorites in the local DB.")

    args = parser.parse_args()
    settings = get_settings()
    configure_logging(settings.log_level)

    if args.cmd == "send-test":
        asyncio.run(_send_test(settings, args.token, args.label, args.lead, args.intensity))
    elif args.cmd == "list":
        asyncio.run(_list_devices(settings))


async def _send_test(
    settings: Settings, token: str, label: str, lead: int, intensity: str
) -> None:
    config = _apns_config(settings)
    if config is None:
        print(
            "APNs not configured — set APNS_KEY_ID, APNS_TEAM_ID, APNS_PRIVATE_KEY_PATH.",
            file=sys.stderr,
        )
        sys.exit(2)
    client = APNsClient(config)

    favorite = Favorite(
        favorite_id=0,
        label=label,
        latitude=52.37,
        longitude=4.89,
        alert_prefs=AlertPrefs(),
        created_at=datetime.now(UTC),
    )
    alert = Alert(
        device_id=token,
        favorite=favorite,
        lead_minutes=lead,
        intensity=cast(Intensity, intensity),
        mm_per_h=2.1,
        dedupe_key=f"test:{datetime.now(UTC).isoformat()}",
        language="nl",
    )

    repository = DeviceRepository.open(settings.data_dir / "devices.db")
    try:
        ok = await client.send(alert, on_terminal=repository)
    finally:
        repository.close()
    if ok:
        print(f"Push delivered to ...{token[-6:]}.")
    else:
        print(f"Push NOT delivered to ...{token[-6:]} — see logs above.", file=sys.stderr)
        sys.exit(1)


async def _list_devices(settings: Settings) -> None:
    repository = DeviceRepository.open(settings.data_dir / "devices.db")
    try:
        devices = await repository.iter_devices_with_favorites()
    finally:
        repository.close()
    if not devices:
        print("(no devices registered)")
        return
    for d in devices:
        print(f"device ...{d.device_id[-6:]}  lang={d.language}  favs={len(d.favorites)}")
        for f in d.favorites:
            qhs = f.alert_prefs.quiet_hours_start
            qhe = f.alert_prefs.quiet_hours_end
            quiet = f" quiet={qhs:02d}-{qhe:02d}" if qhs is not None and qhe is not None else ""
            print(
                f"  • #{f.favorite_id} {f.label:<20} "
                f"({f.latitude:.2f},{f.longitude:.2f}) "
                f"lead={f.alert_prefs.lead_time_min}m "
                f"thr={f.alert_prefs.threshold}{quiet}"
            )


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


if __name__ == "__main__":
    main()
