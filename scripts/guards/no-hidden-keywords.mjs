#!/usr/bin/env node
import fs from 'node:fs';
import path from 'node:path';
import { JSDOM } from 'jsdom';
const pages = (function walk(dir){ return fs.readdirSync(dir,{withFileTypes:true})
  .flatMap(d=> d.isDirectory()? walk(path.join(dir,d.name)) : d.name.endsWith('.html')? [path.join(dir,d.name)] : []); })('dist');

const violations = [];
for (const p of pages) {
  const html = fs.readFileSync(p,'utf8');
  const doc = new JSDOM(html).window.document;
  const hidden = Array.from(doc.querySelectorAll('[hidden], [style*="display:none"], [style*="visibility:hidden"]'))
    .filter(el => /clean|bond|suburb|service|quote/i.test(el.textContent || ''));
  if (hidden.length) violations.push({ page: p, count: hidden.length });
}
if (violations.length){
  fs.mkdirSync('.tmp/guards', {recursive:true});
  fs.writeFileSync('.tmp/guards/hidden.json', JSON.stringify(violations,null,2));
  console.error('[guard:hidden] hidden keyword blocks detected');
  process.exit(2);
}
console.log('[guard:hidden] ok');
