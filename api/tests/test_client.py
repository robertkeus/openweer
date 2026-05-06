"""KNMI Open Data API client tests (mocked HTTP)."""

from __future__ import annotations

import base64
import hashlib

import httpx
import pytest
import respx

from openweer.knmi.client import API_BASE_URL, KnmiClient, KnmiClientError
from openweer.knmi.datasets import get_dataset

RADAR_FORECAST = get_dataset("radar_forecast")
LIST_URL = f"{API_BASE_URL}/{RADAR_FORECAST.files_path}"


def _make_client() -> KnmiClient:
    http = httpx.AsyncClient(
        base_url=API_BASE_URL,
        headers={"Authorization": "test-key"},
    )
    return KnmiClient.with_http("test-key", http)


@respx.mock
async def test_list_files_sends_bare_authorization_header() -> None:
    route = respx.get(LIST_URL).mock(
        return_value=httpx.Response(
            200,
            json={
                "files": [
                    {
                        "filename": "RAD_NL25_RAC_RT_202604031200.h5",
                        "size": 12345,
                        "lastModified": "2026-04-03T12:00:00Z",
                        "created": "2026-04-03T12:00:01Z",
                    }
                ]
            },
        )
    )
    client = _make_client()
    files = await client.list_files(RADAR_FORECAST)

    assert route.called
    assert route.calls.last.request.headers["Authorization"] == "test-key"
    assert "Bearer" not in route.calls.last.request.headers["Authorization"]
    assert files[0].filename == "RAD_NL25_RAC_RT_202604031200.h5"
    assert files[0].size == 12345


@respx.mock
async def test_list_files_default_params_request_newest_first() -> None:
    route = respx.get(LIST_URL).mock(return_value=httpx.Response(200, json={"files": []}))
    client = _make_client()

    await client.list_files(RADAR_FORECAST)

    params = dict(route.calls.last.request.url.params)
    assert params == {"maxKeys": "10", "orderBy": "created", "sorting": "desc"}


@respx.mock
async def test_list_files_raises_on_http_error() -> None:
    respx.get(LIST_URL).mock(return_value=httpx.Response(401, json={"error": "unauthorized"}))
    client = _make_client()

    with pytest.raises(KnmiClientError, match="401"):
        await client.list_files(RADAR_FORECAST)


@respx.mock
async def test_get_download_url_returns_temporary_url() -> None:
    filename = "RAD_NL25_RAC_RT_202604031200.h5"
    expected = "https://knmi.s3.eu-west-1.amazonaws.com/x?signed=1"
    respx.get(f"{LIST_URL}/{filename}/url").mock(
        return_value=httpx.Response(200, json={"temporaryDownloadUrl": expected})
    )
    client = _make_client()

    url = await client.get_download_url(RADAR_FORECAST, filename)
    assert url == expected


async def test_get_download_url_rejects_path_traversal() -> None:
    client = _make_client()
    with pytest.raises(KnmiClientError, match="unsafe KNMI filename"):
        await client.get_download_url(RADAR_FORECAST, "../../../etc/passwd")


@respx.mock
async def test_get_download_url_rejects_response_pointing_outside_allowlist() -> None:
    filename = "valid_file.h5"
    bad_url = "https://evil.example.com/leak.h5"
    respx.get(f"{LIST_URL}/{filename}/url").mock(
        return_value=httpx.Response(200, json={"temporaryDownloadUrl": bad_url})
    )
    client = _make_client()

    with pytest.raises(Exception, match="not in the download allowlist"):
        await client.get_download_url(RADAR_FORECAST, filename)


def test_create_requires_non_empty_api_key() -> None:
    with pytest.raises(KnmiClientError):
        KnmiClient.create("")


_DOWNLOAD_URL = "https://knmi.s3.eu-west-1.amazonaws.com/file?signed=1"


@respx.mock
async def test_stream_download_accepts_matching_content_md5() -> None:
    payload = b"the quick brown fox" * 1000
    md5_b64 = base64.b64encode(hashlib.md5(payload, usedforsecurity=False).digest()).decode()
    respx.get(_DOWNLOAD_URL).mock(
        return_value=httpx.Response(200, content=payload, headers={"Content-MD5": md5_b64})
    )

    client = _make_client()
    received = b"".join([chunk async for chunk in client.stream_download(_DOWNLOAD_URL)])
    assert received == payload


@respx.mock
async def test_stream_download_rejects_mismatched_content_md5() -> None:
    payload = b"correct payload"
    wrong_md5 = base64.b64encode(hashlib.md5(b"different", usedforsecurity=False).digest()).decode()
    respx.get(_DOWNLOAD_URL).mock(
        return_value=httpx.Response(200, content=payload, headers={"Content-MD5": wrong_md5})
    )

    client = _make_client()
    with pytest.raises(KnmiClientError, match="integrity check failed"):
        async for _ in client.stream_download(_DOWNLOAD_URL):
            pass


@respx.mock
async def test_stream_download_accepts_matching_etag_hex() -> None:
    payload = b"s3-style etag check"
    etag = hashlib.md5(payload, usedforsecurity=False).hexdigest()
    respx.get(_DOWNLOAD_URL).mock(
        return_value=httpx.Response(200, content=payload, headers={"ETag": f'"{etag}"'})
    )

    client = _make_client()
    received = b"".join([chunk async for chunk in client.stream_download(_DOWNLOAD_URL)])
    assert received == payload


@respx.mock
async def test_stream_download_rejects_mismatched_etag() -> None:
    payload = b"actual"
    wrong_etag = hashlib.md5(b"expected", usedforsecurity=False).hexdigest()
    respx.get(_DOWNLOAD_URL).mock(
        return_value=httpx.Response(200, content=payload, headers={"ETag": f'"{wrong_etag}"'})
    )

    client = _make_client()
    with pytest.raises(KnmiClientError, match="integrity check failed"):
        async for _ in client.stream_download(_DOWNLOAD_URL):
            pass


@respx.mock
async def test_stream_download_skips_multipart_etag() -> None:
    payload = b"multipart upload bytes"
    respx.get(_DOWNLOAD_URL).mock(
        return_value=httpx.Response(200, content=payload, headers={"ETag": '"abc123-3"'})
    )

    client = _make_client()
    # ETag with `-N` suffix (multipart) is not an md5; we skip verification rather than fail.
    received = b"".join([chunk async for chunk in client.stream_download(_DOWNLOAD_URL)])
    assert received == payload


@respx.mock
async def test_stream_download_passes_through_when_no_integrity_header() -> None:
    payload = b"no header at all"
    respx.get(_DOWNLOAD_URL).mock(return_value=httpx.Response(200, content=payload))

    client = _make_client()
    received = b"".join([chunk async for chunk in client.stream_download(_DOWNLOAD_URL)])
    assert received == payload
