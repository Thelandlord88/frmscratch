#!/usr/bin/env node
import { spawnSync } from 'node:child_process';
const cmds = [
  ['node', ['scripts/guards/anchors.mjs']],
  ['node', ['scripts/guards/no-hidden-keywords.mjs']],
  ['node', ['scripts/guards/no-ua-dom.mjs']],
  ['node', ['scripts/guards/similarity.mjs']]
];
for (const [bin, args] of cmds) {
  const r = spawnSync(bin, args, { stdio: 'inherit' });
  if (r.status !== 0) process.exit(r.status || 2);
}
console.log('[guard:all] ok');
