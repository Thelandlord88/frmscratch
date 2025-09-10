// Rich cluster alias utilities (dataset <-> canonical <-> legacy) used by tests & link builders.
// Dataset slugs often: `<name>-city`; legacy tests may expect `<name>-region` (only for ipswich currently).

export type ClusterSlug = 'ipswich' | 'brisbane' | 'logan';

export const DATASET_TO_CANONICAL: Record<string, ClusterSlug> = {
  'ipswich-city': 'ipswich',
  'brisbane-city': 'brisbane',
  'logan-city': 'logan',
  // self mappings allow passing canonical directly
  ipswich: 'ipswich',
  brisbane: 'brisbane',
  logan: 'logan'
};

export function toCanonicalCluster(slug: string | null | undefined): ClusterSlug | null {
  if (!slug) return null;
  const s = slug.toLowerCase().trim();
  if (DATASET_TO_CANONICAL[s]) return DATASET_TO_CANONICAL[s];
  if (s.endsWith('-city')) {
    const base = s.slice(0, -5);
    if (DATASET_TO_CANONICAL[base]) return DATASET_TO_CANONICAL[base];
  }
  if (s.endsWith('-region')) {
    const base = s.slice(0, -7);
    if (DATASET_TO_CANONICAL[base]) return DATASET_TO_CANONICAL[base];
  }
  return null;
}

export function toLegacyCluster(canonical: ClusterSlug | null): string | null {
  if (!canonical) return null;
  if (canonical === 'ipswich') return 'ipswich-region';
  return canonical;
}

export function normalizeClusterToCanonicalOrSelf(slug: string): ClusterSlug | string {
  return toCanonicalCluster(slug) ?? slug;
}

export function resolveToDatasetClusterSlug(input: string): string {
  const v = (input || '').toLowerCase();
  if (v in DATASET_TO_CANONICAL) return v; // already dataset or canonical
  const canon = toCanonicalCluster(v);
  if (canon) {
    // find a dataset form ending with -city if available
    const ds = Object.entries(DATASET_TO_CANONICAL).find(([k, c]) => c === canon && k.endsWith('-city'))?.[0];
    return ds || canon;
  }
  return v;
}
