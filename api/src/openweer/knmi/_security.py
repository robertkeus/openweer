"""SSRF protection — outbound URL allowlist (OWASP A10).

Every outbound HTTP request from OpenWeer goes through one of these validators.
Any URL whose host doesn't match an allowed pattern is rejected before the request
is dispatched, even if attacker-controlled data somehow reaches the URL builder.
"""

from __future__ import annotations

from urllib.parse import urlparse

#: Hosts the KNMI client may talk to directly (api calls, list/get-url endpoints).
_KNMI_API_HOSTS: frozenset[str] = frozenset(
    {
        "api.dataplatform.knmi.nl",
        "anonymous.api.dataplatform.knmi.nl",
    }
)

#: Suffix patterns that are acceptable for actual file downloads. KNMI returns
#: pre-signed S3 URLs, so we allow `*.amazonaws.com` for the download phase only.
_DOWNLOAD_HOST_SUFFIXES: tuple[str, ...] = (
    ".amazonaws.com",
    ".dataplatform.knmi.nl",
)


class UrlNotAllowedError(ValueError):
    """Raised when an outbound URL fails the allowlist check."""


def _parsed_https(url: str) -> tuple[str, str]:
    """Parse `url` and require https. Returns (host, path)."""
    parsed = urlparse(url)
    if parsed.scheme != "https":
        raise UrlNotAllowedError(f"Refusing non-https URL: scheme={parsed.scheme!r}")
    if not parsed.hostname:
        raise UrlNotAllowedError("Refusing URL without a hostname")
    return parsed.hostname.lower(), parsed.path


def assert_knmi_api_url(url: str) -> str:
    """Validate `url` is a KNMI Open Data API endpoint. Returns the URL on success."""
    host, _ = _parsed_https(url)
    if host not in _KNMI_API_HOSTS:
        raise UrlNotAllowedError(f"Refusing URL: host {host!r} is not in the KNMI API allowlist")
    return url


def assert_download_url(url: str) -> str:
    """Validate `url` is a permitted file-download target (KNMI or its S3 redirect)."""
    host, _ = _parsed_https(url)
    if host in _KNMI_API_HOSTS:
        return url
    if any(
        host == suffix.lstrip(".") or host.endswith(suffix) for suffix in _DOWNLOAD_HOST_SUFFIXES
    ):
        return url
    raise UrlNotAllowedError(
        f"Refusing download URL: host {host!r} is not in the download allowlist"
    )
