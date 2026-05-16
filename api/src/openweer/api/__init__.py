"""OpenWeer HTTP API (FastAPI).

Note: `create_app` is intentionally NOT re-exported eagerly here. Pulling
it in at package-import time would force the whole FastAPI app graph to
load before any submodule (e.g. `api._bbox`) can be imported on its own —
which breaks modules outside `api/` that only need the bbox constants.
Import it explicitly: `from openweer.api.app import create_app`.
"""
