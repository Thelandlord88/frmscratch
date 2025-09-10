// Enhanced clusters facade (alias & legacy aware) per patch spec
import clustersDoc from '~/content/areas.clusters.json';
import adjacencyDoc from '~/content/areas.adj.json';
import coverageDoc from '~/data/serviceCoverage.json';
import blogMap from '~/content/cluster_map.json';
import { toCanonicalCluster, toLegacyCluster } from '~/lib/links/clusterAliases';

export type SuburbItem = { slug: string; name: string; lat?: number; lng?: number };
export type ClusterItem = { slug: string; name?: string; suburbs: SuburbItem[] };
type RawCluster = { slug: string; name?: string; suburbs: Array<string | Partial<SuburbItem>> };

const RAW = (clustersDoc as any).clusters as RawCluster[];

// Indices
const clusterByDatasetSlug = new Map<string, ClusterItem>();
const suburbIndex = new Map<string, SuburbItem>();
const suburbToDatasetCluster = new Map<string, string>();

function slugify(raw: string){
  return (raw||'')
    .toString()
    .trim()
    .toLowerCase()
    .replace(/[^a-z0-9\s-]/g,'')
    .replace(/\s+/g,'-')
    .replace(/-+/g,'-');
}
function titleCase(slug: string) {
  return (slug || '').split('-').map(w => w ? w[0].toUpperCase() + w.slice(1) : w).join(' ').trim();
}

for (const c of RAW) {
  const ds = slugify(c.slug);
  const suburbs: SuburbItem[] = (c.suburbs || []).map(s => {
    if (typeof s === 'string') {
      const sl = slugify(s);
      return { slug: sl, name: titleCase(sl) };
    }
    const sl = slugify((s.slug || s.name || '') as string);
    return { slug: sl, name: s.name || titleCase(sl), lat: s.lat, lng: s.lng };
  });
  clusterByDatasetSlug.set(ds, { slug: ds, name: c.name || titleCase(ds), suburbs });
  for (const s of suburbs) {
    suburbIndex.set(s.slug, s);
    suburbToDatasetCluster.set(s.slug, ds);
  }
}

// Canonical cluster list (unique canonical slugs)
// Ensure exported constant is a real Array (spreadable)
export const CANONICAL_CLUSTERS: string[] = [...Array.from(new Set(
  [...clusterByDatasetSlug.keys()].map(sl => toCanonicalCluster(sl) || sl)
)).map(String)];
export const __CANONICAL_ARRAY = CANONICAL_CLUSTERS;

// Normalize adjacency
const ADJ: Record<string, string[]> = (() => {
  const src = adjacencyDoc as any; const out: Record<string,string[]> = {};
  for (const [k,v] of Object.entries(src)) {
    const key = k.toLowerCase();
    if (Array.isArray(v)) out[key] = v.map(x=>String(x).toLowerCase());
    else if (v && Array.isArray((v as any).adjacent_suburbs)) out[key] = (v as any).adjacent_suburbs.map((x:string)=>String(x).toLowerCase());
  }
  return out;
})();

const COVERAGE = coverageDoc as Record<string,string[]>;

export function getClustersSync(): { slug: string; name: string; suburbCount: number }[] {
  const merged = new Map<string,{slug:string; name:string; suburbCount:number}>();
  for (const [ds, c] of clusterByDatasetSlug) {
    const canonical = toCanonicalCluster(ds) || ds;
    const prev = merged.get(canonical);
    if (!prev) merged.set(canonical, { slug: canonical, name: titleCase(canonical), suburbCount: c.suburbs.length });
    else prev.suburbCount += c.suburbs.length; // future splits accumulate
  }
  return [...merged.values()];
}

export function listSuburbsForClusterSyncAsObjects(clusterSlug: string): SuburbItem[] {
  const canonical = toCanonicalCluster(clusterSlug) || toCanonicalCluster(clusterSlug.replace(/-region$/,'')) || null;
  if (!canonical) return [];
  const out: SuburbItem[] = [];
  for (const [ds, c] of clusterByDatasetSlug) {
    const can = toCanonicalCluster(ds);
    if (can === canonical) out.push(...c.suburbs.map(s => ({ ...s })));
  }
  return dedupe(out);
}

export function findSuburbBySlug(slug: string): SuburbItem | null {
  return suburbIndex.get((slug||'').toLowerCase()) || null;
}

