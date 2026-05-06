"""Shared HTTP error helpers used across route modules.

Keeps the SSRF-allowlist defence-in-depth pattern consistent without each
route re-implementing the `UrlNotAllowedError → HTTPException` conversion.
"""

from __future__ import annotations

from collections.abc import Iterator
from contextlib import contextmanager
from typing import NoReturn

from fastapi import HTTPException, status

from openweer.knmi._security import UrlNotAllowedError


def raise_upstream_blocked(detail: str) -> NoReturn:
    """Raise a clean 502 in Dutch when an outbound URL was refused (OWASP A10)."""
    raise HTTPException(status_code=status.HTTP_502_BAD_GATEWAY, detail=detail)


@contextmanager
def upstream_url_guard(detail: str) -> Iterator[None]:
    """Convert any `UrlNotAllowedError` raised inside the block into a 502."""
    try:
        yield
    except UrlNotAllowedError:
        raise_upstream_blocked(detail)
