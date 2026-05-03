"""Structured logging setup. Imported once per process at startup."""

from __future__ import annotations

import logging
import sys
from typing import Any

import structlog

_NOISY_LIBS: tuple[str, ...] = (
    "rasterio",
    "rasterio._env",
    "rasterio._io",
    "rasterio._base",
    "rasterio.env",
    "fiona",
    "fiona._env",
    "h5py",
    "matplotlib",
    "PIL",
)


def configure_logging(level: str = "INFO") -> None:
    """Configure structlog + stdlib logging for JSON output to stdout.

    Quiets verbose third-party libraries to WARNING regardless of our app
    level so DEBUG mode doesn't drown the operator in GDAL chatter.
    """
    log_level = getattr(logging, level.upper(), logging.INFO)
    logging.basicConfig(
        format="%(message)s",
        stream=sys.stdout,
        level=log_level,
    )
    for name in _NOISY_LIBS:
        logging.getLogger(name).setLevel(logging.WARNING)
    structlog.configure(
        processors=[
            structlog.contextvars.merge_contextvars,
            structlog.processors.add_log_level,
            structlog.processors.TimeStamper(fmt="iso", utc=True),
            structlog.processors.StackInfoRenderer(),
            structlog.processors.format_exc_info,
            structlog.processors.JSONRenderer(),
        ],
        wrapper_class=structlog.make_filtering_bound_logger(log_level),
        logger_factory=structlog.PrintLoggerFactory(),
        cache_logger_on_first_use=True,
    )


def get_logger(name: str | None = None, **initial: Any) -> structlog.stdlib.BoundLogger:
    """Return a bound structlog logger. Use the module name by default."""
    logger = structlog.get_logger(name)
    if initial:
        logger = logger.bind(**initial)
    return logger
