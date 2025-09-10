import cfgRaw from '~/content/geo.config.json';
import { findSuburbBySlug, findClusterBySuburb, getNearbySuburbs as catalogNearby, isCovered, type SuburbItem } from '~/lib/clusters';

type Mode = 'allow' | 'penalize' | 'drop';
type NearCfg = {
  limit: number;
  adjacencyBoost: number;
  clusterBoost: number;
  biasKm: number;
  distanceWeight: number;
  crossClusterMode: Mode;
  crossClusterPenalty: number;
  onlyCovered: boolean;
};
type Edge = { from: string; to: string };
const CFG = cfgRaw as {
  nearby: NearCfg;
  crossCluster?: { whitelistEdges?: Edge[]; blacklistEdges?: Edge[] };
  services?: Record<string, Partial<NearCfg>>;
};

function mergedCfg(service?: string): NearCfg {
  const base = CFG.nearby;
  const o = (service && CFG.services?.[service]) ? CFG.services[service] : {};
  return { ...base, ...o } as NearCfg;
}
function hasLL(s: SuburbItem) { return Number.isFinite((s as any).lat) && Number.isFinite((s as any).lng); }
function haversineKm(a: SuburbItem, b: SuburbItem) {
  const toRad = (d: number) => (d * Math.PI) / 180;
  const R=6371, dLat=toRad(((b as any).lat - (a as any).lat)), dLon=toRad(((b as any).lng - (a as any).lng));
  const s1=Math.sin(dLat/2)**2, s2=Math.cos(toRad((a as any).lat))*Math.cos(toRad((b as any).lat))*Math.sin(dLon/2)**2;
  return 2*R*Math.asin(Math.sqrt(s1+s2));
}
function edgeKey(a: string, b: string) { return [a, b].sort().join('::'); }

export type ProximityOpts = { service?: string; weightFn?: (s: SuburbItem) => number; minWeight?: number; };

export function findNearbySuburbs(slug: string, opts: ProximityOpts = {}): SuburbItem[] {
  const src = findSuburbBySlug(slug); if (!src) return [];
  const C = mergedCfg(opts.service);
  const WL = new Set((CFG.crossCluster?.whitelistEdges || []).map(e => edgeKey(e.from, e.to)));
  const BL = new Set((CFG.crossCluster?.blacklistEdges || []).map(e => edgeKey(e.from, e.to)));

  // Source cluster
  const srcCluster = findClusterBySuburb(slug);

  // Initial pool from catalog (contains curated adjacency + fallback)
  // Initial pool from catalog (contains curated adjacency + fallback).
  // NOTE: catalogNearby only supports { limit }, so we fetch a generous pool
  // and apply any distance window locally.
  const PREFETCH = Math.max(C.limit * 4, 64);
  let pool = catalogNearby(slug, { limit: PREFETCH })
    .filter(s => s.slug !== slug);

  // Optional distance window (biasKm + small margin) applied locally
  if (C.biasKm > 0 && hasLL(src)) {
    const windowKm = C.biasKm + 25;
    pool = pool.filter(s => hasLL(s) ? haversineKm(src, s) <= windowKm : true);
  }

  // Coverage gating
  if (opts.service && C.onlyCovered) pool = pool.filter(s => isCovered(opts.service!, s.slug));

  // Cross-cluster drop mode
  if (C.crossClusterMode === 'drop' && srcCluster) {
    pool = pool.filter(s => {
      const dst = findClusterBySuburb(s.slug);
      const ek = edgeKey(slug, s.slug);
      const cross = !!(dst && dst !== srcCluster);
      return !cross || WL.has(ek);
    });
  }

  // Blacklist removal always
  pool = pool.filter(s => !BL.has(edgeKey(slug, s.slug)));

  const scored = pool.map((s, index) => {
    let v = 0;
    // adjacency order bonus (early items assumed adjacency curated)
    v += Math.max(0, (12 - Math.min(index, 12))) * (C.adjacencyBoost / 12);
    const dstCluster = findClusterBySuburb(s.slug);
    if (srcCluster && dstCluster && srcCluster === dstCluster) v += C.clusterBoost;
    if (srcCluster && dstCluster && srcCluster !== dstCluster && C.crossClusterMode === 'penalize') v -= C.crossClusterPenalty;
    if (hasLL(src) && hasLL(s) && C.biasKm > 0) {
      const d = haversineKm(src, s);
      v += Math.max(0, C.biasKm - d) * (C.distanceWeight || 1);
    }
    if (opts.weightFn) v += opts.weightFn(s);
    return { s, sc: v };
  });

  const minW = opts.minWeight;
  const ranked = (minW == null ? scored : scored.filter(x => x.sc >= (minW as number)))
    .sort((a, b) => b.sc - a.sc)
    .map(x => x.s);

  return ranked.slice(0, C.limit);
}

export type ExplainRow = {
  slug: string; name: string;
  adjacencyOrderBonus: number;
  clusterBoost: number;
  distanceBonus: number;
  crossClusterPenalty: number;
  weightFn: number;
  total: number;
};

export function explainNearby(slug: string, opts: ProximityOpts = {}): ExplainRow[] {
  const src = findSuburbBySlug(slug); if (!src) return [];
  const C = mergedCfg(opts.service);
  const srcCluster = findClusterBySuburb(slug);
  const PREFETCH = Math.max(C.limit * 4, 64);
  let pool = catalogNearby(slug, { limit: PREFETCH }).filter(s => s.slug !== slug);
  if (C.biasKm > 0 && hasLL(src)) {
    const windowKm = C.biasKm + 25;
    pool = pool.filter(s => hasLL(s) ? haversineKm(src, s) <= windowKm : true);
  }
  if (opts.service && C.onlyCovered) pool = pool.filter(s => isCovered(opts.service!, s.slug));
  return pool.map((s, index) => {
    const dstCluster = findClusterBySuburb(s.slug);
    const adjacencyOrderBonus = Math.max(0,(12 - Math.min(index,12))) * (C.adjacencyBoost / 12);
    const clusterBoost = (srcCluster && dstCluster && srcCluster === dstCluster) ? C.clusterBoost : 0;
    const crossClusterPenalty = (srcCluster && dstCluster && srcCluster !== dstCluster && C.crossClusterMode === 'penalize') ? C.crossClusterPenalty : 0;
    let distanceBonus = 0;
    if (hasLL(src) && hasLL(s) && C.biasKm > 0) {
      const d = haversineKm(src,s);
      distanceBonus = Math.max(0, C.biasKm - d) * (C.distanceWeight || 1);
    }
    const wf = opts.weightFn ? opts.weightFn(s) : 0;
    const total = adjacencyOrderBonus + clusterBoost + distanceBonus - crossClusterPenalty + wf;
    return { slug: s.slug, name: s.name, adjacencyOrderBonus, clusterBoost, distanceBonus, crossClusterPenalty, weightFn: wf, total };
  }).sort((a,b)=>b.total - a.total).slice(0, mergedCfg(opts.service).limit);
}
