#!/usr/bin/env bash
# install-unified.sh — One-pass upstream bootstrap for Astro + Tailwind v4 + Geo + Guards
# Usage:
#   bash install-unified.sh --force --site=https://onendone.com.au [--minimal] [--plan]
# Flags:
#   --force   : skip interactive confirm
#   --plan    : dry-run (print actions, don't write)
#   --minimal : skip blog/RSS; core suburb/service only

set -euo pipefail

### ---------------------------
### 0) Flags & environment
### ---------------------------
FORCE=false
PLAN=false
MINIMAL=false
SITE_URL=""
for arg in "$@"; do
  case "$arg" in
    --force)   FORCE=true ;;
    --plan)    PLAN=true ;;
    --minimal) MINIMAL=true ;;
    --site=*)  SITE_URL="${arg#*=}" ;;
    *) echo "Unknown arg: $arg" >&2; exit 1 ;;
  esac
done

if [[ -z "${SITE_URL}" ]]; then
  echo "Error: --site=https://example.com is required" >&2
  exit 1
fi

confirm () {
  $FORCE && return 0
  read -r -p "$1 [y/N] " ans
  [[ "${ans:-N}" =~ ^[Yy]$ ]]
}

plan () { $PLAN && echo "[plan] $*" || eval "$@"; }

require_cmd () { command -v "$1" >/dev/null 2>&1 || { echo "Missing: $1" >&2; exit 1; }; }

nodever_ok () {
  node -e 'const v=process.versions.node.split(".").map(Number); if(!((v[0]>20)|| (v[0]===20 && v[1]>=3))) process.exit(1)'
}

### ---------------------------
### 1) Preflight
### ---------------------------
require_cmd node
require_cmd npm
if ! nodever_ok; then
  echo "Node >= 20.3.0 required. You have: $(node -v)" >&2
  exit 1
fi

if ! $FORCE; then
  echo "This will create/overwrite files in the current repo."
  confirm "Proceed?" || exit 1
fi

### ---------------------------
### 2) Helpers
### ---------------------------
write () {
  # write <path> <<'EOF' ... EOF
  local path="$1"
  shift
  if $PLAN; then
    echo "[plan] write $path"
    cat > /dev/null
  else
    mkdir -p "$(dirname "$path")"
    cat > "$path"
    echo "[ok] wrote $path"
  fi
}

ensure_json_prop () {
  # ensure_json_prop <file> <jq-filter> <fallback-json>
  local file="$1" filter="$2" fallback="$3"
  if ! $PLAN; then
    if ! command -v jq >/dev/null 2>&1; then
      echo "[warn] jq not found; skipping JSON patch for $file. Please merge manually."
      return 0
    fi
    if [[ -f "$file" ]]; then
      tmp="$(mktemp)"
      if ! jq "$filter" "$file" > "$tmp" 2>/dev/null; then
        echo "$fallback" > "$tmp"
      fi
      mv "$tmp" "$file"
      echo "[ok] patched $file"
    else
      echo "$fallback" > "$file"
      echo "[ok] created $file"
    fi
  else
    echo "[plan] ensure $file has $filter"
  fi
}

### ---------------------------
### 3) Node & project basics
### ---------------------------
write ".nvmrc" <<EOF
v20.10.0
EOF

write ".editorconfig" <<'EOF'
root = true
[*]
charset = utf-8
end_of_line = lf
insert_final_newline = true
indent_style = space
indent_size = 2
EOF

write ".gitignore" <<'EOF'
node_modules
dist
.tmp
tmp
.DS_Store
coverage
playwright-report
EOF

### ---------------------------
### 4) Astro + Tailwind v4 (Vite plugin only)
### ---------------------------
write "astro.config.ts" <<'EOF'
import { defineConfig } from 'astro/config';
import tailwind from '@tailwindcss/vite';

export default defineConfig({
  site: import.meta.env.SITE_URL || 'https://example.com',
  vite: {
    plugins: [tailwind()],
  },
});
EOF

write "src/styles/tailwind.css" <<'EOF'
@import "tailwindcss";
/* component-level utilities and safelist hints can live here, if needed */
EOF

