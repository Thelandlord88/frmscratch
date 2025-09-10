import { defineConfig } from 'astro/config';
import tailwind from '@tailwindcss/vite';

export default defineConfig({
  site: import.meta.env.SITE_URL || 'https://example.com',
  vite: {
    plugins: [tailwind()],
  },
});
