#!/usr/bin/env tsx
import clustersDoc from '~/content/areas.clusters.json';
import coverage from '~/data/serviceCoverage.json';
import adjacencyDoc from '~/data/adjacency.json';
import { ClustersUnion, CoverageSchema, AdjacencyUnion } from '~/lib/schemas';
import type { NormalizedAdjacency } from '~/lib/schemas';
import { slugify } from '~/lib/links/knownSuburbs';

function fail(msg: string): never { console.error(msg); process.exit(1); }
const STRICT = process.env.STRICT_MODE === '1';

function normalizeClusters() {
  const parsed = ClustersUnion.safeParse(clustersDoc);
  if (!parsed.success) fail('clusters schema invalid:\n' + parsed.error.toString());

  const suburbToCluster = new Map<string, string>();
  const clusterToSuburbs = new Map<string, string[]>();
  const dupIntra: string[] = [];

  if ('clusters' in (clustersDoc as any)) {
    for (const c of (clustersDoc as any).clusters) {
      const cSlug = slugify(c.slug);
      const listRaw = (c.suburbs || []);
      if (STRICT) {
        if (c.slug !== slugify(c.slug)) fail(`Non-slug cluster '${c.slug}' (STRICT_MODE)`);
        for (const raw of listRaw) {
          const s = String(raw);
            if (s !== slugify(s)) fail(`Non-slug suburb '${s}' in cluster '${c.slug}' (STRICT_MODE)`);
        }
      }
      const list = listRaw.map((s: string) => slugify(s)).sort();
      const seen = new Set<string>();
      for (const s of list) { if (seen.has(s)) dupIntra.push(`${cSlug}:${s}`); seen.add(s); }
      clusterToSuburbs.set(cSlug, list);
      for (const s of list) {
        const prev = suburbToCluster.get(s);
        if (prev && prev !== cSlug) fail(`Suburb '${s}' in multiple clusters: '${prev}', '${cSlug}'`);
        suburbToCluster.set(s, cSlug);
      }
    }
  } else {
    for (const [k, v] of Object.entries(clustersDoc as Record<string, string[]>)) {
      if (STRICT && k !== slugify(k)) fail(`Non-slug cluster '${k}' (STRICT_MODE)`);
      if (STRICT) for (const raw of v) { const s = String(raw); if (s !== slugify(s)) fail(`Non-slug suburb '${s}' in cluster '${k}' (STRICT_MODE)`); }
      const cSlug = slugify(k);
      const list = v.map(s => slugify(s)).sort();
      const seen = new Set<string>();
      for (const s of list) { if (seen.has(s)) dupIntra.push(`${cSlug}:${s}`); seen.add(s); }
      clusterToSuburbs.set(cSlug, list);
      for (const s of list) {
        const prev = suburbToCluster.get(s);
        if (prev && prev !== cSlug) fail(`Suburb '${s}' in multiple clusters: '${prev}', '${cSlug}'`);
        suburbToCluster.set(s, cSlug);
      }
    }
  }
  if (dupIntra.length) fail(`Duplicate suburb(s) inside cluster: ${Array.from(new Set(dupIntra)).join(', ')}`);
  return { suburbToCluster, clusterToSuburbs };
}

function normalizeAdjacency(): NormalizedAdjacency {
  const parsed = AdjacencyUnion.safeParse(adjacencyDoc);
  if (!parsed.success) fail('adjacency schema invalid:\n' + parsed.error.toString());
  const out: NormalizedAdjacency = {};
  for (const [k, v] of Object.entries(adjacencyDoc as any)) {
    const a = slugify(k);
    const list = Array.isArray(v) ? v : (v as any)?.adjacent_suburbs || [];
    out[a] = list.map((s: string) => slugify(s)).sort();
  }
  return out;
}

function validateAdjacencyAgainstClusters(adj: NormalizedAdjacency, suburbToCluster: Map<string, string>) {
  let missing = 0, cross = 0;
  const warnOnly = process.env.GEO_ALLOW_MISSING === '1';
  for (const [a, ns] of Object.entries(adj)) {
    const ca = suburbToCluster.get(a);
    if (!ca) { console.warn(`MISSING NODE: ${a}`); missing++; if (warnOnly) continue; }
    for (const b of ns) {
      const cb = suburbToCluster.get(b);
      if (!cb) { console.warn(`MISSING NEIGHBOR: ${a} -> ${b}`); missing++; continue; }
      if (ca && cb && ca !== cb) { console.warn(`CROSS EDGE: ${a}(${ca}) -> ${b}(${cb})`); cross++; }
    }
  }
  if (!warnOnly && (missing || cross)) fail(`graph invalid (missing=${missing}, cross=${cross})`);
  if (warnOnly) console.log(`Adjacency check: missing=${missing}, cross=${cross} (warnings only)`);
}

function validateCoverageTokens(suburbToCluster: Map<string, string>, clusterToSuburbs: Map<string, string[]>) {
  const parsed = CoverageSchema.safeParse(coverage);
  if (!parsed.success) fail('coverage schema invalid:\n' + parsed.error.toString());
  const unknown: string[] = [];
  for (const [svc, entries] of Object.entries(coverage as Record<string, string[]>)) {
    for (const raw of entries) {
      const token = slugify(raw);
      if (suburbToCluster.has(token)) continue;
      if (clusterToSuburbs.has(token)) continue;
      unknown.push(`[${svc}] '${raw}' → '${token}'`);
    }
  }
  if (unknown.length) {
    if (process.env.GEO_ALLOW_MISSING === '1') {
      console.warn(`Coverage tokens unknown (${unknown.length})`);
      for (const u of unknown) console.warn('  - ' + u);
    } else {
      fail('Unknown coverage tokens:\n' + unknown.join('\n'));
    }
  }
}

(function main(){
  const { suburbToCluster, clusterToSuburbs } = normalizeClusters();
  const adj = normalizeAdjacency();
  validateAdjacencyAgainstClusters(adj, suburbToCluster);
  validateCoverageTokens(suburbToCluster, clusterToSuburbs);
  console.log('validate-data.zod OK');
})();