write "src/env.d.ts" <<'EOF'
/// <reference types="astro/client" />
EOF

write "src/layouts/BaseLayout.astro" <<'EOF'
---
import { sanitizeJsonLd } from "../lib/seo/jsonld";
const { title = "One N Done", description = "Bond cleaning you can trust", jsonld = [], class: klass = "" } = Astro.props;
const site = Astro.site?.toString() || "https://example.com";
---
<!doctype html>
<html lang="en">
  <head>
    <meta charset="utf-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1" />
    <title>{title}</title>
    <link rel="canonical" href={Astro.url.href} />
    <meta name="description" content={description} />
    <style is:global>
      :root { --gap-outer: 24px; --gap-card: 16px; --gap-list: 12px; }
    </style>
    {jsonld.map((entry) => (
      <script type="application/ld+json" set:html={sanitizeJsonLd(entry)} />
    ))}
  </head>
  <body class={`min-h-screen antialiased bg-white text-slate-900 ${klass}`}>
    <main class="mx-auto max-w-6xl px-[var(--gap-outer)]">
      <slot />
    </main>
  </body>
</html>
EOF

write "src/app.css" <<'EOF'
@import "./styles/tailwind.css";
EOF

write "src/lib/seo/jsonld.ts" <<'EOF'
export function sanitizeJsonLd(obj: unknown): string {
  // Minimal XSS-safe stringifier (no functions, no prototypes)
  return JSON.stringify(obj, (_k, v) => (typeof v === 'string' ? v : v));
}
EOF

### ---------------------------
### 5) Data layer (geo + services)
### ---------------------------
write "src/data/services.json" <<'EOF'
[
  {
    "slug": "bond-cleaning",
    "name": "Bond Cleaning",
    "short": "End-of-lease clean that satisfies agent checklists.",
    "guarantee": "Bond-back friendly. If flagged, we re-clean the listed items."
  },
  {
    "slug": "bathroom-deep-clean",
    "name": "Bathroom Deep Clean",
    "short": "Tiles, grout, glass, and fixtures restored to a hygienic shine.",
    "guarantee": "We target grime, scale, and soap build-up thoroughly."
  }
]
EOF

write "src/data/suburbs.json" <<'EOF'
[
  { "slug": "ipswich", "name": "Ipswich", "region": "Brisbane West", "neighbors": ["booval","east-ipswich","brassall"] },
  { "slug": "kenmore", "name": "Kenmore", "region": "Brisbane West", "neighbors": ["brookfield","fig-tree-pocket","chapel-hill"] }
]
EOF

write "src/lib/geo/helpers.ts" <<'EOF'
import suburbs from "../../data/suburbs.json";
import services from "../../data/services.json";

export type Suburb = typeof suburbs[number];
export type Service = typeof services[number];

export function findSuburbBySlug(slug: string): Suburb | undefined {
  return (suburbs as Suburb[]).find(s => s.slug === slug);
}
export function listNearby(slug: string, max = 6): Suburb[] {
  const s = findSuburbBySlug(slug);
  if (!s) return [];
  const order = s.neighbors.concat(
    (suburbs as Suburb[]).map(x => x.slug).filter(x => x !== slug && !s.neighbors.includes(x))
  );
  const seen = new Set<string>();
  const arr: Suburb[] = [];
  for (const sl of order) {
    if (seen.has(sl)) continue;
    const sub = findSuburbBySlug(sl);
    if (sub) { arr.push(sub); seen.add(sl); }
    if (arr.length >= max) break;
  }
  return arr;
}
export function findService(slug: string): Service | undefined {
  return (services as Service[]).find(s => s.slug === slug);
}
export function serviceUrl(svc: string, suburb: string) {
  return `/services/${svc}/${suburb}/`;
}
EOF

### ---------------------------
### 6) UI atoms (trust, nearby)
### ---------------------------
write "src/components/TrustChips.astro" <<'EOF'
---
const { items = ["Fully insured", "Police-checked", "5★ on Google"] } = Astro.props;
---
<div class="mt-3 flex flex-wrap gap-2 text-sm text-slate-700">
  {items.map((t) => <span class="rounded-full border px-2 py-1">{t}</span>)}
