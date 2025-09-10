#!/usr/bin/env node
import fs from 'node:fs';
import { GeoConfigSchema } from '../../src/lib/schemas';

try {
  const raw = fs.readFileSync('src/content/geo.config.json','utf8');
  GeoConfigSchema.parse(JSON.parse(raw));
  console.log('✅ geo.config.json valid');
} catch (e:any) {
  if (e?.errors) {
    console.error('❌ geo.config.json invalid:');
    for (const err of e.errors) {
      console.error('  - ' + err.path.join('.') + ': ' + err.message);
    }
  } else {
    console.error('❌ geo.config validation failed:', e.message);
  }
  process.exit(1);
}
