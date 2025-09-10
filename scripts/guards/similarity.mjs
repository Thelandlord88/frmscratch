#!/usr/bin/env node
import fs from 'node:fs';
import path from 'node:path';
import { JSDOM } from 'jsdom';

// Shingle-based near-duplicate detector on suburb pages
function getHtmlPages(root) {
  const out = [];
  for (const f of fs.readdirSync(root, { withFileTypes: true })) {
    const p = path.join(root, f.name);
    if (f.isDirectory()) out.push(...getHtmlPages(p));
    else if (f.name.endsWith('.html')) out.push(p);
  }
  return out;
}

function textOf(file){
  const html = fs.readFileSync(file, 'utf8');
  const doc = new JSDOM(html).window.document;
  const body = doc.querySelector('main') || doc.body;
  return (body?.textContent || '').replace(/\s+/g, ' ').trim().toLowerCase();
}
function shingles(s, size=8){
  const a = s.split(/\s+/), out = [];
  for (let i=0;i+size<=a.length;i++) out.push(a.slice(i,i+size).join(' '));
  return new Set(out);
}
function jaccard(a,b){
  const A=[...a], B=[...b]; const u=new Set([...A,...B]); const i=[...a].filter(x=>b.has(x)).length; return i / u.size;
}

const pages = getHtmlPages('dist').filter(p => /\/suburbs\/[^/]+\/index\.html$/.test(p));
const violations = [];
for (let i=0;i<pages.length;i++){
  for (let j=i+1;j<pages.length;j++){
    const s1 = shingles(textOf(pages[i]));
    const s2 = shingles(textOf(pages[j]));
    const sim = jaccard(s1, s2);
    if (sim >= 0.92) violations.push({ a: pages[i], b: pages[j], sim });
  }
}
if (violations.length){
  fs.mkdirSync('.tmp/guards', {recursive:true});
  fs.writeFileSync('.tmp/guards/similarity.json', JSON.stringify(violations,null,2));
  console.error('[guard:similar] near-duplicate suburb pages detected');
  process.exit(2);
}
console.log('[guard:similar] ok');
