#!/usr/bin/env node
// Split a large cluster into K subclusters using simple k-means on lat/lng.
// After running: re-run geo:import (if upstream raw changes), then coverage suggestions.

import fs from 'node:fs';
import path from 'node:path';

const ROOT = process.cwd();
const file = path.join(ROOT, 'src/content/areas.clusters.json');
const K = parseInt(process.env.K || '3', 10);
const TARGET = (process.env.CLUSTER || 'brisbane-city').toLowerCase();
const BASE_NAME = process.env.BASE_NAME || 'Brisbane';
const BASE_SLUG = (process.env.BASE_SLUG || 'brisbane').toLowerCase();

if (!fs.existsSync(file)) { console.error('Missing areas.clusters.json'); process.exit(1); }
const doc = JSON.parse(fs.readFileSync(file,'utf8')) as { clusters: any[] };
const idx = doc.clusters.findIndex(c => c.slug === TARGET);
if (idx < 0) { console.error(`Cluster ${TARGET} not found`); process.exit(1); }

const subs = doc.clusters[idx].suburbs.filter((s: any)=> Number.isFinite(s.lat) && Number.isFinite(s.lng));
if (subs.length < K) { console.error(`Not enough coord suburbs (${subs.length}) for K=${K}`); process.exit(1); }

// init centroids (evenly spaced)
let centroids = subs.filter((_,i)=> i % Math.floor(subs.length / K) === 0).slice(0,K).map((s:any)=>[s.lat,s.lng]);
function dist(a:number[], b:number[]){ const dx=a[0]-b[0], dy=a[1]-b[1]; return dx*dx+dy*dy; }

for (let iter=0; iter<50; iter++) {
  const buckets:any[][] = Array.from({length:K}, ()=>[]);
  for (const s of subs) {
    const pt=[s.lat,s.lng]; let best=0, bd=Infinity;
    for (let k=0;k<K;k++){ const d=dist(pt, centroids[k]); if (d<bd){ bd=d; best=k; } }
    buckets[best].push(s);
  }
  const newC = centroids.map((c,k)=>{
    if (!buckets[k].length) return c;
    const lat=buckets[k].reduce((a,b)=>a+b.lat,0)/buckets[k].length;
    const lng=buckets[k].reduce((a,b)=>a+b.lng,0)/buckets[k].length;
    return [lat,lng];
  });
  if (newC.every((c,i)=> Math.abs(c[0]-centroids[i][0])<1e-6 && Math.abs(c[1]-centroids[i][1])<1e-6)) break;
  centroids = newC;
}

const labels = ['inner-north','west','bayside','south','east','north'];
function assignBucket(s:any){
  const pt=[s.lat,s.lng]; let best=0, bd=Infinity; for (let k=0;k<K;k++){ const d=dist(pt,centroids[k]); if(d<bd){ bd=d; best=k; } } return best;
}

const newClusters:any[] = [];
for (let k=0;k<K;k++) {
  const bucket = subs.filter(s=> assignBucket(s)===k);
  const slug = `${BASE_SLUG}-${labels[k] || `part-${k+1}`}`;
  const name = `${BASE_NAME} ${ (labels[k]||`Part ${k+1}`) }`;
  newClusters.push({ slug, name, suburbs: bucket });
}

// replace target cluster
doc.clusters.splice(idx,1,...newClusters);
fs.writeFileSync(file, JSON.stringify(doc,null,2));
console.log(`✅ split ${TARGET} -> ${newClusters.map(c=>c.slug).join(', ')}`);
