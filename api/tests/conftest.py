"""Shared pytest fixtures."""

from __future__ import annotations

from collections.abc import Iterator

import pytest

from openweer.settings import reset_settings_cache


@pytest.fixture(autouse=True)
def _isolate_settings(monkeypatch: pytest.MonkeyPatch) -> Iterator[None]:
    """Each test starts with a fresh settings cache and no real KNMI env vars."""
    for var in (
        "KNMI_OPEN_DATA_API_KEY",
        "KNMI_NOTIFICATION_API_KEY",
        "KNMI_EDR_API_KEY",
        "KNMI_WMS_API_KEY",
        "OPENWEER_GREENPT_API_KEY",
        "OPENWEER_GREENPT_MODEL",
    ):
        monkeypatch.delenv(var, raising=False)
    reset_settings_cache()
    yield
    reset_settings_cache()
