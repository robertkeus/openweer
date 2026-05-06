# Contributing to OpenWeer

Thanks for considering a contribution! OpenWeer is a small, opinionated open-
source weather platform for the Netherlands. The bar is "would I be proud to
deploy this?" rather than "did the tests pass?", so please read this short
guide before opening a PR.

## Engineering rules

The full ruleset lives in [CLAUDE.md](./CLAUDE.md) — it covers OWASP Top 10
commitments, file-length limits (target <250 lines, hard cap 400), folder
discipline, type-discipline (mypy strict, tsc strict, no `any`), test
expectations, UX bar, and commit conventions.

**TL;DR**: small, focused changes; type hints / strict TS everywhere; no
introduction of `any`, `# type: ignore`, or `@ts-ignore` without a written
reason; new public endpoints get happy- and error-path tests.

## Local development

You need Python 3.12+ (we develop on 3.13), Node 22+, and Docker if you want
to exercise the full stack.

```bash
# Backend
cd api
uv sync --all-extras
uv run pytest          # 158 tests, ~14s
uv run ruff check .
uv run mypy

# Frontend
cd web
nvm use                # honors web/.nvmrc
npm ci
npm run lint
npm run typecheck
npm run test           # vitest

# Full stack (no live KNMI key needed for the web layer)
cp .env.example .env   # fill KNMI_OPEN_DATA_API_KEY for ingest
docker compose up
```

## Pull requests

1. Branch from `main`. Keep one logical change per branch.
2. Run `ruff check`, `mypy`, `pytest` for any Python touch; `lint`, `typecheck`,
   `test` for any web touch. CI does this too — make it pass locally first.
3. Commit messages: imperative, scoped, lowercase prefix.
   - Good: `api(forecast): switch HARMONIE window to 36h`
   - Good: `web(timeline): debounce slider scrub at 60fps`
   - Bad: `Update stuff`
4. Reference an issue if one exists.
5. PR description: what changed and **why**. Include reproduction steps for
   bugfixes and screenshots for UI changes.

## What we'll happily merge

- Bugfixes with a regression test.
- New KNMI dataset integrations that follow the existing `ingest/` pattern.
- A11y / performance improvements (we hold ourselves to WCAG 2.2 AA and
  Lighthouse ≥ 95).
- Dutch-language polish in microcopy.
- Docs and examples.

## What we'll likely push back on

- Large architectural rewrites without a prior discussion in an issue.
- New runtime dependencies for things that can be done in <50 lines of stdlib.
- Code that duplicates existing helpers — please grep first.
- Anything that adds user accounts, analytics with PII, or telemetry.

## Reporting security issues

Please don't open a public issue for security problems. See
[SECURITY.md](./SECURITY.md) for the disclosure process.

## Licence

By contributing, you agree your code is released under the MIT licence (see
[LICENSE](./LICENSE)). KNMI weather data remains under CC-BY-4.0 (see
[DATA_LICENSE.md](./DATA_LICENSE.md)).
