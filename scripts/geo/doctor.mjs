#!/usr/bin/env node
import fs from 'node:fs';

function load(p){ if (!fs.existsSync(p)) throw new Error(`Missing data: ${p}`); return JSON.parse(fs.readFileSync(p,'utf8')); }

try {
  const suburbs = load('src/data/suburbs.json');
  const services = load('src/data/services.json');

  const slugs = new Set();
  for (const s of suburbs) {
    if (!/^[a-z0-9-]+$/.test(s.slug)) throw new Error(`Bad suburb slug: ${s.slug}`);
    if (slugs.has(s.slug)) throw new Error(`Duplicate suburb slug: ${s.slug}`);
    slugs.add(s.slug);
    if (!Array.isArray(s.neighbors)) throw new Error(`Suburb.neighbors must be array: ${s.slug}`);
  }

  const svcSlugs = new Set();
  for (const s of services) {
    if (!/^[a-z0-9-]+$/.test(s.slug)) throw new Error(`Bad service slug: ${s.slug}`);
    if (svcSlugs.has(s.slug)) throw new Error(`Duplicate service slug: ${s.slug}`);
    svcSlugs.add(s.slug);
  }

  // synthesize build paths for a quick smoke list
  const buildPaths = [];
  const suburbPages = suburbs.map(s => `/suburbs/${s.slug}/`);
  buildPaths.push(...suburbPages);
  for (const svc of services) for (const s of suburbs) buildPaths.push(`/services/${svc.slug}/${s.slug}/`);

  fs.mkdirSync('.tmp', { recursive: true });
  fs.writeFileSync('.tmp/smoke-paths.json', JSON.stringify(buildPaths.slice(0, 200), null, 2));
  console.log('[geo:doctor] ok - wrote .tmp/smoke-paths.json');
} catch (e) {
  console.error('[geo:doctor] ' + (e?.message || e));
  process.exit(2);
}
