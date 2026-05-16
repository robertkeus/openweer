"""Ingest service — MQTT-driven (with HTTP fallback) downloader for KNMI files.

Submodules are imported explicitly (e.g. `from openweer.ingest.worker import
IngestWorker`) to keep the package-level import side-effect free; eager
re-exports would create a circular import with `openweer.devices.worker`
which depends on `openweer.ingest.storage`.
"""
