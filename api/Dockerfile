# syntax=docker/dockerfile:1.7

# ---------- builder: install deps with uv into a project venv ----------
FROM python:3.13-slim AS builder

ENV UV_LINK_MODE=copy \
    UV_COMPILE_BYTECODE=1 \
    UV_PYTHON_DOWNLOADS=0 \
    PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1

# uv via the official static binary — no extra apt packages required.
COPY --from=ghcr.io/astral-sh/uv:0.9.18 /uv /uvx /usr/local/bin/

WORKDIR /app
COPY pyproject.toml uv.lock ./
COPY src ./src
RUN --mount=type=cache,target=/root/.cache/uv \
    uv sync --frozen --no-dev


# ---------- runtime: minimal Python slim, non-root, no build tools ------
FROM python:3.13-slim AS runtime

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PATH="/app/.venv/bin:$PATH"

# rasterio's wheel bundles GDAL but still dlopens system libexpat.
RUN apt-get update \
    && apt-get install -y --no-install-recommends libexpat1 \
    && rm -rf /var/lib/apt/lists/*

# Drop privileges. Mounted /data is owned by this uid in compose.
RUN groupadd --system --gid 1001 openweer \
    && useradd --system --uid 1001 --gid openweer --no-create-home openweer

WORKDIR /app
COPY --from=builder /app /app

# Pre-create /data so docker copies ownership into the named volume on first mount.
RUN mkdir -p /data && chown openweer:openweer /data

USER openweer
EXPOSE 8000

# Default command is the API; ingest + tiler override via compose.
CMD ["python", "-m", "openweer.api"]
