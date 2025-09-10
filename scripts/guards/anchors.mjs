#!/usr/bin/env node
import fs from 'node:fs';
import path from 'node:path';
import { JSDOM } from 'jsdom';
const dist = 'dist';
if (!fs.existsSync(dist)) { console.error('dist not found'); process.exit(1); }

function walk(dir){ return fs.readdirSync(dir, {withFileTypes:true})
  .flatMap(d=> d.isDirectory()? walk(path.join(dir,d.name)) : d.name.endsWith('.html')? [path.join(dir,d.name)] : []); }

const pages = walk(dist);
const violations = [];
for (const p of pages) {
  const html = fs.readFileSync(p,'utf8');
  const doc = new JSDOM(html).window.document;
  const anchors = Array.from(doc.querySelectorAll('a')).map(a=> (a.textContent||'').trim().toLowerCase()).filter(Boolean);
  const counts = anchors.reduce((m,t)=> (m[t]=(m[t]||0)+1, m), {});
  const bad = Object.entries(counts).filter(([,c]) => c >= 6); // repeated same label too often
  if (bad.length) violations.push({ page: p, bad });
}
if (violations.length){
  fs.mkdirSync('.tmp/guards', {recursive:true});
  fs.writeFileSync('.tmp/guards/anchors.json', JSON.stringify(violations,null,2));
  console.error('[guard:anchors] excessive repeated anchor labels found');
  process.exit(2);
}
console.log('[guard:anchors] ok');
