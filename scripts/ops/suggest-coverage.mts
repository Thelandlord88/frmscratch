#!/usr/bin/env node
import fs from 'node:fs';
import path from 'node:path';

type Seeds = Record<string,{
  seeds: string[];
  radiusKm?: number;
  hops?: number;
  requireIntersect?: boolean;
  maxAdd?: number;
  clusterCap?: number;
}>;

function readJSON(p:string){ return JSON.parse(fs.readFileSync(p,'utf8')); }
const seedsPath = 'src/data/coverage.seeds.json';
if (!fs.existsSync(seedsPath)) throw new Error('Missing src/data/coverage.seeds.json');
const seeds = readJSON(seedsPath) as Seeds;
const coverage = readJSON('src/data/serviceCoverage.json') as Record<string,string[]>;
const clusters = readJSON('src/content/areas.clusters.json').clusters as any[];
let ADJ: Record<string,string[]> = {}; try { ADJ = readJSON('src/content/areas.adj.json'); } catch {}

const allSubs = new Map<string,{slug:string;lat?:number;lng?:number;cluster:string}>();
for (const c of clusters) for (const s of c.suburbs) {
  const slug = (typeof s === 'string'? s : (s.slug||s.name)).toLowerCase().trim();
  allSubs.set(slug,{ slug, lat: s.lat, lng: s.lng, cluster: c.slug });
}

function hav(a:any,b:any){
  if (![a.lat,a.lng,b.lat,b.lng].every(Number.isFinite)) return Number.POSITIVE_INFINITY;
  const toRad=(d:number)=>(d*Math.PI)/180, R=6371;
  const dLat=toRad(b.lat-a.lat), dLon=toRad(b.lng-a.lng);
  const s1=Math.sin(dLat/2)**2, s2=Math.cos(toRad(a.lat))*Math.cos(toRad(b.lat))*Math.sin(dLon/2)**2;
  return 2*R*Math.asin(Math.sqrt(s1+s2));
}

const suggested: Record<string,string[]> = {};
const diff: Record<string,{add:string[],remove:string[]}> = {};

for (const [service, conf] of Object.entries(seeds)) {
  const baseSeeds = conf.seeds.map(s=>s.toLowerCase().trim()).filter(s=>allSubs.has(s));
  const inRadius = new Set<string>();
  const byHops = new Set<string>();

  if (conf.radiusKm && conf.radiusKm > 0) {
    const pts = baseSeeds.map(s=>allSubs.get(s)!);
    for (const cand of allSubs.values()) {
      if (pts.some(p=>hav(p,cand) <= conf.radiusKm!)) inRadius.add(cand.slug);
    }
  }
  const hops = Math.max(0, conf.hops ?? 0);
  if (hops > 0) {
    let frontier = new Set(baseSeeds);
    for (let i=0;i<hops;i++){
      const next = new Set<string>();
      frontier.forEach(sl => (ADJ[sl]||[]).forEach(n=>next.add(n)));
      next.forEach(n=>byHops.add(n));
      frontier = next;
    }
  }

  let pool: string[];
  if (conf.requireIntersect) {
    const inter = new Set<string>();
    inRadius.forEach(s => { if (byHops.has(s)) inter.add(s); });
    pool = Array.from(inter);
  } else {
    pool = Array.from(new Set([...inRadius,...byHops,...baseSeeds]));
  }

  const rank = pool.map(slug => {
    const cand = allSubs.get(slug)!;
    const d = Math.min(...baseSeeds.map(s=>hav(allSubs.get(s)!, cand)));
    const sameClusterBonus = baseSeeds.some(s=>allSubs.get(s)!.cluster===cand.cluster) ? -1 : 0;
    return { slug, d, sameClusterBonus, cluster: cand.cluster };
  }).sort((a,b)=>(a.d + a.sameClusterBonus) - (b.d + b.sameClusterBonus));

  const current = new Set((coverage[service]||[]).map(s=>s.toLowerCase().trim()));
  const chosen: string[] = [];
  const perCluster = new Map<string,number>();
  const addCap = Math.max(0, conf.maxAdd ?? rank.length);
  const clusterCap = Math.max(1, conf.clusterCap ?? rank.length);
  for (const r of rank) {
    if (current.has(r.slug)) { chosen.push(r.slug); continue; }
    const added = chosen.filter(s=>!current.has(s)).length;
    if (added >= addCap) break;
    const used = perCluster.get(r.cluster)||0;
    if (used >= clusterCap) continue;
    perCluster.set(r.cluster, used+1);
    chosen.push(r.slug);
  }

  const union = Array.from(new Set([...current, ...chosen])).sort();
  suggested[service] = union;
  const before = new Set(coverage[service]||[]);
  const after = new Set(union);
  const add = [...after].filter(x=>!before.has(x));
  const remove = [...before].filter(x=>!after.has(x));
  diff[service] = { add: add.sort(), remove: remove.sort() };
}

const outDir = path.join(process.cwd(),'scripts/tmp');
fs.mkdirSync(outDir,{recursive:true});
fs.writeFileSync(path.join(outDir,'coverage.suggested.json'), JSON.stringify(suggested,null,2));
fs.writeFileSync(path.join(outDir,'coverage.diff.json'), JSON.stringify(diff,null,2));
console.log('✅ wrote scripts/tmp/coverage.suggested.json and coverage.diff.json');
console.log('Review adds (capped & balanced), update src/data/serviceCoverage.json, then run prebuild.');
