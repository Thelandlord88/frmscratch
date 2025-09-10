import { test, expect } from '@playwright/test';
import fs from 'node:fs';

const paths: string[] = JSON.parse(fs.readFileSync('.tmp/smoke-paths.json','utf8'));

for (const p of paths.slice(0, 12)) {
  test(`200 & JSON-LD exists: ${p}`, async ({ page }) => {
    const url = new URL(p, process.env.PREVIEW_URL || 'http://localhost:4321').toString();
    const res = await page.goto(url, { waitUntil: 'domcontentloaded' });
    expect(res?.ok(), `status for ${url}`).toBeTruthy();
    const jsonld = await page.locator('script[type="application/ld+json"]').all();
    expect(jsonld.length).toBeGreaterThan(0);
  });
}
