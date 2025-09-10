#!/usr/bin/env bash
set -euo pipefail

# Unified Bootstrap (All-in-One)
# - Astro 5 + Tailwind v4 (single Vite pipeline)
# - Suburbs + Services SSG
# - Safe JSON-LD
# - SEO Report
# - Transparent Lift Pack invariants
# - Geo Sync (from CSV/GeoJSON/content) + Geo Doctor (strict/explain/graph/write)
# Idempotent; pass --force to overwrite, --plan for dry-run, --strict for picky mode.

FORCE=0; PLAN=0; STRICT=0; SITE_URL="${SITE_URL:-http://localhost:4321}"

usage(){ cat <<'H'
Usage:
  ./unified-bootstrap.sh [--force] [--plan] [--strict] [--site=URL]

Flags:
  --force   Overwrite existing files where safe
  --plan    Dry-run
  --strict  Fail on warnings (good for CI)
  --site    Public site URL (also honors SITE_URL env)
H
}

for a in "$@"; do
  case "$a" in
    --force) FORCE=1;;
    --plan) PLAN=1;;
    --strict) STRICT=1;;
    --site=*) SITE_URL="${a#--site=}";;
    -h|--help) usage; exit 0;;
    *) echo "Unknown arg: $a"; usage; exit 2;;
  esac
done

log(){ printf "\033[1;36m[unified]\033[0m %s\n" "$*"; }
warn(){ printf "\033[33m[warn]\033[0m %s\n" "$*"; }

write(){ # write <path> <<'EOF' ... EOF
  local p="$1"; local d; d="$(dirname "$p")"
  [[ "$PLAN" == 1 ]] && { log "PLAN: would write $p"; cat >/dev/null; return 0; }
  mkdir -p "$d"
  if [[ -f "$p" && "$FORCE" -ne 1 ]]; then warn "exists: $p (use --force)"; cat >/dev/null; return 0; fi
  cat >"$p"; log "wrote: $p"
}

# Folders
for d in src/pages src/layouts src/components src/lib src/lib/geo public scripts/geo scripts/seo scripts/invariants scripts/smokes data __ai tmp; do
  [[ "$PLAN" == 1 ]] && log "PLAN: ensure $d" || mkdir -p "$d"
done

# package.json (adds geo:sync + geo:doctor + guard suite)
write package.json <<'JSON'
{
  "name": "onendone-unified",
  "private": true,
  "type": "module",
  "engines": { "node": ">=20.3.0 <21 || >=22" },
  "scripts": {
    "dev": "astro dev",
    "build": "astro build",
    "preview": "astro preview --host",
    "check": "astro check --content",
    "geo:sync": "node scripts/geo/sync-doctor-inputs.mjs",
    "geo:doctor": "node scripts/geo/doctor.mjs",
    "geo:doctor:strict": "CI=1 node scripts/geo/doctor.mjs --strict",
    "seo:report": "node scripts/seo/report.mjs",
    "guard:all": "node scripts/invariants/guard-all.mjs",
    "smoke:build": "node scripts/smokes/build-smokes.mjs",
    "test:e2e": "node scripts/smokes/run-smokes.mjs",
    "predeploy": "npm run check && npm run geo:sync && npm run geo:doctor:strict && npm run build && npm run seo:report && npm run guard:all",
    "postinstall": "node -e \"console.log('✅ Postinstall ok')\""
  },
  "dependencies": {
    "astro": "^5.13.4",
    "@tailwindcss/vite": "^4.1.0",
    "tailwindcss": "^4.1.0"
  },
  "devDependencies": {
    "@astrojs/check": "^0.8.1",
    "@playwright/test": "^1.47.1",
    "fast-glob": "^3.3.2",
    "node-html-parser": "^6.1.13",
    "picocolors": "^1.0.0",
    "zod": "^3.23.8"
  }
}
JSON

# Astro config with Tailwind v4 single pipeline
write astro.config.mjs <<JS
import { defineConfig } from 'astro/config'
import tailwind from '@tailwindcss/vite'
export default defineConfig({
  site: process.env.SITE_URL || '${SITE_URL}',
  vite: { plugins: [tailwind()] },
  server: { host: true }
})
JS

# Tailwind v4 entry
write src/styles/tailwind.css <<'CSS'
@import "tailwindcss";
/* Add tokens/overrides with @theme / @utility as needed */
CSS

# Base layout (safe JSON-LD)
write src/layouts/BaseLayout.astro <<'ASTRO'
---
import '../styles/tailwind.css'
interface Props { title:string; description?:string; canonical?:string; jsonld?:any }
const { title, description='', canonical, jsonld } = Astro.props
const s = (v:any)=>JSON.stringify(v).replace(/</g,'\\u003c')
---
<html lang="en" class="h-full">
  <head>
    <meta charset="utf-8" /><meta name="viewport" content="width=device-width,initial-scale=1" />
    <title>{title}</title>
    {description && <meta name="description" content={description} />}
    {canonical && <link rel="canonical" href={canonical} />}
    <slot name="head" />
    {jsonld && (Array.isArray(jsonld)
      ? jsonld.map(n => <script type="application/ld+json" set:html={s(n)} />)
      : <script type="application/ld+json" set:html={s(jsonld)} />)}
  </head>
  <body class="min-h-full bg-white text-slate-900">
    <header class="sticky top-0 z-40 bg-white/80 backdrop-blur border-b border-slate-200">
      <div class="mx-auto max-w-6xl px-4 py-3 flex items-center justify-between">
        <a href="/" class="font-semibold">One N Done Bond Clean</a>
        <nav class="text-sm"><a href="/services" class="mr-4 hover:underline">Services</a><a href="/suburbs" class="mr-4 hover:underline">Suburbs</a><a href="/blog" class="hover:underline">Blog</a></nav>
      </div>
    </header>
    <main class="mx-auto max-w-6xl px-4"><slot /></main>
    <footer class="mt-16 border-t border-slate-200">
      <div class="mx-auto max-w-6xl px-4 py-8 text-sm text-slate-600">© {new Date().getFullYear()} One N Done Bond Clean · Fully Insured · Police-checked</div>
    </footer>
  </body>
</html>
ASTRO

# Components: Review chips, Sticky CTA, Nearby
write src/components/ReviewChips.astro <<'ASTRO'
---
const items = Astro.props.items ?? [
  { label: "Fully Insured" }, { label: "Police-checked" }, { label: "5★ Google Rated" }
]
---
<div class="flex flex-wrap gap-2 my-3">
  {items.map(i => <span class="rounded-full border border-slate-200 px-3 py-1 text-sm">{i.label}</span>)}
</div>
ASTRO

write src/components/StickyCTA.astro <<'ASTRO'
---
const label = Astro.props.label ?? "Get a fast quote"
const href = Astro.props.href ?? "/quote"
---
<div class="fixed inset-x-0 bottom-0 z-50 md:hidden">
  <div class="mx-auto max-w-6xl px-4 pb-4">
    <a href={href} class="block text-center font-semibold py-3 rounded-xl bg-slate-900 text-white shadow">{label}</a>
  </div>
</div>
ASTRO

write src/components/NearbySuburbs.astro <<'ASTRO'
---
const { items = [] } = Astro.props
---
{items.length>0 && (
  <section class="mt-8">
    <h2 class="text-lg font-semibold mb-3">Nearby suburbs</h2>
    <div class="grid grid-cols-2 sm:grid-cols-3 md:grid-cols-4 gap-2">
      {items.map(s => <a href={`/suburbs/${s.slug}/`} class="block border border-slate-200 rounded-lg px-3 py-2 hover:bg-slate-50">{s.name}</a>)}
    </div>
  </section>
)}
ASTRO

