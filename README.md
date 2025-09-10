# One N Done • Unified Astro Scaffold

This repo bootstraps an upstream-first Astro 5 + Tailwind v4 site with geo/service SSG, JSON-LD, SEO reporting, integrity guards, a Geo Doctor, Playwright smokes, and CI.

## Quick start

1) Install and build

```
npm ci
npm run build
```

2) Preview locally

```
SITE_URL=https://onendone.com.au npm run preview
# or dev server
SITE_URL=https://onendone.com.au npm run dev
```

3) Smoke tests (after preview)

```
PREVIEW_URL=http://127.0.0.1:4321 npm run test:smoke
```

## Pipeline

- Prebuild: Geo Doctor validates `src/data/*.json` and emits `.tmp/smoke-paths.json`.
- Build: Astro SSG for suburb and service/suburb routes.
- Postbuild: SEO reporter validates canonicals and JSON-LD; guards check anchors/hidden keywords/UA DOM/similarity.
- CI: Runs build + smokes, with npm cache and Playwright browsers preinstalled.

## Data

- `src/data/suburbs.json` – suburb slugs, names, neighbors
- `src/data/services.json` – service slugs and copy

## Scripts

- `clean:all` – hard reset + remove untracked/ignored
- `preview:site` – preview with SITE_URL set and fixed host/port

## Notes

- JSON-LD is serialized safely via `sanitizeJsonLd()` in `src/lib/seo/jsonld.ts`.
- Guard thresholds can be tuned in `scripts/guards/*`.
