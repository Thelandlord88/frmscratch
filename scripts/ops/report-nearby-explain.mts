#!/usr/bin/env node
import { explainNearby } from '../../src/lib/geo/proximity';

const suburb = process.argv[2] || 'rosewood';
const service = process.argv[3] || 'bond-cleaning';

const rows = explainNearby(suburb, { service });
console.log(`Explain: ${service} near ${suburb}`);
console.log('slug              total   adj    clus   dist   -xcl  weight');
for (const r of rows) {
  const fmt = (n:number)=> (n>=0? ' ' : '') + n.toFixed(1).padStart(6);
  console.log(`${r.slug.padEnd(16)} ${fmt(r.total)} ${fmt(r.adjacencyOrderBonus)} ${fmt(r.clusterBoost)} ${fmt(r.distanceBonus)} ${fmt(-r.crossClusterPenalty)} ${fmt(r.weightFn)}`);
}