# Libs: urls, suburbs, services (seed; replace with your full data)
write src/lib/urls.ts <<'TS'
export const site = (import.meta.env.SITE_URL || 'http://localhost:4321').replace(/\/$/,'')
export const urlForSuburb  = (slug:string) => `${site}/suburbs/${slug}/`
export const urlForService = (svc:string,sub:string) => `${site}/services/${svc}/${sub}/`
TS

write src/lib/suburbs.ts <<'TS'
export type Suburb = { slug:string; name:string; region?:string; lat?:number; lng?:number; neighbors?:string[] }
export const SUBURBS: Suburb[] = [
  { slug:"ipswich", name:"Ipswich", region:"QLD", neighbors:["ripley"] },
  { slug:"ripley",  name:"Ripley",  region:"QLD", neighbors:["ipswich"] }
]
export const findSuburbBySlug = (slug:string)=> SUBURBS.find(s=>s.slug===slug) || null
export function nearby(slug:string, max=6){
  const me = findSuburbBySlug(slug); if(!me) return []
  const ids = me.neighbors||[]; return SUBURBS.filter(s=>ids.includes(s.slug)).slice(0,max)
}
TS

write src/lib/services.ts <<'TS'
export type Service = { key:string; name:string; slug:string; includes:string[]; summary?:string; cta?:string }
export const SERVICES: Record<string,Service> = {
  "bathroom-deep-clean": { key:"bathroom-deep-clean", name:"Bathroom Deep Clean", slug:"bathroom-deep-clean",
    includes:["Tile & grout scrub","Glass & chrome polish","Mould spot treatment","Exhaust & vents dusted","Mirror streak-free finish"],
    summary:"Intensive bathroom reset to hotel-fresh standard.", cta:"Book a Bathroom Deep Clean" },
  "bond-clean": { key:"bond-clean", name:"Bond Cleaning", slug:"bond-clean",
    includes:["Kitchen degrease & detail","Bathrooms deep clean","Walls & skirtings wipe","Oven & cooktop detail","Agent-ready finish"],
    summary:"Agent-friendly exit clean with bond-back friendly approach.", cta:"Get a Bond Clean quote" }
}
export const getService = (k:string)=> SERVICES[k]
export const listSiblingServices = (except:string)=> Object.values(SERVICES).filter(s=>s.key!==except)
TS

# Pages: Home, Suburb, Service
write src/pages/index.astro <<'ASTRO'
---
import Base from '../layouts/BaseLayout.astro'
import ReviewChips from '../components/ReviewChips.astro'
const jsonld = { "@context":"https://schema.org", "@type":"LocalBusiness", "name":"One N Done Bond Clean", "url":Astro.site, "areaServed":"Brisbane, Ipswich and surrounds", "telephone":"+61-400-000-000" }
---
<Base title="Bond Cleaning • One N Done" description="Fast, agent-friendly bond cleaning in Brisbane, Ipswich and surrounds." jsonld={jsonld}>
  <section class="py-10">
    <h1 class="text-3xl md:text-4xl font-bold">Bond Cleaning in South-East Queensland</h1>
    <p class="mt-2 text-slate-600">Fully insured, agent-friendly, and guaranteed.</p>
    <ReviewChips />
    <div class="mt-6 flex gap-3">
      <a href="/quote" class="px-5 py-3 rounded-xl bg-slate-900 text-white font-semibold">Get a fast quote</a>
      <a href="/services" class="px-5 py-3 rounded-xl border border-slate-200 font-semibold">See services</a>
    </div>
  </section>
</Base>
ASTRO

write src/pages/suburbs/[suburb].astro <<'ASTRO'
---
import Base from '../../layouts/BaseLayout.astro'
import ReviewChips from '../../components/ReviewChips.astro'
import Nearby from '../../components/NearbySuburbs.astro'
import { findSuburbBySlug, nearby } from '../../lib/suburbs'
import { listSiblingServices } from '../../lib/services'
import { urlForSuburb } from '../../lib/urls'
export async function getStaticPaths(){ const { SUBURBS } = await import('../../lib/suburbs.ts'); return SUBURBS.map(s=>({params:{suburb:s.slug}})) }
const { suburb } = Astro.params
const sub = findSuburbBySlug(suburb!)
if(!sub) return Astro.redirect('/404')
const jsonld = {"@context":"https://schema.org","@type":"Service","serviceType":"Cleaning Service","areaServed":sub.name,"url":urlForSuburb(sub.slug)}
---
<Base title={`Bond Cleaning in ${sub.name}`} description={`Professional bond cleaning in ${sub.name} and nearby.`} canonical={urlForSuburb(sub.slug)} jsonld={jsonld}>
  <section class="py-10">
    <h1 class="text-3xl md:text-4xl font-bold">Bond Cleaning in {sub.name}</h1>
    <p class="mt-2 text-slate-600">Fully insured, agent-friendly, and guaranteed.</p>
    <ReviewChips />
    <div class="mt-6">
      <h2 class="text-lg font-semibold mb-2">Popular services in {sub.name}</h2>
      <div class="flex flex-wrap gap-2">
        {listSiblingServices('').map(s => <a href={`/services/${s.slug}/${sub.slug}/`} class="px-4 py-2 rounded-lg border border-slate-200 hover:bg-slate-50">{s.name}</a>)}
      </div>
    </div>
    <Nearby items={nearby(sub.slug)} />
  </section>
</Base>
ASTRO

write src/pages/services/[service]/[suburb].astro <<'ASTRO'
---
import Base from '../../../layouts/BaseLayout.astro'
import ReviewChips from '../../../components/ReviewChips.astro'
import Nearby from '../../../components/NearbySuburbs.astro'
import { getService, listSiblingServices } from '../../../lib/services'
import { findSuburbBySlug, nearby } from '../../../lib/suburbs'
import { urlForService } from '../../../lib/urls'
export async function getStaticPaths(){
  const { SUBURBS } = await import('../../../lib/suburbs.ts')
  const { SERVICES } = await import('../../../lib/services.ts')
  const out = []; for (const s of Object.values(SERVICES)) for (const sub of SUBURBS) out.push({ params:{ service:s.slug, suburb:sub.slug } })
  return out
}
const { service, suburb } = Astro.params
const svc = getService(service!); const sub = findSuburbBySlug(suburb!)
if(!svc || !sub) return Astro.redirect('/404')
const jsonld = [{ "@context":"https://schema.org", "@type":"Service", "name":svc.name, "areaServed":sub.name, "url":urlForService(svc.slug, sub.slug) }]
---
<Base title={`${svc.name} in ${sub.name}`} description={`${svc.summary || svc.name} available in ${sub.name}.`} canonical={urlForService(svc.slug, sub.slug)} jsonld={jsonld}>
  <section class="py-10">
    <h1 class="text-3xl md:text-4xl font-bold">{svc.name} in {sub.name}</h1>
    <p class="mt-2 text-slate-600">Fully insured, agent-friendly, and guaranteed.</p>
    <ReviewChips />
    <div class="mt-6">
      <h2 class="text-lg font-semibold mb-2">What’s included</h2>
      <ul class="grid grid-cols-1 md:grid-cols-2 gap-x-6 list-disc pl-6">{svc.includes.map(i => <li class="py-1">{i}</li>)}</ul>
    </div>
    <div class="mt-6">
      <h2 class="text-lg font-semibold mb-2">Also available</h2>
      <div class="flex flex-wrap gap-2">{listSiblingServices(svc.key).map(s => <a href={`/services/${s.slug}/${sub.slug}/`} class="px-4 py-2 rounded-lg border border-slate-200 hover:bg-slate-50">{s.name}</a>)}</div>
    </div>
    <Nearby items={nearby(sub.slug)} />
  </section>
