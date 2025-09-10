// Canonical provider for known suburbs and cluster resolution
// Single source of truth for all suburb/cluster operations
import clustersData from '~/content/areas.clusters.json';

let KNOWN: Set<string> | null = null;
let SUBURB2CLUSTER: Map<string, string> | null = null;
let CLUSTERS_BY_SLUG: Map<string, any> | null = null;

export function slugify(name: any): string {
  if (name == null) return '';
  const raw = typeof name === 'string' ? name : (name.slug || name.name || '');
  return String(raw).toLowerCase()
    .replace(/\s+/g, '-')
    .replace(/[^a-z0-9-]/g, '');
}

function init() {
  if (KNOWN) return;
  KNOWN = new Set<string>();
  SUBURB2CLUSTER = new Map<string, string>();
  CLUSTERS_BY_SLUG = new Map<string, any>();

  const clusters = (clustersData as any).clusters || [];
  clusters.forEach((cluster: any) => {
    CLUSTERS_BY_SLUG!.set(cluster.slug, cluster);
    const suburbs = cluster.suburbs || [];
    suburbs.forEach((suburb: any) => {
      const slug = slugify(suburb);
      KNOWN!.add(slug);
      SUBURB2CLUSTER!.set(slug, cluster.slug);
    });
  });
}

export function getKnownSuburbSlugs(): Set<string> {
  init();
  return KNOWN!;
}

export function findClusterSlugForSuburb(suburb: string): string | null {
  init();
  return SUBURB2CLUSTER!.get(suburb) ?? null;
}

export function inSameCluster(a: string, b: string): boolean {
  init();
  const ca = SUBURB2CLUSTER!.get(a);
  const cb = SUBURB2CLUSTER!.get(b);
  return !!ca && ca === cb;
}

export function getAllClusters(): any[] {
  const data = clustersData as any;
  return data.clusters || [];
}

export function getSuburbsInCluster(clusterSlug: string): string[] {
  init();
  const cluster = CLUSTERS_BY_SLUG!.get(clusterSlug);
  if (!cluster) return [];
  return cluster.suburbs.map((s: any) => slugify(s));
}
