#!/usr/bin/env node
/**
 * Guard: ensure we only use folder-based suburb dynamic route: [service]/[suburb]/index.astro
 * Any sibling file named [suburb].astro or [...suburb].astro (case-insensitive) should fail CI.
 */
import { readdirSync, statSync } from 'node:fs';
import { join } from 'node:path';

const ROOT = process.cwd();
const PAGES = join(ROOT, 'src/pages');
const offenders: string[] = [];

function walk(dir: string) {
  for (const entry of readdirSync(dir)) {
    const full = join(dir, entry);
    const st = statSync(full);
    if (st.isDirectory()) {
      walk(full);
      continue;
    }
    const lower = full.toLowerCase();
    if (/(\[suburb\]\.astro)$/.test(lower) || /(\[\.\.\.suburb\]\.astro)$/.test(lower)) {
      if (lower.endsWith('/__remove__[suburb].astro')) continue; // safety skip if renamed placeholder
      // skip if it's inside a folder with index.astro (folder-based OK). This file itself is the offender.
      // Accept only pattern */[service]/[suburb]/index.astro (handled elsewhere) so any direct [suburb].astro is a violation.
      if (!/\/[[]suburb[]]\/index\.astro$/.test(lower)) offenders.push(full);
    }
  }
}

try {
  walk(PAGES);
} catch (e) {
  console.error('Traversal error:', e);
}

if (offenders.length) {
  console.error('\n❌ Duplicate suburb dynamic route file(s) detected. Use the folder variant with index.astro only:');
  for (const f of offenders) console.error('  -', f.replace(ROOT + '/', ''));
  console.error('\nFix: remove these files (the canonical route is src/pages/services/[service]/[suburb]/index.astro)');
  process.exit(1);
}

console.log('✅ No duplicate suburb dynamic route files.');