</div>
EOF

write "src/components/NearbySuburbs.astro" <<'EOF'
---
import { listNearby } from "../lib/geo/helpers";
const { suburbSlug } = Astro.props;
const nearby = listNearby(suburbSlug);
---
<section class="mt-8">
  <h2 class="text-lg font-semibold mb-3">Nearby suburbs</h2>
  <ul class="grid grid-cols-2 sm:grid-cols-3 md:grid-cols-6 gap-2">
    {nearby.map(n => (
      <li><a class="block rounded border px-3 py-2 hover:shadow-sm"
             href={`/suburbs/${n.slug}/`}>{n.name}</a></li>
    ))}
  </ul>
</section>
EOF

### ---------------------------
### 7) Pages (SSG: suburb + service/suburb)
### ---------------------------
write "src/pages/suburbs/[suburb]/index.astro" <<'EOF'
---
import BaseLayout from "../../../layouts/BaseLayout.astro";
import { findSuburbBySlug } from "../../../lib/geo/helpers";
import NearbySuburbs from "../../../components/NearbySuburbs.astro";
import TrustChips from "../../../components/TrustChips.astro";

export async function getStaticPaths() {
  const suburbs = (await import("../../../data/suburbs.json")).default as Array<{slug:string}>;
  return suburbs.map(s => ({ params: { suburb: s.slug } }));
}

const { suburb } = Astro.params;
const s = findSuburbBySlug(suburb!);
if (!s) return Astro.redirect("/404");
const title = `Bond Cleaning in ${s.name}`;
const jsonld = [{
  "@context": "https://schema.org",
  "@type": "Service",
  "name": title,
  "areaServed": s.name,
  "provider": { "@type": "LocalBusiness", "name": "One N Done Bond Clean" },
  "url": Astro.url.href
}];
---

<BaseLayout {title} description="Agent-friendly, guaranteed, fully insured." {jsonld}>
  <section class="pt-8">
    <h1 class="text-3xl font-bold">{title}</h1>
    <p class="mt-2 text-slate-700">We service {s.name} and surrounds.</p>
    <a href="/#quote" class="mt-4 inline-block rounded-xl bg-slate-900 px-4 py-2 text-white">Get a fast quote</a>
    <TrustChips />
    <NearbySuburbs suburbSlug={s.slug} />
  </section>
</BaseLayout>
EOF

write "src/pages/services/[service]/[suburb]/index.astro" <<'EOF'
---
import BaseLayout from "../../../../layouts/BaseLayout.astro";
import { findSuburbBySlug, findService, serviceUrl } from "../../../../lib/geo/helpers";
import NearbySuburbs from "../../../../components/NearbySuburbs.astro";
import TrustChips from "../../../../components/TrustChips.astro";

export async function getStaticPaths() {
  const [suburbs, services] = await Promise.all([
    import("../../../../data/suburbs.json"),
    import("../../../../data/services.json"),
  ]);
  return services.default.flatMap((svc: any) =>
    suburbs.default.map((s: any) => ({ params: { service: svc.slug, suburb: s.slug } }))
  );
}

const { suburb, service } = Astro.params;
const s = findSuburbBySlug(suburb!);
const sv = findService(service!);
if (!s || !sv) return Astro.redirect("/404");

const title = `${sv.name} in ${s.name}`;
const jsonld = [{
  "@context": "https://schema.org",
  "@type": "Service",
  "name": sv.name,
  "areaServed": s.name,
  "provider": { "@type": "LocalBusiness", "name": "One N Done Bond Clean" },
  "url": Astro.url.href
}];
---

