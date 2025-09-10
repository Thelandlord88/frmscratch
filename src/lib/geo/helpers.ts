import suburbs from "../../data/suburbs.json";
import services from "../../data/services.json";

export type Suburb = typeof suburbs[number];
export type Service = typeof services[number];

export function findSuburbBySlug(slug: string): Suburb | undefined {
  return (suburbs as Suburb[]).find(s => s.slug === slug);
}
export function listNearby(slug: string, max = 6): Suburb[] {
  const s = findSuburbBySlug(slug);
  if (!s) return [];
  const order = s.neighbors.concat(
    (suburbs as Suburb[]).map(x => x.slug).filter(x => x !== slug && !s.neighbors.includes(x))
  );
  const seen = new Set<string>();
  const arr: Suburb[] = [];
  for (const sl of order) {
    if (seen.has(sl)) continue;
    const sub = findSuburbBySlug(sl);
    if (sub) { arr.push(sub); seen.add(sl); }
    if (arr.length >= max) break;
  }
  return arr;
}
export function findService(slug: string): Service | undefined {
  return (services as Service[]).find(s => s.slug === slug);
}
export function serviceUrl(svc: string, suburb: string) {
  return `/services/${svc}/${suburb}/`;
}
