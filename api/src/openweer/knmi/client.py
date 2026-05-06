"""Async HTTP client for the KNMI Open Data API.

Authentication: a bare `Authorization: <key>` header (no `Bearer`, no `X-API-Key`).
All outbound URLs are validated against the SSRF allowlist before dispatch.
Streamed downloads are verified against `Content-MD5` or `ETag` (OWASP A08).
"""

from __future__ import annotations

import base64
import binascii
import hashlib
import re
from collections.abc import AsyncIterator
from contextlib import asynccontextmanager
from dataclasses import dataclass
from datetime import datetime
from typing import Any, Self

import httpx
from pydantic import BaseModel, ConfigDict, Field

from openweer._logging import get_logger
from openweer.knmi._security import assert_download_url, assert_knmi_api_url
from openweer.knmi.datasets import Dataset

API_BASE_URL = "https://api.dataplatform.knmi.nl/open-data/v1"
_FILENAME_RE = re.compile(r"^[A-Za-z0-9._-]+$")
_ETAG_HEX_RE = re.compile(r"[0-9a-f]{32}")

log = get_logger(__name__)


class KnmiClientError(RuntimeError):
    """Top-level error for failures talking to the KNMI Open Data API."""


def _validate_filename(filename: str) -> str:
    """Reject path-traversal and other injection attempts in filenames (OWASP A03)."""
    if not _FILENAME_RE.fullmatch(filename):
        raise KnmiClientError(f"Refusing unsafe KNMI filename: {filename!r}")
    return filename


class KnmiFile(BaseModel):
    """Metadata for one file in a KNMI dataset."""

    model_config = ConfigDict(extra="ignore", frozen=True)

    filename: str = Field(validation_alias="filename")
    size: int = Field(validation_alias="size")
    last_modified: datetime = Field(validation_alias="lastModified")
    created: datetime = Field(validation_alias="created")


@dataclass(slots=True)
class KnmiClient:
    """Thin async wrapper over the KNMI Open Data REST API."""

    api_key: str
    _http: httpx.AsyncClient
    _owns_client: bool = False

    @classmethod
    def create(cls, api_key: str, *, timeout: float = 30.0) -> Self:
        """Build a client owning its own underlying httpx.AsyncClient."""
        if not api_key:
            raise KnmiClientError("KnmiClient requires a non-empty api_key")
        http = httpx.AsyncClient(
            base_url=API_BASE_URL,
            headers={"Authorization": api_key},
            timeout=timeout,
            http2=True,
        )
        return cls(api_key=api_key, _http=http, _owns_client=True)

    @classmethod
    def with_http(cls, api_key: str, http: httpx.AsyncClient) -> Self:
        """Build a client borrowing an existing httpx.AsyncClient (used in tests)."""
        return cls(api_key=api_key, _http=http, _owns_client=False)

    async def aclose(self) -> None:
        if self._owns_client:
            await self._http.aclose()

    @asynccontextmanager
    async def session(self) -> AsyncIterator[Self]:
        try:
            yield self
        finally:
            await self.aclose()

    async def list_files(
        self,
        dataset: Dataset,
        *,
        max_keys: int = 10,
        order_by: str = "created",
        sorting: str = "desc",
    ) -> list[KnmiFile]:
        """List files for a dataset, newest-first by default."""
        url = f"/{dataset.files_path}"
        # The base URL is a constant, so this combined URL is provably allowlisted;
        # we still re-validate before issuing the request.
        full = f"{API_BASE_URL}{url}"
        assert_knmi_api_url(full)
        resp = await self._http.get(
            url,
            params={"maxKeys": max_keys, "orderBy": order_by, "sorting": sorting},
        )
        return [KnmiFile.model_validate(f) for f in _ok_json(resp)["files"]]

    async def get_download_url(self, dataset: Dataset, filename: str) -> str:
        """Resolve a temporary (S3 pre-signed) download URL for one file."""
        safe_filename = _validate_filename(filename)
        url = f"/{dataset.files_path}/{safe_filename}/url"
        assert_knmi_api_url(f"{API_BASE_URL}{url}")
        resp = await self._http.get(url)
        body = _ok_json(resp)
        download_url = body.get("temporaryDownloadUrl")
        if not isinstance(download_url, str):
            raise KnmiClientError(f"KNMI response missing temporaryDownloadUrl for {filename!r}")
        return assert_download_url(download_url)

    async def stream_download(self, download_url: str) -> AsyncIterator[bytes]:
        """Yield the body of a pre-signed download URL in chunks.

        The pre-signed S3 URL must not include our `Authorization` header (it has
        its own signature), so we use a bare `httpx.AsyncClient` for this call.

        Streamed bytes are hashed in-line and compared against `Content-MD5` or
        `ETag` after the body completes (OWASP A08). On mismatch we raise
        `KnmiClientError` so the writer's cleanup unlinks the temp file.
        """
        assert_download_url(download_url)
        async with httpx.AsyncClient(timeout=60.0) as bare:
            async with bare.stream("GET", download_url) as resp:
                resp.raise_for_status()
                expected_md5_hex = _expected_md5_hex(resp.headers)
                # md5 is for transport-integrity only, not security.
                hasher = hashlib.md5(usedforsecurity=False) if expected_md5_hex else None
                async for chunk in resp.aiter_bytes(chunk_size=64 * 1024):
                    if hasher is not None:
                        hasher.update(chunk)
                    yield chunk
                if hasher is not None and expected_md5_hex is not None:
                    actual = hasher.hexdigest()
                    if actual != expected_md5_hex:
                        raise KnmiClientError(
                            f"KNMI download integrity check failed: "
                            f"expected md5={expected_md5_hex}, got md5={actual}"
                        )
                elif expected_md5_hex is None:
                    log.warning("knmi.download.no_integrity_header", url=download_url)


def _ok_json(resp: httpx.Response) -> dict[str, Any]:
    """Raise for status, then parse JSON, surfacing useful error context."""
    if resp.is_error:
        raise KnmiClientError(
            f"KNMI request failed: {resp.request.method} {resp.request.url} -> {resp.status_code}"
        )
    body = resp.json()
    if not isinstance(body, dict):
        raise KnmiClientError(f"KNMI response was not a JSON object: {resp.request.url}")
    return body


def _expected_md5_hex(headers: httpx.Headers) -> str | None:
    """Return the expected md5 (lowercase hex) from `Content-MD5` or `ETag`, or None.

    `Content-MD5` per RFC 1864 is base64-encoded; S3 pre-signed-URL responses
    use `ETag` which equals the lowercase hex md5 for non-multipart objects.
    Multipart-upload ETags contain a `-` and are skipped.
    """
    content_md5 = headers.get("content-md5")
    if content_md5:
        try:
            digest = base64.b64decode(content_md5, validate=True)
        except (binascii.Error, ValueError):
            digest = b""
        if len(digest) == 16:
            return digest.hex()
    etag: str = headers.get("etag", "").strip().strip('"').lower()
    if _ETAG_HEX_RE.fullmatch(etag):
        return etag
    return None
