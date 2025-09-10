#!/usr/bin/env node
import fs from 'node:fs';
import path from 'node:path';

const ROOT = 'dist';
if (!fs.existsSync(ROOT)) { console.error('[guard:ua] dist not found'); process.exit(1); }

function walk(dir){
  const out = [];
  for (const d of fs.readdirSync(dir, { withFileTypes:true })){
    const p = path.join(dir, d.name);
    if (d.isDirectory()) out.push(...walk(p));
    else if (d.name.endsWith('.html') || d.name.endsWith('.js')) out.push(p);
  }
  return out;
}

const files = walk(ROOT);
const offenders = [];
const re = /navigator\.userAgent|userAgentData/;
for (const f of files){
  try {
    const txt = fs.readFileSync(f, 'utf8');
    if (re.test(txt)) offenders.push(f);
  } catch {}
}

if (offenders.length){
  fs.mkdirSync('.tmp/guards', { recursive:true });
  fs.writeFileSync('.tmp/guards/ua.json', JSON.stringify({ offenders }, null, 2));
  console.error('[guard:ua] user-agent based DOM branching detected in:', offenders[0]);
  process.exit(2);
}
console.log('[guard:ua] ok');