</Base>
ASTRO

# Blog index placeholder
write src/pages/blog/index.astro <<'ASTRO'
---
import Base from '../../layouts/BaseLayout.astro'
---
<Base title="Blog • One N Done" description="Articles and tips.">
  <section class="py-10">
    <h1 class="text-3xl md:text-4xl font-bold">Blog</h1>
    <p class="mt-2 text-slate-600">Tips, guides, and stories.</p>
  </section>
</Base>
ASTRO

# SEO Reporter (canonicals & JSON-LD parse)
write scripts/seo/report.mjs <<'JS'
import fg from 'fast-glob'
import { parse } from 'node-html-parser'
import fs from 'node:fs'; import pc from 'picocolors'
const pages = await fg('dist/**/*.html',{dot:false})
const out='__ai/SEO_REPORT.md'; const sum={total:pages.length,missingCanonical:0,badJsonLd:0,duplicateCanonicals:0}
let report=`# SEO Report\n\nScanned ${pages.length} HTML pages in dist.\n\n`
for (const p of pages){
  const html=fs.readFileSync(p,'utf8'); const root=parse(html)
  const canon=root.querySelectorAll('link[rel="canonical"]'); const scripts=root.querySelectorAll('script[type="application/ld+json"]')
  if (canon.length===0){ sum.missingCanonical++; report+=`- ❌ Missing canonical: ${p}\n` }
  else if (canon.length>1){ sum.duplicateCanonicals++; report+=`- ⚠️ Duplicate canonicals (${canon.length}): ${p}\n` }
  for (const s of scripts){ try{ JSON.parse(s.text||'{}') } catch{ sum.badJsonLd++; report+=`- ❌ JSON-LD parse error: ${p}\n`; break } }
}
report+=`\n## Summary\n- Missing canonical: ${sum.missingCanonical}\n- Duplicate canonicals: ${sum.duplicateCanonicals}\n- JSON-LD parse errors: ${sum.badJsonLd}\n`
fs.writeFileSync(out,report,'utf8'); console.log(pc.green(`SEO report → ${out}`))
if (process.env.CI && (sum.missingCanonical||sum.badJsonLd||sum.duplicateCanonicals)){ console.error(pc.red('SEO report found issues.')); process.exit(1) }
JS

# Invariants (Transparent Lift Pack)
write scripts/invariants/anchor-diversity.mjs <<'JS'
import fg from 'fast-glob'; import { parse } from 'node-html-parser'; import fs from 'node:fs'
const pages=await fg('dist/**/*.html'); let bad=0
for (const p of pages){ const html=fs.readFileSync(p,'utf8'); const root=parse(html); const a=root.querySelectorAll('a'); if (a.length<5) continue
  const map=new Map(); for (const el of a){ const t=(el.innerText||'').trim().toLowerCase(); if(!t) continue; map.set(t,(map.get(t)||0)+1) }
  const max=Math.max(0,...map.values()); const r=max/Math.max(1,a.length); if (r>0.6){ console.error(`[anchor-diversity] ${p} has ${Math.round(r*100)}% identical anchor text.`); bad++ }
}
if (bad) process.exit(1)
JS

write scripts/invariants/schema-lockstep.mjs <<'JS'
import fg from 'fast-glob'; import { parse } from 'node-html-parser'; import fs from 'node:fs'
const pages=await fg('dist/**/*.html'); let bad=0
for (const p of pages){
  const html=fs.readFileSync(p,'utf8'); const root=parse(html); const h1=(root.querySelector('h1')?.innerText||'').toLowerCase()
  const scripts=root.querySelectorAll('script[type="application/ld+json"]')
  for (const s of scripts){ try{
    const node=JSON.parse(s.text||'{}'); const nodes=Array.isArray(node)?node:[node]
    for (const n of nodes){ if (n['@type']==='Service' && typeof n.name==='string'){ if (!h1.includes(n.name.toLowerCase())){ console.error(`[schema-lockstep] ${p} h1 must include Service.name (${n.name}).`); bad++ } } }
  }catch{} }
}
if (bad) process.exit(1)
JS

write scripts/invariants/no-ua-conditionals.mjs <<'JS'
import fg from 'fast-glob'; import fs from 'node:fs'
const files=await fg('dist/**/*.js'); let bad=0
for (const f of files){ const txt=fs.readFileSync(f,'utf8'); if (/navigator\.userAgent/i.test(txt)){ console.error(`[no-ua] Disallowed navigator.userAgent usage in ${f}`); bad++ } }
if (bad) process.exit(1)
JS

write scripts/invariants/no-hidden-keywords.mjs <<'JS'
import fg from 'fast-glob'; import { parse } from 'node-html-parser'; import fs from 'node:fs'
const pages=await fg('dist/**/*.html'); let bad=0
for (const p of pages){ const html=fs.readFileSync(p,'utf8'); const root=parse(html); const hidden=root.querySelectorAll('[style*="display:none"]')
  for (const el of hidden){ const words=(el.innerText||'').trim().split(/\s+/).filter(Boolean); if (words.length>20){ console.error(`[no-hidden] Hidden long-text block in ${p}`); bad++ } }
}
if (bad) process.exit(1)
JS

write scripts/invariants/sitemap-sanity.mjs <<'JS'
import fs from 'node:fs'; import pc from 'picocolors'
if (!fs.existsSync('dist/sitemap.xml')){ console.error(pc.red('[sitemap] dist/sitemap.xml missing')); process.exit(1) }
const xml=fs.readFileSync('dist/sitemap.xml','utf8'); for (const frag of ['/suburbs/','/services/','/blog']){ if (!xml.includes(frag)) console.error(pc.yellow(`[sitemap] ${frag} not found (warn)`)) }
JS

write scripts/invariants/similarity-guard.mjs <<'JS'
import fg from 'fast-glob'; import { parse } from 'node-html-parser'; import fs from 'node:fs'
const tok=s=>s.toLowerCase().replace(/[^a-z0-9\s]/g,' ').split(/\s+/).filter(Boolean)
const jac=(A,B)=>{const a=new Set(A),b=new Set(B);const inter=[...a].filter(x=>b.has(x)).length; const uni=new Set([...a,...b]).size; return inter/Math.max(1,uni)}
const files=await fg('dist/suburbs/**/*.html'); const arr=[]
for (const p of files){ const html=fs.readFileSync(p,'utf8'); const root=parse(html); const txt=(root.querySelector('main')?.innerText||root.innerText||'').trim(); arr.push({p, t:tok(txt)}) }
let bad=0; for (let i=0;i<arr.length;i++) for (let j=i+1;j<arr.length;j++){ const s=jac(arr[i].t,arr[j].t); if (s>0.9){ console.error(`[similarity] ${arr[i].p} and ${arr[j].p} are ${Math.round(s*100)}% similar`); bad++ } }
if (bad) process.exit(1)
JS

