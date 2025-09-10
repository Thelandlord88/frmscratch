// Zod contracts for geo artifacts + helpers to normalize common variants.
// Prevents silent drift from malformed config/data.
// ----------------------------------------------------------------------

import { z } from 'zod';

// --- Scalars ----------------------------------------------------------
export const slug = z.string().min(1).regex(/^[a-z0-9-]+$/);
export const name = z.string().min(1);
export const lat  = z.number().gte(-90).lte(90);
export const lng  = z.number().gte(-180).lte(180);

// --- Suburbs (string or object) --------------------------------------
export const SuburbObject = z.object({
  slug: slug.optional(),
  name: name.optional(),
  lat: lat.optional(),
  lng: lng.optional()
});
export const ClusterSuburb = z.union([slug, SuburbObject]);

// --- Clusters: array and record forms --------------------------------
export const ClusterObject = z.object({
  slug: slug,
  name: name.optional(),
  suburbs: z.array(ClusterSuburb).min(1)
});

export const ClustersArraySchema = z.object({
  clusters: z.array(ClusterObject).min(1)
}).strict();

export const ClustersRecordSchema = z.record(z.array(slug).min(1));

export const ClustersUnion = z.union([ClustersArraySchema, ClustersRecordSchema]);

// --- Adjacency (array record or {adjacent_suburbs}) ------------------
export const AdjacencyArrayRecord = z.record(z.array(slug).default([]));
export const AdjacencyObjRecord   = z.record(z.object({
  adjacent_suburbs: z.array(slug).default([])
}).strict());
export const AdjacencyUnion = z.union([AdjacencyArrayRecord, AdjacencyObjRecord]);

export type NormalizedAdjacency = Record<string, string[]>;

// --- Coverage ---------------------------------------------------------
export const CoverageSchema = z.record(z.array(slug).default([]));

// --- Geo config -------------------------------------------------------
export const CrossClusterEdge = z.object({ from: slug, to: slug });

export const GeoConfigSchema = z.object({
  nearby: z.object({
    limit: z.number().int().min(1).max(24),
    adjacencyBoost: z.number().min(0).max(2000),
    clusterBoost: z.number().min(0).max(5000),
    biasKm: z.number().min(0).max(50),
    distanceWeight: z.number().min(0).max(10),
    onlyCovered: z.boolean(),
    crossClusterMode: z.enum(['allow','penalize','drop']),
    crossClusterPenalty: z.number().min(0).max(5000)
  }),
  services: z.record(z.string(), z.object({
    limit: z.number().int().min(1).max(24)
  }).partial().passthrough()).optional(),
  crossCluster: z.object({
    whitelistEdges: z.array(CrossClusterEdge).default([]),
    blacklistEdges: z.array(CrossClusterEdge).default([])
  }).default({ whitelistEdges: [], blacklistEdges: [] })
}).strict();

// --- Normalizers ------------------------------------------------------
export function normalizeClustersShape(doc: unknown): {
  clusters: Array<{ slug: string; name?: string; suburbs: Array<{ slug: string; name?: string; lat?: number; lng?: number }> }>;
} {
  const parsed = ClustersUnion.parse(doc);
  if ('clusters' in parsed) return parsed as any;
  const arr: any[] = [];
  for (const [cslug, subs] of Object.entries(parsed)) {
    arr.push({ slug: cslug, suburbs: (subs as string[]).map(s => ({ slug: s })) });
  }
  return { clusters: arr };
}

export function normalizeAdjacency(doc: unknown): NormalizedAdjacency {
  const parsed: any = AdjacencyUnion.parse(doc);
  const out: Record<string,string[]> = {};
  // Detect form by inspecting first value
  const firstVal = parsed ? (Object.values(parsed)[0] as any) : null;
  const isObjForm = firstVal && typeof firstVal === 'object' && Array.isArray(firstVal.adjacent_suburbs);
  if (!isObjForm) {
    for (const [k,v] of Object.entries(parsed as Record<string,string[]>)) out[k] = v;
    return out;
  }
  for (const [k, v] of Object.entries(parsed as Record<string,{adjacent_suburbs:string[]}>)) out[k] = v.adjacent_suburbs;
  return out;
}
