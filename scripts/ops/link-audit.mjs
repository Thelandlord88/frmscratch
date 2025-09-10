#!/usr/bin/env node
import { readFileSync, readdirSync, statSync, existsSync } from 'node:fs';
import { join } from 'node:path';

const DIST = join(process.cwd(), 'dist');
if (!existsSync(DIST)) {
	console.log('ℹ️ dist/ not found – skipping link audit');
	process.exit(0);
}

const files = [];
(function walk(p) {
	for (const n of readdirSync(p)) {
		const f = join(p, n);
		const st = statSync(f);
		if (st.isDirectory()) walk(f); else if (f.endsWith('.html')) files.push(f);
	}
})(DIST);

let bad = [];
for (const f of files) {
	const html = readFileSync(f, 'utf8');
	if (/\/(undefined|null|NaN)\//.test(html)) bad.push(f);
}

if (bad.length) {
	console.error('❌ Link audit failed ('+bad.length+' file'+(bad.length>1?'s':'')+'):\n' + bad.map(x => '  - '+x).join('\n'));
	process.exit(1);
}
console.log(`✅ Link audit clean (${files.length} HTML files scanned)`);
