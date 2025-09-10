// Enhanced suburb display resolution with edge case handling
import clusters from '~/content/areas.clusters.json';

export type SuburbDisplay = {
  slug: string;
  name: string;
  cluster?: string;
};

const titleCase = (slug: string): string =>
  slug
    .replace(/-/g, ' ')
    .replace(/\b\w/g, c => c.toUpperCase())
    .replace(/\bSt\b/i, 'St')           // St Lucia, not St-lucia
    .replace(/\bMt\b/i, 'Mt')           // Mt Gravatt, Mt Ommaney
    .replace(/\bUpper\b/i, 'Upper')     // Upper Brookfield
    .replace(/\bNorth\b/i, 'North')     // North Booval
    .replace(/\bWest\b/i, 'West')       // West Ipswich
    .replace(/\bEast\b/i, 'East')       // East Ipswich
    .replace(/\bSouth\b/i, 'South')     // South areas
    .replace(/\bPark\b/i, 'Park')       // Heritage Park, Sinnamon Park
    .replace(/\bCreek\b/i, 'Creek')     // Cedar Creek, Slacks Creek
    .replace(/\bHills?\b/i, 'Hills')    // Kenmore Hills, Pinjarra Hills
    .replace(/\bHeights?\b/i, 'Heights') // Augustine Heights, Eastern Heights
    .replace(/\bPlains?\b/i, 'Plains')   // Redbank Plains, Browns Plains
    .replace(/\bLakes?\b/i, 'Lakes')     // Springfield Lakes
    .replace(/\bRidge\b/i, 'Ridge')      // Park Ridge, Woodridge
    .replace(/\bViews?\b/i, 'View')      // Flinders View
    .replace(/\bGrove\b/i, 'Grove')      // Ellen Grove, Ashgrove
    .replace(/\bLanding\b/i, 'Landing')  // Edens Landing
    .replace(/\bCentral\b/i, 'Central')  // Logan Central
    .replace(/\bVillage\b/i, 'Village')  // Logan Village
    .replace(/\bReserve\b/i, 'Reserve')  // Logan Reserve
    .replace(/\bScrub\b/i, 'Scrub');     // Bahrs Scrub, Veresdale Scrub

// Pre-compute suburb -> cluster mapping for O(1) lookup
const bySuburb = new Map<string, string>();
const clusterData = clusters as any;

for (const cluster of clusterData.clusters || []) {
  const clusterSlug = cluster.slug;
  for (const suburbEntry of cluster.suburbs || []) {
    if (typeof suburbEntry === 'string') {
      const slug = suburbEntry.toLowerCase().replace(/\s+/g, '-');
      bySuburb.set(slug, clusterSlug);
    } else if (suburbEntry && typeof suburbEntry === 'object') {
      const raw = suburbEntry.slug || suburbEntry.name;
      if (raw && typeof raw === 'string') {
        const slug = raw.toLowerCase().replace(/\s+/g, '-');
        bySuburb.set(slug, clusterSlug);
      }
    }
  }
}

// Memoization cache for performance
const cache = new Map<string, SuburbDisplay>();

export function resolveSuburbDisplay(slug: string): SuburbDisplay {
  if (cache.has(slug)) return cache.get(slug)!;
  
  const cluster = bySuburb.get(slug);
  const display: SuburbDisplay = {
    slug,
    name: titleCase(slug.replace(/-qld$/i, '')), // strip region suffix if present
    cluster,
  };
  
  cache.set(slug, display);
  return display;
}

export function safeSuburbLabel(slug: string): string {
  return resolveSuburbDisplay(slug).name;
}

// Bulk resolution for performance
export function resolveSuburbDisplays(slugs: string[]): SuburbDisplay[] {
  return slugs.map(slug => resolveSuburbDisplay(slug));
}

// Clear cache if needed (useful for testing)
export function clearDisplayCache(): void {
  cache.clear();
}
