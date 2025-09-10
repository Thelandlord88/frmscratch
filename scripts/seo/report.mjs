#!/usr/bin/env node
import { JSDOM } from 'jsdom';
import fs from 'node:fs';
import path from 'node:path';

const dist = 'dist';
if (!fs.existsSync(dist)) {
  console.error('dist not found. Run `npm run build` first.');
  process.exit(1);
}

function walk(dir) {
  const out = [];
  for (const f of fs.readdirSync(dir)) {
    const p = path.join(dir, f);
    const s = fs.statSync(p);
    if (s.isDirectory()) out.push(...walk(p));
    else if (f.endsWith('.html')) out.push(p);
  }
  return out;
}

const pages = walk(dist);
const summary = { pages: 0, missingCanonicals: [], jsonldErrors: [], duplicateCanonicals: [] };
for (const p of pages) {
  const html = fs.readFileSync(p, 'utf8');
  const dom = new JSDOM(html);
  const doc = dom.window.document;

  const canon = doc.querySelector('link[rel="canonical"]')?.getAttribute('href') || '';
  if (!canon) summary.missingCanonicals.push(p);

  const scripts = Array.from(doc.querySelectorAll('script[type="application/ld+json"]'));
  try {
    for (const s of scripts) JSON.parse(s.textContent || '{}');
  } catch (e) {
    summary.jsonldErrors.push(p);
  }

  // crude check: multiple canonicals
  const canonCount = doc.querySelectorAll('link[rel="canonical"]').length;
  if (canonCount > 1) summary.duplicateCanonicals.push(p);
}
summary.pages = pages.length;

const outDir = '.tmp/seo';
fs.mkdirSync(outDir, { recursive: true });
fs.writeFileSync(path.join(outDir, 'summary.json'), JSON.stringify(summary, null, 2));
console.log('[seo:report] wrote .tmp/seo/summary.json');
if (summary.missingCanonicals.length || summary.jsonldErrors.length) {
  console.error('[seo:report] issues found');
  process.exitCode = 2;
}
