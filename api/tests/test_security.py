"""SSRF allowlist tests (OWASP A10)."""

from __future__ import annotations

import pytest

from openweer.knmi._security import (
    UrlNotAllowedError,
    assert_download_url,
    assert_knmi_api_url,
)


class TestKnmiApiUrl:
    def test_accepts_official_knmi_api_host(self) -> None:
        url = "https://api.dataplatform.knmi.nl/open-data/v1/datasets"
        assert assert_knmi_api_url(url) == url

    def test_accepts_anonymous_subdomain(self) -> None:
        url = "https://anonymous.api.dataplatform.knmi.nl/wms/adaguc-server"
        assert assert_knmi_api_url(url) == url

    def test_rejects_http_scheme(self) -> None:
        with pytest.raises(UrlNotAllowedError, match="non-https"):
            assert_knmi_api_url("http://api.dataplatform.knmi.nl/")

    def test_rejects_arbitrary_host(self) -> None:
        with pytest.raises(UrlNotAllowedError, match="not in the KNMI API allowlist"):
            assert_knmi_api_url("https://evil.example.com/")

    def test_rejects_subdomain_takeover_attempt(self) -> None:
        # `knmi.nl.evil.com` ends with `.evil.com`, must not match the KNMI host.
        with pytest.raises(UrlNotAllowedError):
            assert_knmi_api_url("https://api.dataplatform.knmi.nl.evil.com/")


class TestDownloadUrl:
    def test_accepts_amazonaws_pre_signed_url(self) -> None:
        url = "https://knmi-data.s3.eu-west-1.amazonaws.com/file.h5?X-Amz-Signature=abc"
        assert assert_download_url(url) == url

    def test_accepts_knmi_dataplatform_host(self) -> None:
        url = "https://files.dataplatform.knmi.nl/abc.h5"
        assert assert_download_url(url) == url

    def test_rejects_unknown_host(self) -> None:
        with pytest.raises(UrlNotAllowedError):
            assert_download_url("https://malware.example.com/file.bin")

    def test_rejects_http_download(self) -> None:
        with pytest.raises(UrlNotAllowedError):
            assert_download_url("http://knmi-data.s3.amazonaws.com/file.h5")
