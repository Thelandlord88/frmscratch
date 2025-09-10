import { defineConfig, devices } from '@playwright/test';
export default defineConfig({
  testDir: 'tests/smoke',
  timeout: 30_000,
  use: { baseURL: process.env.PREVIEW_URL || 'http://localhost:4321' },
  projects: [{ name: 'chromium', use: { ...devices['Desktop Chrome'] } }]
});