write scripts/invariants/guard-all.mjs <<'JS'
import { spawn } from 'node:child_process'
const cmds=[
  ['node','scripts/invariants/anchor-diversity.mjs'],
  ['node','scripts/invariants/schema-lockstep.mjs'],
  ['node','scripts/invariants/no-ua-conditionals.mjs'],
  ['node','scripts/invariants/no-hidden-keywords.mjs'],
  ['node','scripts/invariants/sitemap-sanity.mjs'],
  ['node','scripts/invariants/similarity-guard.mjs']
]
let bad=0; for (const [cmd,...args] of cmds){ const code=await new Promise(r=>{ const p=spawn(cmd,args,{stdio:'inherit'}); p.on('close',r) }); if (code!==0) bad++ }
process.exit(bad?1:0)
JS

# GEO SYNC (from your agent) — builds areas.clusters.json, areas.adj.json, geo.config.json, proximity.json
# Source: sync-doctor-inputs.mjs
write scripts/geo/sync-doctor-inputs.mjs <<'JS'
#!/usr/bin/env node
import fs from 'node:fs';
import path from 'node:path';

const pContentClusters = 'src/content/areas.clusters.json';
const pSuburbs = 'src/data/suburbs.json';
const pAdjSrc = 'src/data/adjacency.json';
// Enriched sources (optional)
const GEO_DIR = 'src/components/Geo docter files';
const GEO_TRUE = path.join(GEO_DIR, 'Suburb Data True');
const pAdjRich = path.join(GEO_TRUE, 'adjacency.json');
const pCSV1 = path.join(GEO_DIR, 'suburbs_enriched.csv');
const pCSV2 = path.join(GEO_DIR, 'suburbs.csv');
const pGJ1 = path.join(GEO_DIR, 'suburbs_enriched.geojson');
const pGJ2 = path.join(GEO_DIR, 'suburbs.geojson');

const pAreasClusters = 'src/data/areas.clusters.json';
const pAreasAdj = 'src/data/areas.adj.json';
const pGeoCfg = 'src/data/geo.config.json';
const pProx = 'src/data/proximity.json';
const pTrueClusters = path.join(GEO_TRUE, 'clusters.json');

function readJson(p, fallback) { try { return JSON.parse(fs.readFileSync(p,'utf8')); } catch { return fallback; } }
function writeJson(p, data) { fs.mkdirSync(path.dirname(p), { recursive: true }); fs.writeFileSync(p, JSON.stringify(data, null, 2) + '\n'); }

const slugify = (s='') => String(s).trim().toLowerCase().normalize('NFKD')
  .replace(/[^\p{L}\p{N}]+/gu, '-').replace(/-+/g,'-').replace(/^-|-$/g,'');

function readText(p) { try { return fs.readFileSync(p, 'utf8'); } catch { return null; } }
function parseCsv(txt) {
  if (!txt) return [];
  const lines = txt.split(/\r?\n/).filter(Boolean);
  if (!lines.length) return [];
  const header = lines[0].split(',').map(h=>h.trim().toLowerCase());
  const idx = (names) => names.map(n=>header.indexOf(n)).find(i=>i>=0) ?? -1;
  const iSlug = idx(['slug','suburb_slug']);
  const iName = idx(['name','suburb','suburb_name']);
  const iLat  = idx(['lat','latitude']);
  const iLng  = idx(['lng','lon','longitude']);
  const out = [];
  for (let i=1;i<lines.length;i++){
    const cells = lines[i].split(',');
    if (cells.length < header.length) continue;
    const rawSlug = iSlug>=0 ? cells[iSlug] : '';
    const rawName = iName>=0 ? cells[iName] : '';
    const slug = slugify(rawSlug || rawName);
    if (!slug) continue;
    const lat = iLat>=0 ? Number(cells[iLat]) : NaN;
    const lng = iLng>=0 ? Number(cells[iLng]) : NaN;
    out.push({ slug, name: rawName || rawSlug || slug, lat: Number.isFinite(lat)?lat:undefined, lng: Number.isFinite(lng)?lng:undefined });
  }
  return out;
}

function centroidOfGeometry(geom) {
  if (!geom || !geom.type) return null;
  const avg = (arr) => arr.reduce((a,b)=>a+b,0)/arr.length;
  if (geom.type === 'Point') {
    const [lng,lat] = geom.coordinates||[]; return Number.isFinite(lat)&&Number.isFinite(lng)?{lat,lng}:null;
  }
  if (geom.type === 'Polygon') {
    const ring = geom.coordinates?.[0];
    if (!Array.isArray(ring) || !ring.length) return null;
    const lats = ring.map(c=>c[1]).filter(Number.isFinite); const lngs = ring.map(c=>c[0]).filter(Number.isFinite);
    if (!lats.length || !lngs.length) return null;
    return { lat: avg(lats), lng: avg(lngs) };
  }
  if (geom.type === 'MultiPolygon') {
    const rings = (geom.coordinates||[]).flat();
    const lats = rings.map(c=>c[1]).filter(Number.isFinite); const lngs = rings.map(c=>c[0]).filter(Number.isFinite);
    if (!lats.length || !lngs.length) return null;
    return { lat: avg(lats), lng: avg(lngs) };
  }
  return null;
}

function parseGeoJson(txt) {
  try {
    const gj = JSON.parse(txt);
    const feats = Array.isArray(gj?.features) ? gj.features : [];
    const out = [];
    for (const f of feats) {
      const props = f?.properties || {};
      const name = String(props.name || props.suburb || props.SA2_NAME || '').trim();
      const slug = slugify(String(props.slug || name));
      if (!slug) continue;
      const lat = Number.isFinite(Number(props.lat)) ? Number(props.lat) : undefined;
      const lng = Number.isFinite(Number(props.lng)) ? Number(props.lng) : undefined;
      let coords = (lat!=null && lng!=null) ? { lat, lng } : centroidOfGeometry(f.geometry);
      out.push({ slug, name: name || slug, lat: coords?.lat, lng: coords?.lng });
    }
    return out;
  } catch { return []; }
}

// Build areas.clusters.json from content clusters + LGA true clusters + optional coords from suburbs.json/CSV/GeoJSON
const content = readJson(pContentClusters, { clusters: [] });
const suburbsList = readJson(pSuburbs, []);
// Build an enrichment map from CSV/GeoJSON if present
const enrich = new Map();
for (const file of [pCSV1, pCSV2]) {
  const txt = readText(file); if (!txt) continue;
  for (const r of parseCsv(txt)) enrich.set(r.slug, r);
}
for (const file of [pGJ1, pGJ2]) {
  const txt = readText(file); if (!txt) continue;
  for (const r of parseGeoJson(txt)) {
    if (!enrich.has(r.slug)) enrich.set(r.slug, r); // prefer explicit CSV over derived centroid
  }
}
const bySlug = new Map();
const byName = new Map();
for (const s of suburbsList) {
  const slug = s?.slug || slugify(s?.name || '');
  if (!slug) continue;
  bySlug.set(slug, s);
  if (s?.name) byName.set(String(s.name).toLowerCase(), s);
}

// 1) Start with canonical clusters from content
const clusterSets = new Map(); // slug -> Set(suburbSlug)
const clusterNames = new Map(); // slug -> display name
if (Array.isArray(content?.clusters)) {
  for (const c of content.clusters) {
    const slug = slugify(c.slug || '');
    if (!slug) continue;
    clusterNames.set(slug, c.name || c.slug || slug);
    const set = clusterSets.get(slug) || new Set();
    for (const n of (Array.isArray(c?.suburbs) ? c.suburbs : [])) {
      const s = slugify(String(n));
      if (s) set.add(s);
    }
    clusterSets.set(slug, set);
  }
}

