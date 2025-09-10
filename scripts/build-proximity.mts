#!/usr/bin/env node
import fs from 'node:fs';
import path from 'node:path';
import { createHash } from 'node:crypto';
import { getClustersSync, listSuburbsForClusterSyncAsObjects, getNearbySuburbs } from '../src/lib/clusters';

const ROOT = process.cwd();
const outDir = path.join(ROOT, 'src/content/_generated');
fs.mkdirSync(outDir, { recursive: true });

const clusterSlugs = getClustersSync().map(c => c.slug);
const allSuburbs = Array.from(new Set(clusterSlugs.flatMap(c => listSuburbsForClusterSyncAsObjects(c).map(s => s.slug))));
const nearby: Record<string,{slug:string;name:string}[]> = {};
for (const slug of allSuburbs) {
  nearby[slug] = getNearbySuburbs(slug, { limit: 6 }).map(s => ({ slug: s.slug, name: s.name }));
}

const payload = { nearby };
const etag = createHash('sha1').update(JSON.stringify(payload)).digest('hex');
fs.writeFileSync(path.join(outDir, 'proximity.json'), JSON.stringify({ etag, ...payload }, null, 2));
console.log(`✅ Proximity snapshot for ${allSuburbs.length} suburbs (ETag ${etag})`);
