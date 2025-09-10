#!/usr/bin/env node
import { readFileSync } from 'node:fs';

const clusters = JSON.parse(readFileSync('src/content/areas.clusters.json','utf8')).clusters as any[];
const known = new Set(clusters.flatMap((c: any) => (c.suburbs || []).map((s: any) => (typeof s === 'string' ? s : (s.slug || s.name)).toLowerCase())));
const coverage = JSON.parse(readFileSync('src/data/serviceCoverage.json','utf8')) as Record<string,string[]>;
const problems: string[] = [];
for (const [service, list] of Object.entries(coverage)) {
  for (const s of list) if (!known.has(s)) problems.push(`Service "${service}" references unknown suburb: ${s}`);
}
if (problems.length) {
  if (process.env.GEO_ALLOW_MISSING === '1') {
    console.warn('⚠️ Coverage validation warnings ('+problems.length+'):');
    for (const p of problems) console.warn('  - '+p);
  } else {
    console.error('❌ Coverage validation failed:\n' + problems.map(p => '  - '+p).join('\n'));
    process.exit(1);
  }
} else {
  console.log('✅ Coverage validation passed');
}