// 2) Merge LGA true clusters into canonical clusters via a simple mapping
const trueClusters = readJson(pTrueClusters, null);
if (trueClusters && typeof trueClusters === 'object' && !Array.isArray(trueClusters)) {
  const mapLgaToCanonical = (k) => {
    const key = slugify(k);
    if (key.includes('brisbane')) return 'brisbane';
    if (key.includes('ipswich')) return 'ipswich';
    if (key.includes('logan')) return 'logan';
    return null;
  };
  for (const [lgaKey, rec] of Object.entries(trueClusters)) {
    const target = mapLgaToCanonical(lgaKey);
    if (!target) continue;
    const set = clusterSets.get(target) || new Set();
    const list = Array.isArray(rec?.suburbs) ? rec.suburbs : [];
    for (const n of list) {
      const s = slugify(String(n));
      if (s) set.add(s);
    }
    clusterSets.set(target, set);
    if (!clusterNames.has(target)) clusterNames.set(target, target.charAt(0).toUpperCase()+target.slice(1));
  }
}

// 3) Ensure adjacency-rich sources don’t reference non-existent suburbs when we can map them from true clusters
const clusters = [];
for (const [slug, set] of clusterSets.entries()) {
  const suburbs = [];
  for (const s of set) {
    const nameGuess = s.replace(/-/g, ' ').replace(/\b\w/g, (m)=>m.toUpperCase());
    const match = bySlug.get(s) || byName.get(nameGuess.toLowerCase()) || enrich.get(s);
    const lat = (match?.coords?.lat ?? match?.lat);
    const lng = (match?.coords?.lng ?? match?.lng);
    const entry = { slug: s, name: match?.name || nameGuess };
    if (typeof lat === 'number' && typeof lng === 'number') { entry.lat = lat; entry.lng = lng; }
    suburbs.push(entry);
  }
  clusters.push({ slug, name: clusterNames.get(slug) || slug, suburbs });
}

// Fallback if none
if (!clusters.length) {
  if (Array.isArray(content?.clusters)) {
    for (const c of content.clusters) {
      const suburbs = [];
      const list = Array.isArray(c?.suburbs) ? c.suburbs : [];
      for (const n of list) {
        const name = String(n);
        const s = slugify(name);
        const match = bySlug.get(s) || byName.get(name.toLowerCase()) || enrich.get(s);
        const lat = (match?.coords?.lat ?? match?.lat);
        const lng = (match?.coords?.lng ?? match?.lng);
        const entry = { slug: s, name };
        if (typeof lat === 'number' && typeof lng === 'number') { entry.lat = lat; entry.lng = lng; }
        suburbs.push(entry);
      }
      clusters.push({ slug: c.slug, name: c.name || c.slug, suburbs });
    }
  }
}

writeJson(pAreasClusters, { clusters });

// Build adjacency: prefer rich true-data if present, else copy flat src/data/adjacency.json
let adjOut = {};
const rich = readJson(pAdjRich, null);
if (rich && typeof rich === 'object' && !Array.isArray(rich)) {
  const valid = new Set(); for (const c of clusters) for (const s of c.suburbs) valid.add(slugify(s.slug));
  const mapped = {};
  for (const [srcRaw, rec] of Object.entries(rich)) {
    const src = slugify(srcRaw);
    if (!valid.has(src)) continue;
    const input = Array.isArray(rec?.adjacent_suburbs) ? rec.adjacent_suburbs : [];
    const seen = new Set(); const out = [];
    for (const tRaw of input) {
      const t = slugify(tRaw); if (!t || t===src) continue; if (!valid.has(t)) continue; if (seen.has(t)) continue; seen.add(t); out.push(t);
    }
    if (out.length) mapped[src] = out;
  }
  adjOut = mapped;
} else {
  adjOut = readJson(pAdjSrc, {});
}
writeJson(pAreasAdj, adjOut);

// Create minimal geo.config.json if missing
if (!fs.existsSync(pGeoCfg)) {
  writeJson(pGeoCfg, {
    data: { nearby: { limit: 6 }, adjacencyBoost: 24, clusterBoost: 200, biasKm: 12, crossClusterPenalty: 200 }
  });
}

// Create minimal proximity.json if missing
if (!fs.existsSync(pProx)) { writeJson(pProx, { nearby: {} }); }

console.log('[sync-doctor-inputs] Wrote:', pAreasClusters, pAreasAdj, fs.existsSync(pGeoCfg)?'(cfg exists)':'(cfg created)', fs.existsSync(pProx)?'(prox exists)':'(prox created)');
JS

# GEO DOCTOR (strict/explain/graph/write) — from your agent
write scripts/geo/doctor.mjs <<'JS'
#!/usr/bin/env node
/*
 See user message for full description. This is the exact Geo Doctor script.
*/
import fs from 'node:fs';
import path from 'node:path';

const DATA = 'src/data';
const OUT_DIR = '__ai';
const TMP = 'tmp';

const pClusters   = path.join(DATA, 'areas.clusters.json');
const pClusterMap = path.join(DATA, 'cluster_map.json');
const pAdj        = path.join(DATA, 'areas.adj.json');
const pProx       = path.join(DATA, 'proximity.json');
const pCfg        = path.join(DATA, 'geo.config.json');

const ARGS = new Set(process.argv.slice(2));
const getArgVal = (name, def=null) => {
  const i = process.argv.indexOf(name);
  return i > -1 ? process.argv[i+1] ?? def : def;
};
const STRICT = ARGS.has('--strict') || !!process.env.CI;
const WRITE  = ARGS.has('--write');
const GRAPH  = ARGS.has('--graph');
const EXPLAIN = getArgVal('--explain', null);
const SUGGEST_SPLIT_CLUSTER = getArgVal('--suggest-split', null);
const SUGGEST_SPLIT_K = SUGGEST_SPLIT_CLUSTER ? Number(getArgVal(SUGGEST_SPLIT_CLUSTER, 3)) : null;
const DEFAULT_DIFF_SAMPLE = Math.max(1, Number(getArgVal('--diff-sample', 60)));
const FORCE_LIMIT = getArgVal('--limit', null) ? Number(getArgVal('--limit', null)) : null;

const color = (esc) => (s)=>`${esc}${s}\x1b[0m`;
const GREEN = color('\x1b[32m'), RED = color('\x1b[31m'), YELLOW = color('\x1b[33m'), BOLD = color('\x1b[1m');

const out = (p, data) => { fs.mkdirSync(path.dirname(p), { recursive: true }); fs.writeFileSync(p, data); };

function readJson(p, fallback=null) {
  try {
    if (!fs.existsSync(p)) return { ok:false, err:'ENOENT', data:fallback };
    const raw = fs.readFileSync(p,'utf8');
    return { ok:true, err:null, data: JSON.parse(raw) };
  } catch (e) {
    return { ok:false, err:String(e?.message||e), data:fallback };
  }
}

function isStr(x){ return typeof x==='string' && x.trim().length>0; }
function isNum(x){ return typeof x==='number' && Number.isFinite(x); }
const clamp = (n, lo, hi) => Math.max(lo, Math.min(hi, n));

/* -------------------- Load all -------------------- */
const clusters   = readJson(pClusters, { clusters: [] });
const clusterMap = readJson(pClusterMap, {});
const adj        = readJson(pAdj, {});
const prox       = readJson(pProx, { nearby: {} });
const cfg        = readJson(pCfg, {});

const limitCfg   = Number(cfg.data?.nearby?.limit ?? 6);
const LIMIT = FORCE_LIMIT ? Math.max(1, FORCE_LIMIT) : Math.max(1, limitCfg);

