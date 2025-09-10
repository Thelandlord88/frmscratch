#!/usr/bin/env tsx
/**
 * Import "true" geo data from the Suburb Data True/ directory and emit
 * canonical project-format geo files:
 *   - src/content/areas.clusters.json (object form with suburb objects & lat/lng)
 *   - src/content/areas.adj.json (record<string,string[]>)
 *
 * Source files expected:
 *   Suburb Data True/clusters.json  (record: clusterSlug -> { lga, suburbs[] })
 *   Suburb Data True/suburbs.csv    (columns: name_official,slug,*,centroid_lat,centroid_lon)
 *   Suburb Data True/adjacency.json (record: suburb -> { adjacent_suburbs:[], ... })
 */
import { readFileSync, writeFileSync } from 'node:fs';
import { mkdirSync } from 'node:fs';
import { resolve } from 'node:path';

// Utility: safe JSON read
function readJSON(path: string) {
  return JSON.parse(readFileSync(path, 'utf8'));
}

// Parse CSV simple (no quoted commas present in provided data)
function readCSV(path: string) {
  const raw = readFileSync(path, 'utf8').trim();
  const [headerLine, ...lines] = raw.split(/\r?\n/);
  const headers = headerLine.split(',');
  return lines.filter(l => l.trim()).map(line => {
    const cols = line.split(',');
    const row: Record<string,string> = {};
    headers.forEach((h,i)=> row[h] = (cols[i] ?? '').trim());
    return row;
  });
}

function slugify(s: string) { return s.toLowerCase().replace(/[^a-z0-9]+/g,'-').replace(/^-|-$|(--)+/g,'-'); }

const SOURCE_DIR = resolve('Suburb Data True');
const CLUSTERS_SRC = resolve(SOURCE_DIR, 'clusters.json');
const SUBURBS_CSV = resolve(SOURCE_DIR, 'suburbs.csv');
const ADJ_SRC      = resolve(SOURCE_DIR, 'adjacency.json');

const OUT_CLUSTERS = resolve('src/content/areas.clusters.json');
const OUT_ADJ      = resolve('src/content/areas.adj.json');

interface SuburbObj { slug: string; name: string; lat?: number; lng?: number; }

function main() {
  console.log('🌐 Importing true geo dataset...');
  const clustersRaw = readJSON(CLUSTERS_SRC) as Record<string,{ lga: string; suburbs: string[] }>;
  const suburbRows = readCSV(SUBURBS_CSV);
  const adjRaw = readJSON(ADJ_SRC) as Record<string,{ adjacent_suburbs?: string[] }>;

  // Map slug -> coords
  const coords = new Map<string,{lat:number,lng:number,name:string}>();
  for (const r of suburbRows) {
    const slug = r.slug?.trim().toLowerCase();
    if (!slug) continue;
    const lat = parseFloat(r.centroid_lat);
    const lng = parseFloat(r.centroid_lon);
    if (!Number.isFinite(lat) || !Number.isFinite(lng)) continue;
    coords.set(slug, { lat, lng, name: r.name_official || slug });
  }

  // Build clusters in target schema
  const clustersOut: any[] = [];
  for (const [clusterSlug, info] of Object.entries(clustersRaw)) {
    const suburbs: SuburbObj[] = info.suburbs.map(s => {
      const slug = s.toLowerCase();
      const c = coords.get(slug);
      return c ? { slug, name: c.name, lat: c.lat, lng: c.lng } : { slug, name: slug.replace(/-/g,' ') };
    });
    clustersOut.push({ slug: clusterSlug, name: info.lga || clusterSlug.replace(/-/g,' '), suburbs });
  }

  const clustersJson = { clusters: clustersOut };
  mkdirSync(resolve('src/content'), { recursive: true });
  writeFileSync(OUT_CLUSTERS, JSON.stringify(clustersJson, null, 2));
  console.log(`✅ Wrote ${OUT_CLUSTERS} (clusters=${clustersOut.length})`);

  // Build adjacency: record<string,string[]>
  const adjOut: Record<string,string[]> = {};
  for (const [slug, node] of Object.entries(adjRaw)) {
    const list = node?.adjacent_suburbs || [];
    adjOut[slug.toLowerCase()] = Array.from(new Set(list.map(s => s.toLowerCase()).filter(Boolean))).sort();
  }
  writeFileSync(OUT_ADJ, JSON.stringify(adjOut, null, 2));
  console.log(`✅ Wrote ${OUT_ADJ} (nodes=${Object.keys(adjOut).length})`);

  // Quick integrity summary
  const missingCoords = clustersOut.flatMap(c => c.suburbs).filter((s:SuburbObj)=> s.lat==null || s.lng==null).length;
  console.log(`ℹ️  Suburbs with coordinates: ${coords.size}; Without coords in clusters: ${missingCoords}`);
  // === Provenance digest ===
  try {
    const clustersDoc = clustersJson;
    const adjDoc = adjOut;
    const clusterCount = clustersDoc.clusters.length;
    const suburbCount = clustersDoc.clusters.reduce((a: number, c: any) => a + c.suburbs.length, 0);
    const coordsFilled = clustersDoc.clusters.reduce((a: number, c: any) => a + c.suburbs.filter((s: any) => Number.isFinite(s.lat) && Number.isFinite(s.lng)).length, 0);
    const map = new Map<string,string>();
    for (const c of clustersDoc.clusters) for (const s of c.suburbs) map.set((s.slug||s.name).toLowerCase(), c.slug);
    let crossEdges = 0;
    for (const [k, list] of Object.entries(adjDoc)) {
      for (const v of list) if (map.get(k) && map.get(v) && map.get(k) !== map.get(v)) crossEdges++;
    }
    const srcIdxPath = resolve('Suburb Data True', 'sources_index.json');
    let provSummary = '';
    try {
      const provRaw = readFileSync(srcIdxPath,'utf8');
      const prov = JSON.parse(provRaw);
      if (Array.isArray(prov)) {
        provSummary = prov.map((p:any)=> p.name || '').join(', ');
      } else if (Array.isArray(prov.sources)) {
        provSummary = prov.sources.map((p:any)=> p.name || '').join(', ');
      }
    } catch {}
    console.log('--- geo:import digest ---');
    console.log(`clusters: ${clusterCount}, suburbs: ${suburbCount}, coords: ${coordsFilled}/${suburbCount} (${Math.round(100*coordsFilled/suburbCount)}%)`);
    console.log(`adjacency nodes: ${Object.keys(adjDoc).length}, cross-cluster edges: ${crossEdges}`);
    if (provSummary) console.log('sources: ' + provSummary);
    console.log('--- end digest ---');
  } catch {}
  console.log('Done. Run: npm run lint:data && npm run lint:graph');
}

try { main(); } catch (err:any) { console.error('❌ Import failed:', err?.stack || err); process.exit(1); }