export function findClusterBySuburb(suburbSlug: string): string | null {
  const ds = suburbToDatasetCluster.get((suburbSlug||'').toLowerCase());
  if (!ds) return null;
  return toLegacyCluster(toCanonicalCluster(ds)) || null;
}

export function getClusterForSuburbSync(suburbSlug: string): string | null {
  const ds = suburbToDatasetCluster.get((suburbSlug||'').toLowerCase());
  if (!ds) return null; 
  const canonical = toCanonicalCluster(ds) || ds;
  // Always return canonical (never legacy) for this API
  return canonical;
}

export function isCovered(service: string, suburbSlug: string): boolean {
  const list = (COVERAGE[service] || []).map(s=>s.toLowerCase());
  if (!COVERAGE[service]) return true; // treat unknown service as open
  return list.includes((suburbSlug||'').toLowerCase());
}

export function getNearbySuburbs(suburbSlug: string, opts: { limit?: number } = {}): SuburbItem[] {
  const src = findSuburbBySlug(suburbSlug); if (!src) return [];
  const limit = Math.max(1, opts.limit ?? 6);
  const adj = (ADJ[src.slug] || []).map(sl => findSuburbBySlug(sl)).filter(Boolean) as SuburbItem[];
  if (adj.length >= limit) return adj.slice(0, limit);
  // pad from same canonical cluster ranked by distance
  const canonical = getClusterForSuburbSync(src.slug);
  let pool: SuburbItem[] = [];
  if (canonical) pool = listSuburbsForClusterSyncAsObjects(canonical).filter(s => s.slug !== src.slug && !adj.find(a=>a.slug===s.slug));
  pool = rankByDistance(src, pool);
  return [...adj, ...pool].slice(0, limit);
}

export function representativeOfClusterSync(clusterSlug: string): string | null {
  const list = listSuburbsForClusterSyncAsObjects(clusterSlug);
  if (!list.length) return null;
  const ranked = list.map(s => ({ s, deg: (ADJ[s.slug]||[]).length }))
    .sort((a,b)=> b.deg - a.deg || a.s.slug.localeCompare(b.s.slug));
  return ranked[0]?.s.slug || null;
}

// Legacy helpers retained
export function unslugToName(slug: string){ return titleCase(slug); }
export function resolveClusterSlug(input: string){ return toCanonicalCluster(input)||null; }
export function toCanonicalClusterExport(input: string){ return toCanonicalCluster(input)||input; }
export function isAliasCluster(_input:string){ return false; }

// Blog cluster slug resolution (kept for backward compatibility)
const BLOG_MAP: Record<string,string> = blogMap as any;
export function getBlogClusterSlug(clusterSlug: string){
  const canonical = toCanonicalCluster(clusterSlug) || clusterSlug;
  const legacy = toLegacyCluster(toCanonicalCluster(clusterSlug));
  const tries = [clusterSlug, canonical, legacy].filter(Boolean).map(s=>String(s).toLowerCase());
  for (const t of tries) if (BLOG_MAP[t]) return BLOG_MAP[t];
  return canonical.toLowerCase();
}

// Internal helpers
function rankByDistance(src: SuburbItem, list: SuburbItem[]) {
  if (!Number.isFinite(src.lat) || !Number.isFinite(src.lng)) return list.sort((a,b)=>a.slug.localeCompare(b.slug));
  return list.map(s => ({ s, d: hav(src,s) })).sort((a,b)=>a.d-b.d).map(x=>x.s);
}
function hav(a: SuburbItem, b: SuburbItem){
  if (![a.lat,a.lng,b.lat,b.lng].every(Number.isFinite)) return Number.POSITIVE_INFINITY;
  const R=6371, toRad=(d:number)=>(d*Math.PI/180);
  const dLat=toRad((b.lat!-a.lat!)); const dLon=toRad((b.lng!-a.lng!));
  const s1=Math.sin(dLat/2)**2; const s2=Math.cos(toRad(a.lat!))*Math.cos(toRad(b.lat!))*Math.sin(dLon/2)**2;
  return 2*R*Math.asin(Math.sqrt(s1+s2));
}
function dedupe(list: SuburbItem[]) { const seen=new Set<string>(); const out:SuburbItem[]=[]; for (const s of list){ if(!seen.has(s.slug)){seen.add(s.slug); out.push(s);} } return out; }