const weights = {
  adjacencyBoost: Number(cfg.data?.adjacencyBoost ?? 24),
  clusterBoost:   Number(cfg.data?.clusterBoost ?? 200),
  biasKm:         Number(cfg.data?.biasKm ?? 12),
  crossPenalty:   Number(cfg.data?.crossClusterPenalty ?? 200),
};

/* -------------------- Indexes -------------------- */
const issues = { missing:[], schema:[], referential:[], warnings:[] };

const clusterSlugs = [];
const suburbBySlug = new Map(); // slug -> {name, lat?, lng?, cluster}
if (!clusters.ok) {
  issues.missing.push(`Missing ${pClusters}: ${clusters.err || 'file not found'}`);
} else if (!Array.isArray(clusters.data?.clusters)) {
  issues.schema.push(`${pClusters} must be {clusters: []}`);
} else {
  for (const c of clusters.data.clusters) {
    if (!isStr(c?.slug)) { issues.schema.push(`Cluster missing/invalid slug`); continue; }
    clusterSlugs.push(c.slug);
    if (!Array.isArray(c?.suburbs)) { issues.schema.push(`Cluster ${c.slug} has no suburbs[]`); continue; }
    for (const s of c.suburbs) {
      if (!isStr(s?.slug)) issues.schema.push(`Suburb in cluster ${c.slug} missing slug`);
      if (!isStr(s?.name)) issues.schema.push(`Suburb ${s?.slug||'(unknown)'} missing name`);
      if (suburbBySlug.has(s.slug)) issues.schema.push(`Duplicate suburb slug "${s.slug}" across clusters`);
      suburbBySlug.set(s.slug, { name: s.name, lat: s.lat, lng: s.lng, cluster: c.slug });
    }
  }
}

if (clusterMap.ok) {
  const unknownClusters = Object.keys(clusterMap.data||{}).filter(k => !clusterSlugs.includes(k));
  for (const k of unknownClusters) issues.referential.push(`cluster_map.json references unknown cluster "${k}"`);
} else {
  issues.warnings.push(`cluster_map.json missing — region will be undefined in some UIs/LD.`);
}

/* Adjacency checks */
if (adj.ok) {
  for (const [src, list] of Object.entries(adj.data||{})) {
    if (!suburbBySlug.has(src)) issues.referential.push(`adjacency: source "${src}" not in clusters`);
    if (!Array.isArray(list)) { issues.schema.push(`adjacency["${src}"] must be string[]`); continue; }
    for (const dst of list) {
      if (dst === src) issues.schema.push(`adjacency: "${src}" lists itself`);
      if (!suburbBySlug.has(dst)) issues.referential.push(`adjacency: "${src}" -> "${dst}" not in clusters`);
    }
  }
}

/* Proximity checks */
if (prox.ok) {
  const nmap = prox.data?.nearby || {};
  const seenSrc = Object.keys(nmap);
  for (const src of seenSrc) {
    const arr = nmap[src];
    if (!suburbBySlug.has(src)) { issues.referential.push(`proximity: source "${src}" not in clusters`); continue; }
    if (!Array.isArray(arr)) { issues.schema.push(`proximity.nearby["${src}"] must be an array`); continue; }
    const seen = new Set();
    if (arr.length > LIMIT) issues.warnings.push(`proximity["${src}"] length ${arr.length} exceeds limit ${LIMIT}`);
    for (const item of arr) {
      if (!isStr(item?.slug)) issues.schema.push(`proximity["${src}"] item missing slug`);
      if (item?.slug === src) issues.schema.push(`proximity["${src}"] contains self`);
      if (seen.has(item?.slug)) issues.schema.push(`proximity["${src}"] duplicate "${item?.slug}"`);
      seen.add(item?.slug);
      if (item?.slug && !suburbBySlug.has(item.slug)) issues.referential.push(`proximity["${src}"] -> "${item.slug}" not in clusters`);
    }
  }
}

/* Coordinate sanity + coverage */
let missLatLng = 0, badRange = 0;
for (const [slug, r] of suburbBySlug) {
  const okLat = isNum(r.lat), okLng = isNum(r.lng);
  if (!okLat || !okLng) { missLatLng++; continue; }
  if (r.lat < -90 || r.lat > 90 || r.lng < -180 || r.lng > 180) badRange++;
}
if (missLatLng) issues.warnings.push(`${missLatLng} suburbs missing lat/lng (distance fallback limited)`);
if (badRange) issues.schema.push(`${badRange} suburbs have out-of-range coordinates`);

/* -------------------- Scoring & recompute -------------------- */
function haversineKm(a,b){
  const toRad = (x)=>x*Math.PI/180; const R=6371;
  const dLat=toRad(b.lat-a.lat), dLng=toRad(b.lng-a.lng);
  const s = Math.sin(dLat/2)**2 + Math.cos(toRad(a.lat))*Math.cos(toRad(b.lat))*Math.sin(dLng/2)**2;
  return 2*R*Math.asin(Math.sqrt(s));
}
const isSameCluster = (a,b) => a.cluster && b.cluster && a.cluster===b.cluster;

function scorePair(srcSlug, dstSlug) {
  const A = suburbBySlug.get(srcSlug), B = suburbBySlug.get(dstSlug);
  if (!A || !B) return { score:-Infinity, parts:{} };
  const parts = { adjacency:0, cluster:0, distance:0, crossPenalty:0 };
  const neighbors = Array.isArray(adj.data?.[srcSlug]) ? adj.data[srcSlug] : [];
  if (neighbors.includes(dstSlug)) parts.adjacency = weights.adjacencyBoost;
  if (isSameCluster(A,B)) parts.cluster = weights.clusterBoost;
  else parts.crossPenalty = -Math.abs(weights.crossPenalty);
  if (isNum(A.lat)&&isNum(A.lng)&&isNum(B.lat)&&isNum(B.lng)) {
    const km = haversineKm({lat:A.lat,lng:A.lng}, {lat:B.lat,lng:B.lng});
    parts.distance = -Math.abs(weights.biasKm) * km;
  }
  const score = parts.adjacency + parts.cluster + parts.distance + parts.crossPenalty;
  return { score, parts };
}

function recomputeNearby(srcSlug, max=LIMIT) {
  const pool = [];
  const A = suburbBySlug.get(srcSlug);
  if (!A) return [];
  for (const slug of suburbBySlug.keys()) if (slug !== srcSlug) {
    const { score } = scorePair(srcSlug, slug);
    pool.push({ slug, name: suburbBySlug.get(slug)?.name || slug, score });
  }
  pool.sort((x,y)=> y.score - x.score);
  return pool.slice(0, max).map(x => ({ slug:x.slug, name:x.name }));
}

/* -------------------- Proximity diff (sample) -------------------- */
const ALL_SUBURBS = Array.from(suburbBySlug.keys());
const sampleSuburbs = ALL_SUBURBS.slice(0, clamp(DEFAULT_DIFF_SAMPLE, 1, ALL_SUBURBS.length));
const diffs = [];
for (const s of sampleSuburbs) {
  const pre = Array.isArray(prox.data?.nearby?.[s]) ? prox.data.nearby[s].map(x=>x.slug) : [];
  const rec = recomputeNearby(s, LIMIT).map(x=>x.slug);
  const setPre = new Set(pre), setRec = new Set(rec);
  const missingFromPre = rec.filter(slug => !setPre.has(slug)).slice(0, 5);
  const extrasInPre = pre.filter(slug => !setRec.has(slug)).slice(0, 5);
  if (missingFromPre.length || extrasInPre.length) {
    diffs.push({ suburb: s, missingFromPre, extrasInPre });
  }
}