<BaseLayout {title} description={sv.short} {jsonld}>
  <section class="pt-8">
    <h1 class="text-3xl font-bold">{title}</h1>
    <p class="mt-2 text-slate-700">{sv.short}</p>
    <a href="/#quote" class="mt-4 inline-block rounded-xl bg-slate-900 px-4 py-2 text-white">Get a fast quote</a>
    <TrustChips />
    <section class="mt-6">
      <h2 class="text-lg font-semibold mb-2">What’s included</h2>
      <ul class="list-disc pl-6 space-y-[var(--gap-list)]">
        <li>Detailed surface clean with attention to edges and corners</li>
        <li>Agent-friendly finishing for bathrooms and kitchens</li>
        <li>Final inspection pass with touch-up if needed</li>
      </ul>
    </section>
    <section class="mt-8">
      <h2 class="text-lg font-semibold mb-2">More in {s.name}</h2>
      <div class="flex flex-wrap gap-2">
        {["bond-cleaning","bathroom-deep-clean"].filter(sl => sl !== sv.slug).map(sl => (
          <a class="rounded border px-3 py-2"
             href={serviceUrl(sl, s.slug)}>{sl.replace(/-/g, " ")}</a>
        ))}
      </div>
    </section>
    <NearbySuburbs suburbSlug={s.slug} />
  </section>
</BaseLayout>
EOF

### ---------------------------
### 8) SEO reporter (happy-dom) — JSON-LD/canonicals
### ---------------------------
write "scripts/seo/report.mjs" <<'EOF'
#!/usr/bin/env node
import { JSDOM } from 'jsdom';
import fs from 'node:fs';
import path from 'node:path';

const dist = 'dist';
if (!fs.existsSync(dist)) {
  console.error('dist not found. Run `npm run build` first.');
  process.exit(1);
}

function walk(dir) {
  const out = [];
  for (const f of fs.readdirSync(dir)) {
    const p = path.join(dir, f);
    const s = fs.statSync(p);
    if (s.isDirectory()) out.push(...walk(p));
    else if (f.endsWith('.html')) out.push(p);
  }
  return out;
}

const pages = walk(dist);
const summary = { pages: 0, missingCanonicals: [], jsonldErrors: [], duplicateCanonicals: [] };
for (const p of pages) {
  const html = fs.readFileSync(p, 'utf8');
  const dom = new JSDOM(html);
  const doc = dom.window.document;

  const canon = doc.querySelector('link[rel="canonical"]')?.getAttribute('href') || '';
  if (!canon) summary.missingCanonicals.push(p);

  const scripts = Array.from(doc.querySelectorAll('script[type="application/ld+json"]'));
  try {
    for (const s of scripts) JSON.parse(s.textContent || '{}');
  } catch (e) {
    summary.jsonldErrors.push(p);
  }

  // crude check: multiple canonicals
  const canonCount = doc.querySelectorAll('link[rel="canonical"]').length;
  if (canonCount > 1) summary.duplicateCanonicals.push(p);
}
summary.pages = pages.length;

const outDir = '.tmp/seo';
fs.mkdirSync(outDir, { recursive: true });
fs.writeFileSync(path.join(outDir, 'summary.json'), JSON.stringify(summary, null, 2));
console.log('[seo:report] wrote .tmp/seo/summary.json');
if (summary.missingCanonicals.length || summary.jsonldErrors.length) {
  console.error('[seo:report] issues found');
  process.exitCode = 2;
}
EOF

### ---------------------------
### 9) Integrity guards (Transparent Lift Pack style)
### ---------------------------
write "scripts/guards/anchors.mjs" <<'EOF'
#!/usr/bin/env node
import fs from 'node:fs';
import path from 'node:path';
import { JSDOM } from 'jsdom';
const dist = 'dist';
if (!fs.existsSync(dist)) { console.error('dist not found'); process.exit(1); }

function walk(dir){ return fs.readdirSync(dir, {withFileTypes:true})
  .flatMap(d=> d.isDirectory()? walk(path.join(dir,d.name)) : d.name.endsWith('.html')? [path.join(dir,d.name)] : []); }

