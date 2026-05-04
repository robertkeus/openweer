"""Centralised configuration loaded from environment / .env file.

Every KNMI service has its own key, all consumed as a bare `Authorization: <key>`
header (or as the MQTT connection password). Keys live in environment variables
only — never in source.
"""

from __future__ import annotations

from pathlib import Path

from pydantic import Field, SecretStr
from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    """Runtime configuration for the OpenWeer Python services."""

    model_config = SettingsConfigDict(
        env_file=(".env", "../.env"),
        env_file_encoding="utf-8",
        extra="ignore",
    )

    # KNMI service-specific keys.
    knmi_open_data_api_key: SecretStr = Field(
        default=SecretStr(""),
        validation_alias="KNMI_OPEN_DATA_API_KEY",
    )
    knmi_notification_api_key: SecretStr = Field(
        default=SecretStr(""),
        validation_alias="KNMI_NOTIFICATION_API_KEY",
    )
    knmi_edr_api_key: SecretStr = Field(
        default=SecretStr(""),
        validation_alias="KNMI_EDR_API_KEY",
    )
    knmi_wms_api_key: SecretStr = Field(
        default=SecretStr(""),
        validation_alias="KNMI_WMS_API_KEY",
    )

    # GreenPT (LLM provider) — used by the /api/chat proxy.
    greenpt_api_key: SecretStr = Field(
        default=SecretStr(""),
        validation_alias="OPENWEER_GREENPT_API_KEY",
    )
    greenpt_model: str = Field(
        default="gemma4",
        validation_alias="OPENWEER_GREENPT_MODEL",
    )

    data_dir: Path = Field(
        default=Path("./data"),
        validation_alias="OPENWEER_DATA_DIR",
    )
    public_site_url: str = Field(
        default="https://openweer.nl",
        validation_alias="PUBLIC_SITE_URL",
    )
    log_level: str = Field(default="INFO", validation_alias="OPENWEER_LOG_LEVEL")

    # ---- accessors that surface the raw key only at the I/O boundary ----

    def require_open_data_key(self) -> str:
        return _require(self.knmi_open_data_api_key, "KNMI_OPEN_DATA_API_KEY")

    def require_notification_key(self) -> str:
        return _require(self.knmi_notification_api_key, "KNMI_NOTIFICATION_API_KEY")

    def require_edr_key(self) -> str:
        return _require(self.knmi_edr_api_key, "KNMI_EDR_API_KEY")

    def require_wms_key(self) -> str:
        return _require(self.knmi_wms_api_key, "KNMI_WMS_API_KEY")

    def require_greenpt_key(self) -> str:
        return _require(self.greenpt_api_key, "OPENWEER_GREENPT_API_KEY")


def _require(secret: SecretStr, env_name: str) -> str:
    value = secret.get_secret_value()
    if not value:
        raise RuntimeError(f"{env_name} is not configured. Set it in the environment or .env file.")
    return value


_settings: Settings | None = None


def get_settings() -> Settings:
    """Process-wide settings singleton."""
    global _settings
    if _settings is None:
        _settings = Settings()
    return _settings


def reset_settings_cache() -> None:
    """Test hook: drop the cached settings so the next get_settings() re-reads env."""
    global _settings
    _settings = None