/* -------------------- Aggregate stats -------------------- */
const clusterSizes = {};
for (const c of clusterSlugs) clusterSizes[c] = 0;
for (const { cluster } of suburbBySlug.values()) if (cluster) clusterSizes[cluster]++;

let crossEdges = 0, totalEdges = 0, reciprocal = 0;
if (adj.ok) {
  for (const [src, list] of Object.entries(adj.data||{})) {
    for (const dst of list) {
      totalEdges++;
      const Csrc = suburbBySlug.get(src)?.cluster;
      const Cdst = suburbBySlug.get(dst)?.cluster;
      if (Csrc && Cdst && Csrc !== Cdst) crossEdges++;
      const back = adj.data?.[dst] || [];
      if (Array.isArray(back) && back.includes(src)) reciprocal++;
    }
  }
}
const reciprocityRate = totalEdges ? (reciprocal / totalEdges) : 0;

/* Big cluster hint */
const bigClusters = Object.entries(clusterSizes)
  .filter(([_, n]) => n >= 120)
  .map(([slug, n]) => `${slug} (${n})`);
if (bigClusters.length) {
  issues.warnings.push(`Large clusters detected: ${bigClusters.join(', ')} — consider subdividing for better nearby relevance.`);
}

/* -------------------- Explain (optional) -------------------- */
let explainOut = null;
if (EXPLAIN && suburbBySlug.has(EXPLAIN)) {
  const src = EXPLAIN;
  const scored = [];
  for (const dst of suburbBySlug.keys()) if (dst!==src) {
    const { score, parts } = scorePair(src, dst);
    scored.push({ dst, name: suburbBySlug.get(dst).name, score, parts });
  }
  scored.sort((a,b)=> b.score - a.score);
  explainOut = { source: src, top: scored.slice(0, 12), weights, limit: LIMIT };
  out(path.join(OUT_DIR, `geo-explain-${src}.json`), JSON.stringify(explainOut, null, 2));
}

/* -------------------- Graph (optional) -------------------- */
if (GRAPH && adj.ok) {
  let dot = 'graph G {\n  graph [overlap=false];\n  node [shape=point];\n';
  for (const [src, list] of Object.entries(adj.data||{})) {
    for (const dst of list) {
      dot += `  "${src}" -- "${dst}";\n`;
    }
  }
  dot += '}\n';
  out(path.join(OUT_DIR, 'geo-adjacency.dot'), dot);
}

/* -------------------- Write fixed proximity (optional) -------------------- */
let fixed = null;
if (WRITE) {
  const fixedNearby = {};
  for (const s of ALL_SUBURBS) {
    const current = Array.isArray(prox.data?.nearby?.[s]) ? prox.data.nearby[s] : [];
    const keep = [];
    const seen = new Set();
    for (const it of current) {
      if (!it || typeof it!=='object') continue;
      if (!isStr(it.slug)) continue;
      if (it.slug === s) continue;
      if (!suburbBySlug.has(it.slug)) continue;
      const key = it.slug;
      if (seen.has(key)) continue;
      seen.add(key);
      keep.push({ slug: it.slug, name: suburbBySlug.get(it.slug)?.name || it.slug });
      if (keep.length >= LIMIT) break;
    }
    if (keep.length < LIMIT) {
      const rec = recomputeNearby(s, LIMIT*2);
      for (const it of rec) {
        if (it.slug===s) continue;
        if (!suburbBySlug.has(it.slug)) continue;
        if (keep.find(k=>k.slug===it.slug)) continue;
        keep.push({ slug: it.slug, name: suburbBySlug.get(it.slug)?.name || it.slug });
        if (keep.length >= LIMIT) break;
      }
    }
    fixedNearby[s] = keep.slice(0, LIMIT);
  }
  fixed = { nearby: fixedNearby, meta: { limit: LIMIT, generatedAt: new Date().toISOString() } };
  out(path.join(OUT_DIR, 'geo-proximity-fixed.json'), JSON.stringify(fixed, null, 2));
}

/* -------------------- Smoke paths -------------------- */
const first = ALL_SUBURBS.slice(0, 6);
const smokePaths = [
  '/suburbs/','/services/',
  ...first.map(s=>`/suburbs/${s}/`),
  ...first.flatMap(s=>[
    `/services/spring-clean/${s}/`,
    `/services/bathroom-deep-clean/${s}/`
  ])
];
out(path.join(TMP, 'smoke-paths.json'), JSON.stringify({ paths: smokePaths }, null, 2));

/* -------------------- Reports -------------------- */
const report = {
  timestamp: new Date().toISOString(),
  files: {
    clusters:   { path:pClusters, ok:clusters.ok,   err:clusters.err },
    clusterMap: { path:pClusterMap, ok:clusterMap.ok, err:clusterMap.err },
    adjacency:  { path:pAdj, ok:adj.ok, err:adj.err },
    proximity:  { path:pProx, ok:prox.ok, err:prox.err },
    config:     { path:pCfg, ok:cfg.ok,  err:cfg.err }
  },
  config: { limit: LIMIT, weights },
  counts: {
    clusters: clusterSlugs.length,
    suburbs: suburbBySlug.size,
    adjacencySources: adj.ok ? Object.keys(adj.data||{}).length : 0,
    proximitySources: prox.ok ? Object.keys(prox.data?.nearby||{}).length : 0,
  },
  clusterSizes,
  adjacency: { totalEdges, crossClusterEdges: crossEdges, reciprocityRate },
  diffsSampled: sampleSuburbs.length,
  proximityDiffs: diffs.slice(0, 200),
  explain: explainOut ? { saved: `__ai/geo-explain-${EXPLAIN}.json` } : null,
  outputs: {
    reportJson: '__ai/geo-report.json',
    reportTxt:  '__ai/geo-report.txt',
    diff:       '__ai/geo-proximity-diff.json',
    fixed:      WRITE ? '__ai/geo-proximity-fixed.json' : null,
    graph:      GRAPH ? '__ai/geo-adjacency.dot' : null,
  },
  issues
};
const outFile = path.join(OUT_DIR, 'geo-report.json');
fs.mkdirSync(path.dirname(outFile), { recursive: true }); fs.writeFileSync(outFile, JSON.stringify(report, null, 2));

const diffFile = path.join(OUT_DIR, 'geo-proximity-diff.json');
fs.writeFileSync(diffFile, JSON.stringify(diffs, null, 2));

const topMsgs = [
  ...issues.missing.slice(0,10),
  ...issues.schema.slice(0,10),
  ...issues.referential.slice(0,10),
  ...issues.warnings.slice(0,10),
];
const txt =
`Geo Doctor
==========
Time: ${report.timestamp}

Files:
- clusters:   ${clusters.ok? 'OK' : 'MISSING/ERR'}
- clusterMap: ${clusterMap.ok? 'OK' : 'Missing'}
- adjacency:  ${adj.ok? 'OK' : 'Missing'}
- proximity:  ${prox.ok? 'OK' : 'Missing'}
- config:     ${cfg.ok? 'OK' : 'Missing'}

Config:
- limit: ${LIMIT}
- weights: ${JSON.stringify(weights)}

Counts:
- clusters:  ${report.counts.clusters}
- suburbs:   ${report.counts.suburbs}
- adjacency: ${report.counts.adjacencySources} sources (edges: ${totalEdges}; reciprocity ${(reciprocityRate*100).toFixed(1)}%)
- proximity: ${report.counts.proximitySources} sources

Diffs (sample ${report.diffsSampled}):
- records with mismatches: ${diffs.length}
  (saved → ${report.outputs.diff})

Cluster sizes (top 10):
${Object.entries(clusterSizes).sort((a,b)=>b[1]-a[1]).slice(0,10).map(([k,v])=>`  - ${k}: ${v}`).join('\n') || '  (none)'}

Issues:
- missing:     ${issues.missing.length}
- schema:      ${issues.schema.length}
- referential: ${issues.referential.length}
- warnings:    ${issues.warnings.length}

Top messages:
${topMsgs.map(x=>'  - '+x).join('\n') || '  (none)'}

Smoke paths → tmp/smoke-paths.json
`;
fs.writeFileSync(path.join(OUT_DIR, 'geo-report.txt'), txt);

