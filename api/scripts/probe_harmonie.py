"""Probe the KNMI Open Data catalog for a sub-hourly HARMONIE precipitation product.

One-shot exploration script: enumerates HARMONIE dataset candidates and reports
which ones exist in the catalog plus the newest filename of each (the filename
often encodes the model run + cycle so we can tell sub-hourly variants apart
without downloading the multi-hundred-MB tar).

For any reachable candidate the user opts to inspect, an interactive download
of the latest file lets us peek at the per-step GRIB members inside the tar to
infer the actual forecast-step length.

Run with:
    uv run python -m scripts.probe_harmonie         # listing only (cheap)
    uv run python -m scripts.probe_harmonie <slug>  # download + inspect one
"""

from __future__ import annotations

import asyncio
import re
import sys
import tarfile
import tempfile
from dataclasses import dataclass
from pathlib import Path

import httpx

from openweer.knmi._security import assert_download_url
from openweer.knmi.client import KnmiClient
from openweer.knmi.datasets import Dataset
from openweer.settings import get_settings

# Known + speculative HARMONIE-AROME product slugs to probe.
_CANDIDATES: tuple[tuple[str, str], ...] = (
    ("harmonie_arome_cy43_p1", "1.0"),
    ("harmonie_arome_cy43_p2", "1.0"),
    ("harmonie_arome_cy43_p3", "1.0"),
    ("harmonie_arome_cy43_p4", "1.0"),
    ("harmonie_arome_cy43_p5", "1.0"),
    ("harmonie_arome_cy43_p6", "1.0"),
    ("harmonie_arome_cy43_p7", "1.0"),
    ("harmonie_arome_cy43_p1_sub_hourly", "1.0"),
    ("harmonie_arome_cy43_p3_sub_hourly", "1.0"),
    ("harmonie_arome_cy43_p5_sub_hourly", "1.0"),
    ("harmonie_arome_cy43_p7_sub_hourly", "1.0"),
)

_STEP_RE = re.compile(r"_(\d{5})_GB$")


@dataclass(slots=True)
class ListResult:
    slug: str
    version: str
    reachable: bool
    latest_filename: str | None = None
    latest_size: int | None = None
    note: str = ""


def _make_descriptor(slug: str, version: str) -> Dataset:
    return Dataset(
        key="harmonie",  # type: ignore[arg-type]
        name=slug,
        version=version,
        file_format="grib",
        cadence_seconds=10_800,
        description="probe",
    )


async def _list_one(client: KnmiClient, slug: str, version: str) -> ListResult:
    ds = _make_descriptor(slug, version)
    try:
        files = await client.list_files(ds, max_keys=1)
    except Exception as exc:
        return ListResult(slug=slug, version=version, reachable=False, note=str(exc)[:80])
    if not files:
        return ListResult(slug=slug, version=version, reachable=True, note="no files")
    latest = files[0]
    return ListResult(
        slug=slug,
        version=version,
        reachable=True,
        latest_filename=latest.filename,
        latest_size=latest.size,
    )


async def _inspect_one(client: KnmiClient, slug: str, version: str) -> None:
    """Range-download a 400 MB prefix of the latest tar and enumerate the
    step members visible in that prefix — enough to read the cadence without
    pulling multi-GB tarballs."""
    ds = _make_descriptor(slug, version)
    files = await client.list_files(ds, max_keys=1)
    if not files:
        print(f"{slug}: no files")
        return
    latest = files[0]
    print(f"Inspecting {slug} v{version} -> {latest.filename} ({latest.size:,} bytes total)")
    url = await client.get_download_url(ds, latest.filename)
    assert_download_url(url)

    range_bytes = 400 * 1024 * 1024  # 400 MB prefix — enough for ~10–20 members
    with tempfile.TemporaryDirectory(prefix="probe-") as work:
        tar_path = Path(work) / latest.filename
        range_hdr = {"Range": f"bytes=0-{range_bytes - 1}"}
        async with httpx.AsyncClient(timeout=120.0) as bare:
            async with bare.stream("GET", url, headers=range_hdr) as resp:
                resp.raise_for_status()
                with tar_path.open("wb") as fp:
                    bytes_seen = 0
                    async for chunk in resp.aiter_bytes(chunk_size=64 * 1024):
                        fp.write(chunk)
                        bytes_seen += len(chunk)
        print(f"  fetched {bytes_seen / (1024 * 1024):.1f} MB prefix")
        steps: list[int] = []
        member_names: list[str] = []
        try:
            with tarfile.open(tar_path, "r|") as tf:
                for member in tf:
                    if not member.isfile():
                        continue
                    member_names.append(member.name)
                    m = _STEP_RE.search(member.name)
                    if m:
                        steps.append(int(m.group(1)))
        except (tarfile.ReadError, EOFError):
            pass
        print(f"  members visible in prefix: {len(member_names)}")
        print(f"  first 8 names: {member_names[:8]}")
        if not steps:
            print("  no _NNNNN_GB steps found")
            return
        unique = sorted(set(steps))
        # Decode the KNMI step encoding. Default convention is HHHMM (5-digit
        # `forecast_seconds // 60` written as hours-hundreds-of-minutes); e.g.
        # 00015 → 15 min, 00200 → 2h, 02400 → 24h.
        def decode_hhhmm(s: int) -> int:
            return (s // 100) * 60 + (s % 100)

        from itertools import pairwise

        decoded_hhhmm = [decode_hhhmm(s) for s in unique]
        deltas = [b - a for a, b in pairwise(decoded_hhhmm)]
        print(f"  unique steps (raw):     first={unique[:8]} last={unique[-3:]}")
        print(f"  decoded HHHMM (min):    first={decoded_hhhmm[:8]} last={decoded_hhhmm[-3:]}")
        if deltas:
            unique_deltas = sorted(set(deltas))
            print(f"  step deltas (min): min={min(deltas)} unique={unique_deltas[:8]}")


async def amain() -> None:
    api_key = get_settings().require_open_data_key()
    async with KnmiClient.create(api_key).session() as client:
        if len(sys.argv) > 1:
            await _inspect_one(client, sys.argv[1], sys.argv[2] if len(sys.argv) > 2 else "1.0")
            return
        print(f"{'slug':<48}{'ver':<6}{'reachable':<10}{'latest_filename':<55}{'size_mb':<10}")
        print("-" * 130)
        for slug, version in _CANDIDATES:
            r = await _list_one(client, slug, version)
            size_mb = f"{r.latest_size / (1024 * 1024):.1f}" if r.latest_size else "-"
            fn = r.latest_filename or r.note
            print(f"{r.slug:<48}{r.version:<6}{r.reachable!s:<10}{fn:<55}{size_mb:<10}")
        print("\nRe-run with `python -m scripts.probe_harmonie <slug> [ver]` to inspect one.")


if __name__ == "__main__":
    asyncio.run(amain())
