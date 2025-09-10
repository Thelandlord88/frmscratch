#!/usr/bin/env node
import fs from 'node:fs';

if (!fs.existsSync('src/content/geo.config.json')) {
  console.error('No geo.config.json found');
  process.exit(1);
}
const cfg = JSON.parse(fs.readFileSync('src/content/geo.config.json','utf8'));
const adjPath = 'src/content/areas.adj.json';
const clustersPath = 'src/content/areas.clusters.json';
if (!fs.existsSync(adjPath) || !fs.existsSync(clustersPath)) {
  console.error('Missing adjacency or clusters file');
  process.exit(1);
}
const adj = JSON.parse(fs.readFileSync(adjPath,'utf8')) as Record<string,string[]>;
const clusters = JSON.parse(fs.readFileSync(clustersPath,'utf8')).clusters as any[];

const WL = new Set<string>((cfg.crossCluster?.whitelistEdges || []).map((e:any)=> [e.from,e.to].sort().join('::')));
const map = new Map<string,string>();
for (const c of clusters) for (const s of c.suburbs) map.set((s.slug||s.name).toLowerCase(), c.slug);

const cleaned: Record<string,string[]> = {};
let dropped = 0;
for (const [k, list] of Object.entries(adj)) {
  const kc = map.get(k);
  cleaned[k] = (list || []).filter(v => {
    const vc = map.get(v);
    if (!kc || !vc) return false;
    if (kc === vc) return true;
    const keep = WL.has([k,v].sort().join('::'));
    if (!keep) dropped++;
    return keep;
  });
}
fs.writeFileSync(adjPath, JSON.stringify(cleaned, null, 2));
console.log(`✅ enforced cross-cluster adjacency (dropped ${dropped} edges)`);