console.log('\x1b[1m\n[geo-doctor]\x1b[0m');
console.log(txt);

const fatal = [];
if (!clusters.ok) fatal.push('clusters missing/invalid');
if (issues.schema.length) fatal.push('schema errors');
if (issues.referential.length) fatal.push('referential errors');

if (STRICT && fatal.length) {
  console.error('\x1b[31m' + `[geo-doctor] strict mode fail: ${fatal.join(', ')}` + '\x1b[0m');
  process.exit(1);
} else {
  console.log('\x1b[32m' + '[geo-doctor] done' + '\x1b[0m');
  process.exit(0);
}

/* -------------------- Optional: cluster split suggestion -------------------- */
function kmeans(points, k, iters=40) {
  if (points.length <= k) return points.map((p,i)=>({ ...p, cid:i }));
  let centers = points.slice(0,k).map(p=>({lat:p.lat,lng:p.lng}));
  for (let t=0;t<iters;t++){
    const buckets = Array.from({length:k}, ()=>[]);
    for (const p of points) {
      let best=0, bestd=Infinity;
      for (let i=0;i<k;i++){
        const d = (p.lat-centers[i].lat)**2 + (p.lng-centers[i].lng)**2;
        if (d<bestd){best=i;bestd=d;}
      }
      buckets[best].push(p);
    }
    for (let i=0;i<k;i++){
      if (!buckets[i].length) continue;
      let slat=0, slng=0;
      for (const p of buckets[i]){ slat+=p.lat; slng+=p.lng; }
      centers[i] = { lat: slat/buckets[i].length, lng: slng/buckets[i].length };
    }
    if (t===iters-1) {
      const out = [];
      for (let i=0;i<k;i++) for (const p of buckets[i]) out.push({...p, cid:i});
      return out;
    }
  }
  return points.map((p,i)=>({ ...p, cid:i%k }));
}

// Run if requested
if (SUGGEST_SPLIT_CLUSTER && clusterSlugs.includes(SUGGEST_SPLIT_CLUSTER) && Number.isFinite(SUGGEST_SPLIT_K) && SUGGEST_SPLIT_K>1) {
  const pts = [];
  for (const [slug, r] of suburbBySlug) {
    if (r.cluster !== SUGGEST_SPLIT_CLUSTER) continue;
    if (isNum(r.lat) && isNum(r.lng)) pts.push({ slug, name:r.name, lat:r.lat, lng:r.lng });
  }
  if (pts.length) {
    const res = kmeans(pts, SUGGEST_SPLIT_K);
    const groups = {};
    for (const p of res) (groups[p.cid] ||= []).push({ slug:p.slug, name:p.name });
    const suggest = {
      cluster: SUGGEST_SPLIT_CLUSTER,
      k: SUGGEST_SPLIT_K,
      groups,
      note: "Consider naming groups by compass or local identity (e.g., brisbane-inner-north)."
    };
    fs.writeFileSync(path.join(OUT_DIR, 'geo-suggested-split.json'), JSON.stringify(suggest, null, 2));
    console.log('\x1b[33m' + `[geo-doctor] suggested split saved to __ai/geo-suggested-split.json` + '\x1b[0m');
  } else {
    console.log('\x1b[33m' + `[geo-doctor] no lat/lng for cluster "${SUGGEST_SPLIT_CLUSTER}" — cannot suggest split` + '\x1b[0m');
  }
}
JS

# Smokes (fast presence checks)
write scripts/smokes/build-smokes.mjs <<'JS'
import fs from 'node:fs'
const routes=['/index.html','/suburbs/ipswich/index.html','/services/bond-clean/ipswich/index.html']
fs.mkdirSync('tmp',{recursive:true}); fs.writeFileSync('tmp/smoke-paths.json',JSON.stringify(routes,null,2))
console.log('smoke-paths → tmp/smoke-paths.json')
JS

write scripts/smokes/run-smokes.mjs <<'JS'
import fs from 'node:fs'; import pc from 'picocolors'
if(!fs.existsSync('dist')){ console.error(pc.red('dist missing. run build')); process.exit(1) }
const routes=JSON.parse(fs.readFileSync('tmp/smoke-paths.json','utf8')); let bad=0
for(const r of routes){ const p='dist'+r; if(!fs.existsSync(p)){ console.error(pc.red(`[smoke] missing ${p}`)); bad++ } }
if(bad) process.exit(1); console.log(pc.green('smokes OK'))
JS

# Data placeholders
write data/serviceCoverage.json <<'JSON'
{ "services": ["bond-clean","bathroom-deep-clean"], "coverage": { "bond-clean":["ipswich","ripley"], "bathroom-deep-clean":["ipswich"] } }
JSON

write data/suburbs.geojson <<'JSON'
{ "type":"FeatureCollection", "features":[{ "type":"Feature", "properties":{ "slug":"ipswich","name":"Ipswich","region":"QLD" }, "geometry":{ "type":"Point", "coordinates":[152.760,-27.616] } }] }
JSON

# Public sitemap placeholder
write public/sitemap.xml <<'XML'
<?xml version="1.0" encoding="UTF-8"?>
<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">
  <url><loc>__SITE__/</loc></url>
  <url><loc>__SITE__/suburbs/ipswich/</loc></url>
  <url><loc>__SITE__/services/bond-clean/ipswich/</loc></url>
</urlset>
XML

# Owner TODO
write __ai/OWNER_TODO.md <<'MD'
# Owner TODO (Geo + SEO + Invariants)
1) Replace placeholders:
   - `data/suburbs.geojson` with ABS-enriched features (lat/lng present)
   - `data/serviceCoverage.json` mapping services→valid suburb slugs
   - (Optional) `src/content/areas.clusters.json` for editorial clusters
   - (Optional) `src/components/Geo docter files/Suburb Data True/*` with CSV/GeoJSON for rich sync
2) Configure `SITE_URL` env or use `--site=` flag.
3) CI: run `npm run predeploy` to block broken builds (sync→doctor→build→SEO→invariants).
4) Use doctor’s extras:
   - `npm run geo:doctor -- --explain ipswich` → saves `__ai/geo-explain-ipswich.json`
   - `npm run geo:doctor -- --graph`          → saves `__ai/geo-adjacency.dot`
   - `npm run geo:doctor -- --write`          → writes `__ai/geo-proximity-fixed.json`
MD

# .gitignore & .nvmrc
write .gitignore <<'GIT'
node_modules
dist
tmp
__ai
.DS_Store
.env*
GIT

write .nvmrc <<'NVM'
v20.11.1
NVM

echo "----------------------------------------------------------------------
✅ Unified scaffold written. Next:
  npm install
  npm run dev

For CI:
  npm run predeploy
----------------------------------------------------------------------"
