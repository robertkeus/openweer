"""Settings tests — secrets handling and required-key behaviour."""

from __future__ import annotations

import pytest

from openweer.settings import Settings, reset_settings_cache


def test_require_open_data_key_raises_when_unset(monkeypatch: pytest.MonkeyPatch) -> None:
    reset_settings_cache()
    settings = Settings(_env_file=None)
    with pytest.raises(RuntimeError, match="KNMI_OPEN_DATA_API_KEY is not configured"):
        settings.require_open_data_key()


def test_require_open_data_key_returns_value_when_set(monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.setenv("KNMI_OPEN_DATA_API_KEY", "abc-123")
    reset_settings_cache()
    settings = Settings(_env_file=None)
    assert settings.require_open_data_key() == "abc-123"


def test_each_service_has_its_own_required_accessor(monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.setenv("KNMI_OPEN_DATA_API_KEY", "od")
    monkeypatch.setenv("KNMI_NOTIFICATION_API_KEY", "no")
    monkeypatch.setenv("KNMI_EDR_API_KEY", "ed")
    monkeypatch.setenv("KNMI_WMS_API_KEY", "wm")
    reset_settings_cache()
    settings = Settings(_env_file=None)

    assert settings.require_open_data_key() == "od"
    assert settings.require_notification_key() == "no"
    assert settings.require_edr_key() == "ed"
    assert settings.require_wms_key() == "wm"


def test_secret_str_is_not_repr_leaked() -> None:
    settings = Settings(_env_file=None, KNMI_OPEN_DATA_API_KEY="supersecret")
    text = repr(settings)
    assert "supersecret" not in text
