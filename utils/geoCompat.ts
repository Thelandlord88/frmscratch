// src/utils/geoCompat.ts
import {
  getClustersSync,
  listSuburbsForClusterSyncAsObjects,
  findClusterBySuburb,
  getNearbySuburbs,
  findSuburbBySlug as coreFindSuburb,
  CANONICAL_CLUSTERS as CORE_CANONICAL,
  getClusterForSuburbSync as coreCanonicalClusterForSuburb
} from '~/lib/clusters';

export {
  getClustersSync,
  listSuburbsForClusterSyncAsObjects,
  findClusterBySuburb,
  getNearbySuburbs,
} from '~/lib/clusters';

// Ensure iterable array exported for tests
export const CANONICAL_CLUSTERS = [...CORE_CANONICAL];

// Legacy string-list shims (for older tests/callers)
export const listClustersSync = () => getClustersSync().map(c => c.slug);
export const listSuburbsForClusterSync = (cluster: string) =>
  listSuburbsForClusterSyncAsObjects(cluster).map(s => s.slug);

// Additional legacy aliases (keep existing code working)
// Canonical (not legacy) cluster resolution
export const getClusterForSuburbSync = (slug: string) => coreCanonicalClusterForSuburb(slug) || findClusterBySuburb(slug);
export const allSuburbsSync = () => {
  const allSlugs: string[] = [];
  for (const cluster of getClustersSync()) {
    const suburbs = listSuburbsForClusterSync(cluster.slug);
    allSlugs.push(...suburbs);
  }
  return allSlugs.sort();
};

// Find suburb with name by slug (for service pages)
export const findSuburbBySlug = (slug: string) => coreFindSuburb(slug);

// Async shims for legacy compatibility
export const getClusterForSuburb = async (s: string) => findClusterBySuburb(s);
export const allSuburbs = async () => allSuburbsSync();
export const listClusters = async () => getClustersSync();
export const listSuburbsForCluster = async (c: string) => listSuburbsForClusterSyncAsObjects(c);

// Legacy test compatibility
export const getSuburbsForClusterSync = listSuburbsForClusterSync;
// expose nearby via compat (used by some older helpers/tests indirectly)
export const nearbySuburbsCompat = (slug: string, limit = 6) => getNearbySuburbs(slug, { limit });

/** @deprecated No-op since data is pre-computed */
export async function primeGeoCompat(): Promise<void> {
  // No-op - everything is pre-computed at module load
}

// Representative selection (highest adjacency degree fallback alphabetical)
import adjacency from '~/content/areas.adj.json';
export function representativeOfClusterSync(cluster: string): string | null {
  const subs = listSuburbsForClusterSyncAsObjects(cluster);
  if (!subs.length) return null;
  const deg = (slug: string) => ((adjacency as Record<string,string[]>)[slug] || []).length;
  subs.sort((a,b)=> (deg(b.slug)-deg(a.slug)) || a.name.localeCompare(b.name));
  return subs[0].slug;
}