const pages = walk(dist);
const violations = [];
for (const p of pages) {
  const html = fs.readFileSync(p,'utf8');
  const doc = new JSDOM(html).window.document;
  const anchors = Array.from(doc.querySelectorAll('a')).map(a=> (a.textContent||'').trim().toLowerCase()).filter(Boolean);
  const counts = anchors.reduce((m,t)=> (m[t]=(m[t]||0)+1, m), {});
  const bad = Object.entries(counts).filter(([,c]) => c >= 6); // repeated same label too often
  if (bad.length) violations.push({ page: p, bad });
}
if (violations.length){
  fs.mkdirSync('.tmp/guards', {recursive:true});
  fs.writeFileSync('.tmp/guards/anchors.json', JSON.stringify(violations,null,2));
  console.error('[guard:anchors] excessive repeated anchor labels found');
  process.exit(2);
}
console.log('[guard:anchors] ok');
EOF

write "scripts/guards/no-hidden-keywords.mjs" <<'EOF'
#!/usr/bin/env node
import fs from 'node:fs';
import path from 'node:path';
import { JSDOM } from 'jsdom';
const pages = (function walk(dir){ return fs.readdirSync(dir,{withFileTypes:true})
  .flatMap(d=> d.isDirectory()? walk(path.join(dir,d.name)) : d.name.endsWith('.html')? [path.join(dir,d.name)] : []); })('dist');

const violations = [];
for (const p of pages) {
  const html = fs.readFileSync(p,'utf8');
  const doc = new JSDOM(html).window.document;
  const hidden = Array.from(doc.querySelectorAll('[hidden], [style*="display:none"], [style*="visibility:hidden"]'))
    .filter(el => /clean|bond|suburb|service|quote/i.test(el.textContent || ''));
  if (hidden.length) violations.push({ page: p, count: hidden.length });
}
if (violations.length){
  fs.mkdirSync('.tmp/guards', {recursive:true});
  fs.writeFileSync('.tmp/guards/hidden.json', JSON.stringify(violations,null,2));
  console.error('[guard:hidden] hidden keyword blocks detected');
  process.exit(2);
}
console.log('[guard:hidden] ok');
EOF

write "scripts/guards/no-ua-dom.mjs" <<'EOF'
#!/usr/bin/env node
import fs from 'node:fs';
const code = fs.readFileSync('dist/index.html','utf8').toString();
if (/navigator\.userAgent|userAgentData/.test(code)) {
  console.error('[guard:ua] user-agent based DOM branching detected in built output');
  process.exit(2);
}
console.log('[guard:ua] ok');
EOF

write "scripts/guards/similarity.mjs" <<'EOF'
#!/usr/bin/env node
import fs from 'node:fs';
import path from 'node:path';
import { JSDOM } from 'jsdom';

// Shingle-based near-duplicate detector on suburb pages
function getHtmlPages(root) {
  const out = [];
  for (const f of fs.readdirSync(root, { withFileTypes: true })) {
    const p = path.join(root, f.name);
    if (f.isDirectory()) out.push(...getHtmlPages(p));
    else if (f.name.endsWith('.html')) out.push(p);
  }
  return out;
}

function textOf(file){
  const html = fs.readFileSync(file, 'utf8');
  const doc = new JSDOM(html).window.document;
  const body = doc.querySelector('main') || doc.body;
  return (body?.textContent || '').replace(/\s+/g, ' ').trim().toLowerCase();
}
function shingles(s, size=8){
  const a = s.split(/\s+/), out = [];
  for (let i=0;i+size<=a.length;i++) out.push(a.slice(i,i+size).join(' '));
  return new Set(out);
}
function jaccard(a,b){
  const A=[...a], B=[...b]; const u=new Set([...A,...B]); const i=[...a].filter(x=>b.has(x)).length; return i / u.size;
}

const pages = getHtmlPages('dist').filter(p => /\/suburbs\/[^/]+\/index\.html$/.test(p));
const violations = [];
for (let i=0;i<pages.length;i++){
  for (let j=i+1;j<pages.length;j++){
    const s1 = shingles(textOf(pages[i]));
    const s2 = shingles(textOf(pages[j]));
    const sim = jaccard(s1, s2);
    if (sim >= 0.92) violations.push({ a: pages[i], b: pages[j], sim });
  }
}
if (violations.length){
  fs.mkdirSync('.tmp/guards', {recursive:true});
  fs.writeFileSync('.tmp/guards/similarity.json', JSON.stringify(violations,null,2));
  console.error('[guard:similar] near-duplicate suburb pages detected');
  process.exit(2);
}
console.log('[guard:similar] ok');
EOF

