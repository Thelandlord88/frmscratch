#!/usr/bin/env node
import { readFileSync } from 'node:fs';

const clusters = JSON.parse(readFileSync('src/content/areas.clusters.json','utf8')).clusters as any[];
const known = new Set(clusters.flatMap((c: any) => (c.suburbs||[]).map((s:any)=> (typeof s==='string'? s : (s.slug||s.name)).toLowerCase())));
let proxRaw = '{}';
try { proxRaw = readFileSync('src/content/_generated/proximity.json','utf8'); } catch {}
const prox = proxRaw.trim() ? JSON.parse(proxRaw).nearby as Record<string,{slug:string;name:string}[]> : {};
const errs: string[] = [];
for (const [slug, list] of Object.entries(prox)) {
  if (!known.has(slug)) errs.push(`unknown suburb key: ${slug}`);
  for (const it of list) if (!known.has(it.slug)) errs.push(`nearby not in catalog: ${slug} -> ${it.slug}`);
}
if (errs.length) { console.error('❌ Proximity validation failed:\n' + errs.map(e => '  - '+e).join('\n')); process.exit(1); }
console.log('✅ Proximity snapshot OK');
