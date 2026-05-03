# OpenWeer — Project Rules

This file is loaded automatically by Claude Code in every session for this repo. Apply these rules to every change.

## Identity
- Product name: **OpenWeer** (not "buienradar"; local dir is named for legacy reasons).
- Domain: **openweer.nl**.
- Open-source weather platform for the Netherlands, powered by KNMI open data (CC-BY-4.0).
- Code license: MIT. Weather data: © KNMI, CC-BY-4.0 (attribution required in README and web app footer).

## Engineering rules

### Security — OWASP Top 10
- **A01 Access Control**: public read-only API; rate-limit at nginx (`limit_req`). Never expose internal file paths in errors.
- **A02 Crypto**: HTTPS-only in production; HSTS header; no PII storage.
- **A03 Injection**: validate every input at the API boundary with Pydantic. Reject path-traversal in filenames (`..`, `/`, `\`). Coordinates must be float in NL bbox.
- **A04 Insecure Design**: design for known threats; coordinate-rounding for cache; deny-by-default in URL allowlist for SSRF.
- **A05 Misconfiguration**: ship security headers (`Content-Security-Policy`, `X-Content-Type-Options: nosniff`, `Referrer-Policy: strict-origin-when-cross-origin`, `X-Frame-Options: DENY`, `Strict-Transport-Security`). Disable server tokens.
- **A06 Vulnerable Components**: pin every dep (uv lockfile, package-lock.json). Dependabot or `uv lock --upgrade` weekly.
- **A07 Auth**: no user accounts in v1; if added later, use Argon2id, never plain bcrypt.
- **A08 Integrity**: verify HDF5/GRIB downloads against KNMI's `Content-MD5` if provided; atomic-mv all file writes; never write directly into a path served to the public.
- **A09 Logging**: structured JSON logs; never log API keys, raw lat/lon (round to 2 decimals for analytics); no PII.
- **A10 SSRF**: allowlist `api.dataplatform.knmi.nl`, `mqtt.dataplatform.knmi.nl`, `nominatim.openstreetmap.org` only. Reject any other host before fetching.

### Code quality
- **File length**: target <250 lines per file; hard cap 400. Split by responsibility, not arbitrarily.
- **No duplication**: before adding a function, grep for similar names/intent. Extract shared helpers into a clear module (`shared/`, `lib/`, `utils/` only when genuinely cross-cutting).
- **Folder structure**: every folder has a single, named responsibility. No "misc", "common", "helpers" dumping grounds. If a folder has >7 files of mixed concerns, split it.
- **Senior-dev defaults**:
  - Python: type hints everywhere; `from __future__ import annotations`; ruff + mypy strict; pydantic v2 for boundary types; async-first for I/O.
  - TypeScript: `strict: true`; no `any`; React Router v7 typed loaders; Zod for runtime validation of external data.
  - Pure functions where practical; side effects pushed to the edges.
  - Errors are domain types, not strings; never `except: pass`.

### Testing
- **Unit tests** for every pure function and parser (Python: pytest; TS: vitest).
- **Integration tests** for HTTP boundaries (FastAPI `TestClient`; React Router with msw).
- **End-to-end terminal smoke test** at every step before marking it done — health endpoint, sample tile fetch, sample API call.
- Test coverage isn't a target on its own, but every public endpoint and every parser must have at least happy-path + error-path tests.

### UX / UI (award-winning bar)
- Mobile-first responsive design; map fills the viewport on mobile, sidebar on desktop.
- Performance budget: LCP < 1.5 s on 4G; TTI < 2.5 s. Lighthouse ≥ 95 across all categories.
- A11y: WCAG 2.2 AA — all interactive elements keyboard-reachable, focus rings visible, ARIA labels on the map controls, prefers-reduced-motion disables animation.
- Visual: clean Dutch design language (think NS, Rijksmuseum) — generous whitespace, restrained palette, one strong accent, system fonts or Inter.
- Microcopy in Dutch (the audience is NL), with English fallback toggle.
- Loading states are designed (skeletons, not spinners on the map; subtle progress on tile prefetch).
- The radar slider is the hero element — must feel buttery (60 fps, snap to ticks, haptic on mobile).

### Process
- Each step ends with a green test run AND a terminal smoke test before moving on.
- Commit messages: imperative, scoped (`api(knmi): add MQTT client`).
- Never commit `.env`, lockfile-bypassing installs, or generated tile artifacts.