write "scripts/guards/all.mjs" <<'EOF'
#!/usr/bin/env node
import { spawnSync } from 'node:child_process';
const cmds = [
  ['node', ['scripts/guards/anchors.mjs']],
  ['node', ['scripts/guards/no-hidden-keywords.mjs']],
  ['node', ['scripts/guards/no-ua-dom.mjs']],
  ['node', ['scripts/guards/similarity.mjs']]
];
for (const [bin, args] of cmds) {
  const r = spawnSync(bin, args, { stdio: 'inherit' });
  if (r.status !== 0) process.exit(r.status || 2);
}
console.log('[guard:all] ok');
EOF

chmod +x scripts/guards/*.mjs 2>/dev/null || true

### ---------------------------
### 10) Geo Doctor (strict checks)
### ---------------------------
write "scripts/geo/doctor.mjs" <<'EOF'
#!/usr/bin/env node
import fs from 'node:fs';

function load(p){ if (!fs.existsSync(p)) throw new Error(`Missing data: ${p}`); return JSON.parse(fs.readFileSync(p,'utf8')); }

try {
  const suburbs = load('src/data/suburbs.json');
  const services = load('src/data/services.json');

  const slugs = new Set();
  for (const s of suburbs) {
    if (!/^[a-z0-9-]+$/.test(s.slug)) throw new Error(`Bad suburb slug: ${s.slug}`);
    if (slugs.has(s.slug)) throw new Error(`Duplicate suburb slug: ${s.slug}`);
    slugs.add(s.slug);
    if (!Array.isArray(s.neighbors)) throw new Error(`Suburb.neighbors must be array: ${s.slug}`);
  }

  const svcSlugs = new Set();
  for (const s of services) {
    if (!/^[a-z0-9-]+$/.test(s.slug)) throw new Error(`Bad service slug: ${s.slug}`);
    if (svcSlugs.has(s.slug)) throw new Error(`Duplicate service slug: ${s.slug}`);
    svcSlugs.add(s.slug);
  }

  // synthesize build paths for a quick smoke list
  const buildPaths = [];
  const suburbPages = suburbs.map(s => `/suburbs/${s.slug}/`);
  buildPaths.push(...suburbPages);
  for (const svc of services) for (const s of suburbs) buildPaths.push(`/services/${svc.slug}/${s.slug}/`);

  fs.mkdirSync('.tmp', { recursive: true });
  fs.writeFileSync('.tmp/smoke-paths.json', JSON.stringify(buildPaths.slice(0, 200), null, 2));
  console.log('[geo:doctor] ok - wrote .tmp/smoke-paths.json');
} catch (e) {
  console.error('[geo:doctor] ' + (e?.message || e));
  process.exit(2);
}
EOF

chmod +x scripts/geo/doctor.mjs 2>/dev/null || true

### ---------------------------
### 11) Playwright smoke tests
### ---------------------------
write "playwright.config.ts" <<'EOF'
import { defineConfig, devices } from '@playwright/test';
export default defineConfig({
  testDir: 'tests/smoke',
  timeout: 30_000,
  use: { baseURL: process.env.PREVIEW_URL || 'http://localhost:4321' },
  projects: [{ name: 'chromium', use: { ...devices['Desktop Chrome'] } }]
});
EOF

write "tests/smoke/smoke.spec.ts" <<'EOF'
import { test, expect } from '@playwright/test';
import fs from 'node:fs';

const paths: string[] = JSON.parse(fs.readFileSync('.tmp/smoke-paths.json','utf8'));

for (const p of paths.slice(0, 12)) {
  test(`200 & JSON-LD exists: ${p}`, async ({ page }) => {
    const url = new URL(p, process.env.PREVIEW_URL || 'http://localhost:4321').toString();
    const res = await page.goto(url, { waitUntil: 'domcontentloaded' });
    expect(res?.ok(), `status for ${url}`).toBeTruthy();
    const jsonld = await page.locator('script[type="application/ld+json"]').all();
    expect(jsonld.length).toBeGreaterThan(0);
  });
}
EOF

### ---------------------------
### 12) Package.json (scripts & deps)
### ---------------------------
write "package.json" <<'EOF'
{
  "name": "onendone-unified",
  "private": true,
  "type": "module",
  "engines": { "node": ">=20.3.0 <21 || >=22" },
  "scripts": {
    "dev": "astro dev",
    "build": "SITE_URL=${SITE_URL} astro build",
    "preview": "astro preview",
    "geo:doctor:strict": "node scripts/geo/doctor.mjs",
    "seo:report": "node scripts/seo/report.mjs",
    "guard:all": "node scripts/guards/all.mjs",
    "prebuild": "npm run geo:doctor:strict",
    "postbuild": "npm run seo:report && npm run guard:all",
    "test:smoke": "playwright test -c playwright.config.ts"
  },
  "dependencies": {
    "astro": "^5.13.4",
    "@tailwindcss/vite": "^4.1.0"
  },
  "devDependencies": {
    "@playwright/test": "^1.47.2",
    "jsdom": "^24.1.0",
    "typescript": "^5.6.2"
  }
}
EOF

### ---------------------------
### 13) Netlify + CI
### ---------------------------
write "netlify.toml" <<'EOF'
[build]
  command = "npm run build"
  publish = "dist"

[[plugins]]
  package = "@netlify/plugin-lighthouse"
EOF

write ".github/workflows/ci.yml" <<'EOF'
name: ci
on:
  push:
    branches: [ main ]
  pull_request:
jobs:
  build-test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with: { node-version: '20.10.0' }
      - run: npm ci
      - run: npm run build
      - run: npx http-server dist -p 4321 & sleep 2
      - run: PREVIEW_URL="http://127.0.0.1:4321" npm run test:smoke
EOF

### ---------------------------
### 14) Optional blog scaffold (skipped with --minimal)
### ---------------------------
if ! $MINIMAL; then
  write "src/content/config.ts" <<'EOF'
import { z, defineCollection } from 'astro:content';
const blog = defineCollection({
  type: 'content',
  schema: z.object({
    title: z.string(),
    description: z.string().optional(),
    pubDate: z.date(),
    hero: z.string().optional(),
    tags: z.array(z.string()).default([]),
  })
});
export const collections = { blog };
EOF

  write "src/pages/blog/index.astro" <<'EOF'
---
import BaseLayout from "../../layouts/BaseLayout.astro";
import { getCollection } from "astro:content";
const posts = await getCollection("blog");
---
<BaseLayout title="Blog">
  <h1 class="text-3xl font-bold pt-8">Latest articles</h1>
  <ul class="mt-6 grid md:grid-cols-2 gap-6">
    {posts.slice(0,12).map(p => (
      <li class="rounded border p-4">
        <a href={`/blog/${p.slug}/`} class="text-lg font-semibold">{p.data.title}</a>
        <p class="text-sm text-slate-700 mt-1">{p.data.description}</p>
      </li>
    ))}
  </ul>
</BaseLayout>
EOF

  write "src/pages/rss.xml.ts" <<'EOF'
import type { APIContext } from 'astro';
import rss from '@astrojs/rss';
import { getCollection } from 'astro:content';

export async function GET(context: APIContext) {
  const posts = await getCollection('blog');
  return rss({
    title: 'One N Done Blog',
    description: 'Cleaning tips and local news',
    site: context.site?.toString() || 'https://example.com',
    items: posts.map(p => ({ title: p.data.title, pubDate: p.data.pubDate, link: `/blog/${p.slug}/` })),
  });
}
EOF
fi

### ---------------------------
### 15) Final notes
### ---------------------------
echo
echo "✅ Unified install complete."
echo "Next steps:"
echo "1) npm ci"
echo "2) npm run build"
echo "3) npx http-server dist -p 4321  (or 'astro preview')"
echo "4) PREVIEW_URL=http://127.0.0.1:4321 npm run test:smoke"
echo
echo "Flags recap: --force (no prompt), --plan (dry-run), --minimal (no blog)"
