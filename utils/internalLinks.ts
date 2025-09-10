// src/utils/internalLinks.ts (final deterministic implementation with directional + override precedence)
import {
  findClusterBySuburb,
  getClusterForSuburbSync,
  findSuburbBySlug,
  isCovered,
  unslugToName as clustersUnslugToName,
  listSuburbsForClusterSyncAsObjects,
} from '~/lib/clusters';

import prox from '~/content/_generated/proximity.json';
import coverageMap from '~/data/serviceCoverage.json';

// Curated neighbors used by tests (Ipswich only)
let CURATED_BY_CLUSTER: Record<string, Record<string, string[]>> = {};
const _req = (id: string): any => { try { return (eval('require'))(id); } catch { return null; } }; // safe fallback for vitest/node
{ const ips = _req('~/data/geo.neighbors.ipswich.json'); if (ips) CURATED_BY_CLUSTER.ipswich = (ips?.default ?? ips) || {}; }

// BLOG_BASE awareness
const BLOG_BASE: string = (globalThis as any).BLOG_BASE || '/guides/';

// Blog cluster override map (support data & content + raw variants, tests mock data path)
let BLOG_CLUSTER_OVERRIDE: Record<string,string> = {};
{ const d = _req('~/data/cluster_map.json'); if (d) BLOG_CLUSTER_OVERRIDE = (d?.default ?? d) || {}; }
if (Object.keys(BLOG_CLUSTER_OVERRIDE).length === 0) { const draw = _req('~/data/cluster_map.json?raw'); if (draw && typeof draw === 'string') { try { BLOG_CLUSTER_OVERRIDE = JSON.parse(draw); } catch {} } }
if (Object.keys(BLOG_CLUSTER_OVERRIDE).length === 0) { const c = _req('~/content/cluster_map.json'); if (c) BLOG_CLUSTER_OVERRIDE = (c?.default ?? c) || {}; }
if (Object.keys(BLOG_CLUSTER_OVERRIDE).length === 0) { const craw = _req('~/content/cluster_map.json?raw'); if (craw && typeof craw === 'string') { try { BLOG_CLUSTER_OVERRIDE = JSON.parse(craw); } catch {} } }

// Optional mocked adjacency (higher precedence) always normalized
let MOCKED_ADJ: Record<string,string[]> = {};
function normalizeAdjMap(src: Record<string, any>): Record<string,string[]> { const out: Record<string,string[]> = {}; for (const [k,v] of Object.entries(src||{})){ const key = hyphenate(k); const arr = Array.isArray(v)? v : Array.isArray((v as any)?.adjacent_suburbs)? (v as any).adjacent_suburbs : []; out[key] = (arr||[]).map(hyphenate); } return out; }
{ const mod = _req('~/data/adjacency.json'); if (mod) MOCKED_ADJ = normalizeAdjMap((mod?.default ?? mod) || {}); }

// ---------- helpers ----------
const lower = (s: string) => (s ?? '').toString().trim().toLowerCase();
const titleize = (s: string) => s.replace(/-/g,' ').replace(/\b\w/g,c=>c.toUpperCase());
const hyphenate = (s: string) => lower(s).replace(/\s+/g,'-');
function stripDatasetSuffix(s: string){ if (s.endsWith('-city')) return s.slice(0,-5); if (s.endsWith('-region')) return s.slice(0,-7); return s; }
function stripDirectional(s: string | null){ if(!s) return s; let out=s; out=out.replace(/-(north|south|east|west|central)$/i,''); out=out.replace(/-(north|south)(east|west)$/i,''); out=out.replace(/-(inner|outer|metro|greater)$/i,''); return out; }
function toCanonicalClusterSlug(input?: string | null): string | null { if(!input) return null; return stripDatasetSuffix(lower(input)); }
const isOpenService = (service:string) => !Object.prototype.hasOwnProperty.call(coverageMap, service);
function dedupe<T>(arr:T[]){ const seen=new Set<string>(); const out:T[]=[]; for(const x of arr){ const key= typeof x==='string'? lower(x): JSON.stringify(x); if(!seen.has(key)){ seen.add(key); out.push(x);} } return out; }

function safeFindSuburb(input: string){
  const slug = hyphenate(input);
  let s = findSuburbBySlug(slug);
  if (s) return s;
  try {
    const m = _req('~/content/areas.clusters.json');
    const doc = (m?.default ?? m) || {};
    const cls = Array.isArray(doc?.clusters)? doc.clusters : [];
    for (const c of cls){
      const subs = Array.isArray(c?.suburbs)? c.suburbs : [];
      for (const sub of subs){
        if (typeof sub === 'string') { const ss=hyphenate(sub); if (ss===slug) return { slug:ss, name: clustersUnslugToName(ss) }; }
        else if (sub && (sub.slug || sub.name)) { const ss=hyphenate(sub.slug || sub.name); const nm=sub.name || clustersUnslugToName(ss); if (ss===slug) return { slug:ss, name:nm }; }
      }
    }
  } catch {}
  return null;
}

