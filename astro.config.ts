import { defineConfig } from 'astro/config';
import tailwind from '@tailwindcss/vite';
// Types can drift between Astro-bundled Vite and local Vite; use any to avoid config-time type frictions.

export default defineConfig({
  site: process.env.SITE_URL || 'https://example.com',
  vite: {
  plugins: [tailwind() as any],
  },
});