// ---------- exports ----------
export function unslugToName(suburbSlug: string){ return findSuburbBySlug(suburbSlug)?.name || clustersUnslugToName(suburbSlug); }
export function getServiceLink(serviceSlug: string, suburbSlug: string){ return `/services/${hyphenate(serviceSlug)}/${hyphenate(suburbSlug)}/`; }

export function getLocalBlogLink(suburbSlug: string): string {
  const base = BLOG_BASE.endsWith('/')? BLOG_BASE : BLOG_BASE + '/';
  const here = safeFindSuburb(suburbSlug);
  if (!here){
    const unknown = hyphenate(suburbSlug);
    // Treat override keys as suburb->cluster mapping first
    if (BLOG_CLUSTER_OVERRIDE[unknown]) {
      const rawTarget = BLOG_CLUSTER_OVERRIDE[unknown];
      const targetCanon = stripDirectional(toCanonicalClusterSlug(rawTarget) || stripDatasetSuffix(lower(String(rawTarget))) || lower(String(rawTarget)) );
      if (targetCanon) return `${base}${targetCanon.replace(/^\/|\/$/g,'')}/`;
    }
    const values = Object.values(BLOG_CLUSTER_OVERRIDE).map(v=>{
      const raw = lower(String(v)).replace(/^\/|\/$/g,'');
      return stripDirectional(toCanonicalClusterSlug(raw) || stripDatasetSuffix(raw) || raw) || raw;
    });
    for (const pref of ['ipswich','brisbane','logan']) if (values.includes(pref)) return `${base}${pref}/`;
    const first = values[0]; return first? `${base}${first}/` : base;
  }
  const dataset = findClusterBySuburb(here.slug) || getClusterForSuburbSync(here.slug);
  const canonical = toCanonicalClusterSlug(dataset);
  const bare = stripDirectional(canonical);
  const candidates = [
    lower(dataset||''),
    lower(stripDatasetSuffix(dataset||'')),
    lower(canonical||''),
    lower(bare||''),
    bare? `${bare}-region`:'',
    bare? `${bare}-city`:'',
  ].filter(Boolean) as string[];
  for (const k of dedupe(candidates)){ const mapped = BLOG_CLUSTER_OVERRIDE[k]; if (mapped) return `${base}${lower(mapped).replace(/^\/|\/$/g,'')}/`; }
  if (bare) return `${base}${bare}/`;
  return canonical? `${base}${canonical}/` : base;
}

export function getRelatedServiceLinks(opts: { service:string; suburbSlug:string; count?:number; includeSelf?:boolean }) {
  const service = lower(opts.service); const includeSelf = opts.includeSelf !== false; const neighborCount = Math.max(1, opts.count ?? 1);
  const here = safeFindSuburb(opts.suburbSlug); const totalLimit = includeSelf? neighborCount + 1 : neighborCount;
  if (!here){ const href = getServiceLink(service, opts.suburbSlug); const label=`${titleize(service)} in ${clustersUnslugToName(hyphenate(opts.suburbSlug))}`; return includeSelf? [{ href, label }]: []; }
  const open = isOpenService(service); const allow = (slug:string)=> open || isCovered(service, slug);
  // Re-evaluate mocked adjacency lazily if empty (Vitest may reset module cache ordering)
  let adjMockSrc = MOCKED_ADJ;
  if (Object.keys(adjMockSrc).length === 0) {
    try { const m = _req('~/data/adjacency.json'); if (m) adjMockSrc = normalizeAdjMap((m?.default ?? m) || {}); } catch {}
  }
  const adjMock = (adjMockSrc[here.slug] || []).map(lower);
  const nearRaw = ((prox as any)?.nearby || {})[here.slug] || []; const near = nearRaw.map((x:any)=> typeof x==='string'? lower(x) : lower(x?.slug)).filter(Boolean);
  const dsCluster = findClusterBySuburb(here.slug) || getClusterForSuburbSync(here.slug); const bare = stripDirectional(toCanonicalClusterSlug(dsCluster));
  const curatedBlob = bare? CURATED_BY_CLUSTER[bare]: undefined; const curated = curatedBlob? (curatedBlob[here.slug]||[]).map(lower): [];
  const clusterPad = bare? (listSuburbsForClusterSyncAsObjects(bare)||[]).map(s=>s.slug).map(lower).sort() : [];
  const candidates = dedupe<string>([...adjMock, ...near, ...curated, ...clusterPad.filter(s=>s!==here.slug)]);
  const out: Array<{ href:string; label:string; suburb:string }> = [];
  if (includeSelf && allow(here.slug)) out.push({ href: getServiceLink(service, here.slug), label: `${titleize(service)} in ${here.name}`, suburb: here.slug });
  for (const nb of candidates){ if (out.length >= totalLimit) break; if (nb===here.slug) continue; if(!allow(nb)) continue; if(out.find(x=>x.suburb===nb)) continue; out.push({ href:getServiceLink(service, nb), label:`${titleize(service)} in ${clustersUnslugToName(nb)}`, suburb: nb }); }
  if (!out.length) out.push({ href: getServiceLink(service, here.slug), label: `${titleize(service)} in ${here.name}`, suburb: here.slug });
  return out.slice(0, totalLimit);
}

export { unslugToName as titleize };
