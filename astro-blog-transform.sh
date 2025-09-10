#!/usr/bin/env bash
set -euo pipefail

# ================================
# Astro Blog Transformation Script
# ================================
# Turns a basic (or greenfield) Astro project into a production-ready blog
# with content collections, taxonomy, RSS, business conversion paths (QuoteForm),
# analytics shim, sitemap, robots, AEST-friendly dates, and Playwright guardrails.
#
# Idempotent-leaning: files are backed up before overwrite (file.bak). Re-running
# is safe-ish (it won't double-install deps).

# --------- Logging helpers ---------
log_info()    { printf "\033[1;34m[INFO]\033[0m %s\n" "$*"; }
log_warn()    { printf "\033[1;33m[WARN]\033[0m %s\n" "$*"; }
log_error()   { printf "\033[1;31m[ERROR]\033[0m %s\n" "$*"; }
log_success() { printf "\033[1;32m[SUCCESS]\033[0m %s\n" "$*"; }

# --------- File helpers ---------
write_file() {
  local path="$1"
  local content="$2"
  local dir
  dir="$(dirname "$path")"
  mkdir -p "$dir"
  if [[ -f "$path" ]]; then
    cp "$path" "${path}.bak"
    log_warn "Backed up $path -> ${path}.bak"
  fi
  printf '%s\n' "$content" > "$path"
  log_info "Wrote: $path"
}

append_unique_line() {
  # Append a line to a file only if not present
  local path="$1"
  local line="$2"
  grep -qxF "$line" "$path" 2>/dev/null || echo "$line" >> "$path"
}

ensure_public_dir() {
  mkdir -p public
  log_info "Ensured ./public exists"
}

# --------- Preflight checks ---------
check_or_init_project() {
  if [[ ! -f package.json ]]; then
    log_warn "No package.json found. Initializing minimal Node project..."
    npm init -y >/dev/null
    log_info "Installing Astro..."
    npm i -D astro@latest >/dev/null
  fi
}

ensure_dep() {
  # $1 = package name
  local name="$1"
  if ! node -e "try{const p=require('./package.json'); process.exit(p.dependencies && p.dependencies['$name'] || p.devDependencies && p.devDependencies['$name'] ? 0:1);}catch(e){process.exit(1)}"; then
    log_info "Installing $name ..."
    npm i -D "$name" >/dev/null
  else
    log_info "Dependency already present: $name"
  fi
}

ensure_playwright_installed() {
  if ! npx --yes playwright --version >/dev/null 2>&1; then
    log_info "Installing Playwright (browsers + deps)..."
    npx --yes playwright install --with-deps >/dev/null
  else
    log_info "Playwright already installed"
  fi
}

backup_if_exists() {
  local path="$1"
  if [[ -f "$path" ]]; then
    cp "$path" "${path}.bak"
    log_warn "Backed up $path -> ${path}.bak"
  fi
}

# --------- Prompt helpers ---------
ask() {
  local var_name="$1"
  local prompt="$2"
  local default_val="${3-}"
  local current_val="${!var_name-}"
  if [[ -n "${current_val-}" ]]; then
    # already set from env; keep it
    return
  fi
  if [[ -n "$default_val" ]]; then
    read -rp "$prompt [$default_val]: " value
    value="${value:-$default_val}"
  else
    read -rp "$prompt: " value
  fi
  printf -v "$var_name" "%s" "$value"
}

# --------- Start ---------
log_info "Starting Astro Blog Transformation..."

check_or_init_project
ensure_public_dir

# Required deps (core script keeps it lean)
ensure_dep "@astrojs/rss"
ensure_dep "typescript"
ensure_dep "@types/node"
ensure_dep "@playwright/test"

# Ask for business information (env override possible)
ask BUSINESS_NAME        "Business/Brand name" "One N Done Bond Clean"
ask BUSINESS_LEGAL_NAME  "Legal name"          "One N Done Bond Clean"
ask BUSINESS_PHONE       "Phone"               "+61 400 000 000"
ask BUSINESS_EMAIL       "Public email"        "hello@example.com"
ask BUSINESS_URL         "Primary site URL (https://... no trailing slash)" "https://example.com"
ask BUSINESS_STREET      "Street address"      "123 Sample St"
ask BUSINESS_LOCALITY    "City/Suburb"         "Ipswich"
ask BUSINESS_REGION      "State/Region"        "QLD"
ask BUSINESS_POSTCODE    "Postcode"            "4305"
ask BUSINESS_COUNTRY     "Country code (ISO2)" "AU"
ask BUSINESS_ABN         "ABN (optional)"      ""
ask BUSINESS_HOURS       "Opening hours (comma-separated, e.g. Mo-Fr 08:00-18:00, Sa 09:00-13:00)" "Mo-Fr 08:00-18:00"

SITE_URL="$BUSINESS_URL"

# Update package.json scripts safely via Node
node - <<'NODE'
const fs = require('fs');
const p = './package.json';
const pkg = JSON.parse(fs.readFileSync(p, 'utf8'));

pkg.type = pkg.type || "module";
pkg.scripts = Object.assign({
  "dev": "astro dev",
  "build": "astro build",
  "preview": "astro preview",
  "sync": "astro sync",
  "test:e2e": "playwright test",
  "test:install": "playwright install --with-deps"
}, pkg.scripts || {});

// Keep name if already set
pkg.name = pkg.name || "astro-blog-site";
pkg.engines = pkg.engines || { "node": ">=20.3.0 <21 || >=22" };

fs.writeFileSync(p, JSON.stringify(pkg, null, 2));
console.log("[INFO] Updated package.json scripts and engines");
NODE

# Ensure tsconfig has proper alias for "@/"
if [[ -f "tsconfig.json" ]]; then
  node - <<'NODE'
const fs = require('fs');
const p = './tsconfig.json';
const ts = JSON.parse(fs.readFileSync(p, 'utf8'));
ts.compilerOptions = ts.compilerOptions || {};
ts.compilerOptions.module = ts.compilerOptions.module || "ESNext";
ts.compilerOptions.moduleResolution = ts.compilerOptions.moduleResolution || "bundler";
ts.compilerOptions.target = ts.compilerOptions.target || "ES2022";
ts.compilerOptions.strict = ts.compilerOptions.strict ?? true;
ts.compilerOptions.baseUrl = ts.compilerOptions.baseUrl || ".";
ts.compilerOptions.paths = ts.compilerOptions.paths || {};
ts.compilerOptions.paths["@/*"] = ["src/*"];
fs.writeFileSync(p, JSON.stringify(ts, null, 2));
console.log("[INFO] Ensured tsconfig.json alias @/* -> src/*");
NODE
else
  write_file "tsconfig.json" "$(cat <<'EOF'
{
  "compilerOptions": {
    "module": "ESNext",
    "moduleResolution": "bundler",
    "target": "ES2022",
    "strict": true,
    "baseUrl": ".",
    "paths": {
      "@/*": ["src/*"]
    },
    "types": ["@types/node"]
  }
}
EOF
)"
fi

# Back up astro.config.mjs if present
if [[ -f "astro.config.mjs" ]]; then
  backup_if_exists "astro.config.mjs"
fi

# Write astro.config.mjs (simple; preserves 'site' for sitemaps/RSS)
write_file "astro.config.mjs" "$(cat <<EOF
import { defineConfig } from 'astro/config';

export default defineConfig({
  site: '${SITE_URL}',
});
EOF
)"

# Content collections config
write_file "src/content/config.ts" "$(cat <<'EOF'
import { defineCollection, z } from 'astro:content';

export const ALLOWED_CATEGORIES = [
  'news','guides','tips','case-studies'
] as const;

export const ALLOWED_TAGS = [
  'bond-cleaning','checklists','kitchen','bathroom','bedroom','living-room','eco'
] as const;

const posts = defineCollection({
  type: 'content',
  schema: z.object({
    title: z.string(),
    description: z.string().max(200),
    publishDate: z.date(),
    draft: z.boolean().default(false),
    author: z.string().optional(),
    categories: z.array(z.enum(ALLOWED_CATEGORIES)),
    tags: z.array(z.enum(ALLOWED_TAGS)).optional(),
    heroImage: z.string().optional(),
  }),
});

export const collections = { posts };
EOF
)"

# Centralized taxonomy export (importable)
write_file "src/content/taxonomy.ts" "$(cat <<'EOF'
export { ALLOWED_CATEGORIES, ALLOWED_TAGS } from './config';
EOF
)"

# Business data (NAP authority)
write_file "src/data/business.json" "$(cat <<EOF
{
  "name": "${BUSINESS_NAME}",
  "legalName": "${BUSINESS_LEGAL_NAME}",
  "telephone": "${BUSINESS_PHONE}",
  "email": "${BUSINESS_EMAIL}",
  "url": "${BUSINESS_URL}",
  "address": {
    "streetAddress": "${BUSINESS_STREET}",
    "addressLocality": "${BUSINESS_LOCALITY}",
    "addressRegion": "${BUSINESS_REGION}",
    "postalCode": "${BUSINESS_POSTCODE}",
    "addressCountry": "${BUSINESS_COUNTRY}"
  },
  "abn": "${BUSINESS_ABN}",
  "openingHours": "${BUSINESS_HOURS}"
}
EOF
)"

# BaseLayout with analytics shim + canonical slot
write_file "src/layouts/BaseLayout.astro" "$(cat <<'EOF'
---
export interface Props {
  title?: string;
  description?: string;
  canonical?: string;
}
const { title = 'Site', description = 'Blog', canonical } = Astro.props;
---
<html lang="en">
  <head>
    <meta charset="utf-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1.0" />
    <title>{title}</title>
    <meta name="description" content={description} />
    {canonical && <link rel="canonical" href={canonical} />}
  </head>
  <body class="min-h-screen">
    <main class="px-6 py-8 max-w-4xl mx-auto">
      <slot />
    </main>

    <script>
      // Simple analytics shim — vendor-agnostic
      (function () {
        const endpoint = '/api/e';
        window.e_send = function (payload) {
          try {
            navigator.sendBeacon?.(endpoint, new Blob([JSON.stringify(payload || {})], { type: 'application/json' }));
          } catch (e) {}
        };
      })();
    </script>
  </body>
</html>
EOF
)"

# QuoteForm component with event
write_file "src/components/QuoteForm.astro" "$(cat <<'EOF'
---
export interface Props {
  variant?: 'inline' | 'page';
  source?: string;
}
const { variant = 'inline', source = 'unknown' } = Astro.props;
---
<form id="quote" class="space-y-4" method="post" action="/api/e" on:submit={(e) => {
  e.preventDefault();
  const fd = new FormData(e.currentTarget);
  const data = Object.fromEntries(fd.entries());
  window.e_send({ t: 'quote_submit', source: source, data });
  alert('Thanks! We will contact you shortly.');
}}>
  <div>
    <label class="block font-medium mb-1">Name</label>
    <input class="border rounded px-3 py-2 w-full" name="name" required />
  </div>
  <div>
    <label class="block font-medium mb-1">Email</label>
    <input class="border rounded px-3 py-2 w-full" name="email" type="email" required />
  </div>
  <div>
    <label class="block font-medium mb-1">Message</label>
    <textarea class="border rounded px-3 py-2 w-full" name="message" rows="4"></textarea>
  </div>
  <button class="px-4 py-2 rounded bg-blue-600 text-white">Request Quote</button>
</form>
EOF
)"

# Analytics endpoint
write_file "src/pages/api/e.ts" "$(cat <<'EOF'
import type { APIRoute } from 'astro';

export const POST: APIRoute = async ({ request }) => {
  try {
    // Consume payload; replace with real logging later
    await request.json().catch(() => ({}));
  } catch {}
  return new Response(null, { status: 204 });
};
EOF
)"

# Home page
write_file "src/pages/index.astro" "$(cat <<'EOF'
---
import BaseLayout from "@/layouts/BaseLayout.astro";
import QuoteForm from "@/components/QuoteForm.astro";
const canonical = new URL("/", Astro.site).toString();
---
<BaseLayout title="Home" description="Welcome" canonical={canonical}>
  <h1 class="text-4xl font-bold mb-4">Welcome</h1>
  <p class="text-slate-600 mb-8">Explore our latest posts and request a free quote.</p>
  <p class="mb-6"><a class="text-blue-600 underline" href="/blog/">Go to Blog</a></p>
  <div class="mt-10">
    <h2 class="text-2xl font-semibold mb-2">Get a free quote</h2>
    <QuoteForm variant="inline" source="home" />
  </div>
</BaseLayout>
EOF
)"

# Blog index
write_file "src/pages/blog/index.astro" "$(cat <<'EOF'
---
import BaseLayout from "@/layouts/BaseLayout.astro";
import { getCollection } from "astro:content";
const posts = (await getCollection('posts', ({ data }) => !data.draft))
  .sort((a,b) => +new Date(b.data.publishDate) - +new Date(a.data.publishDate));

const canonical = new URL("/blog/", Astro.site).toString();
---
<BaseLayout title="Blog" description="Latest articles" canonical={canonical}>
  <h1 class="text-3xl font-bold mb-6">Blog</h1>
  <ul class="space-y-6">
    {posts.map((p) => (
      <li>
        <a class="text-xl font-semibold hover:text-blue-600" href={`/blog/${p.slug}/`}>{p.data.title}</a>
        <div class="text-sm text-slate-600">
          {p.data.publishDate.toLocaleDateString('en-AU', { timeZone: 'Australia/Brisbane' })}
        </div>
        <p class="text-slate-700">{p.data.description}</p>
      </li>
    ))}
  </ul>
</BaseLayout>
EOF
)"

# Single post page
write_file "src/pages/blog/[slug].astro" "$(cat <<'EOF'
---
import BaseLayout from "@/layouts/BaseLayout.astro";
import QuoteForm from "@/components/QuoteForm.astro";
import { getCollection } from "astro:content";

export async function getStaticPaths() {
  const posts = await getCollection('posts');
  return posts.map((p) => ({ params: { slug: p.slug } }));
}

const { slug } = Astro.params;
const posts = await getCollection('posts');
const entry = posts.find((p) => p.slug === slug);
if (!entry) throw new Error('Post not found: ' + slug);

const { Content, data } = await entry.render();
const canonical = new URL(`/blog/${slug}/`, Astro.site).toString();
---
<BaseLayout title={data.title} description={data.description} canonical={canonical}>
  <article class="prose max-w-none">
    <h1 class="text-3xl font-bold mb-2">{data.title}</h1>
    <div class="text-sm text-slate-600 mb-6">
      {data.publishDate.toLocaleDateString('en-AU', { timeZone: 'Australia/Brisbane' })}
    </div>
    <Content />
  </article>
  <section class="mt-12">
    <h2 class="text-2xl font-semibold mb-2">Request a free quote</h2>
    <QuoteForm variant="inline" source={`post:${slug}`} />
  </section>
</BaseLayout>
EOF
)"

# Category listing
write_file "src/pages/blog/category/[category]/index.astro" "$(cat <<'EOF'
---
import BaseLayout from "@/layouts/BaseLayout.astro";
import { getCollection } from "astro:content";
import { ALLOWED_CATEGORIES } from "@/content/config";

export async function getStaticPaths() {
  return ALLOWED_CATEGORIES.map((category) => ({ params: { category } }));
}

const { category } = Astro.params;
const posts = (await getCollection('posts', ({ data }) => !data.draft))
  .filter(p => p.data.categories.includes(category))
  .sort((a,b) => +new Date(b.data.publishDate) - +new Date(a.data.publishDate));
const canonical = new URL(`/blog/category/${category}/`, Astro.site).toString();
---
<BaseLayout title={`Category: ${category}`} description={`Posts in ${category}`} canonical={canonical}>
  <h1 class="text-3xl font-bold mb-6">Category: {category}</h1>
  <ul class="space-y-6">
    {posts.map(p => (
      <li>
        <a class="text-xl font-semibold hover:text-blue-600" href={`/blog/${p.slug}/`}>{p.data.title}</a>
        <p class="text-slate-600">{p.data.description}</p>
      </li>
    ))}
  </ul>
</BaseLayout>
EOF
)"

# Tag listing
write_file "src/pages/blog/tag/[tag]/index.astro" "$(cat <<'EOF'
---
import BaseLayout from "@/layouts/BaseLayout.astro";
import { getCollection } from "astro:content";
import { ALLOWED_TAGS } from "@/content/config";

export async function getStaticPaths() {
  return ALLOWED_TAGS.map((tag) => ({ params: { tag } }));
}

const { tag } = Astro.params;
const posts = (await getCollection('posts', ({ data }) => !data.draft)))
  .filter(p => (p.data.tags ?? []).includes(tag))
  .sort((a,b) => +new Date(b.data.publishDate) - +new Date(a.data.publishDate));
const canonical = new URL(`/blog/tag/${tag}/`, Astro.site).toString();
---
<BaseLayout title={`Tag: ${tag}`} description={`Posts tagged ${tag}`} canonical={canonical}>
  <h1 class="text-3xl font-bold mb-6">Tag: {tag}</h1>
  <ul class="space-y-6">
    {posts.map(p => (
      <li>
        <a class="text-xl font-semibold hover:text-blue-600" href={`/blog/${p.slug}/`}>{p.data.title}</a>
        <p class="text-slate-600">{p.data.description}</p>
      </li>
    ))}
  </ul>
</BaseLayout>
EOF
)"

# Main RSS
write_file "src/pages/rss.xml.ts" "$(cat <<'EOF'
import rss from '@astrojs/rss';
import { getCollection } from 'astro:content';

export async function GET(context: any) {
  const posts = await getCollection('posts', ({ data }) => !data.draft);
  return rss({
    title: 'Blog RSS',
    description: 'Latest posts',
    site: context.site,
    items: posts
      .sort((a,b) => +new Date(b.data.publishDate) - +new Date(a.data.publishDate))
      .map(p => ({
        title: p.data.title,
        description: p.data.description,
        pubDate: p.data.publishDate,
        link: `/blog/${p.slug}/`,
        author: p.data.author,
      })),
  });
}
EOF
)"

# Category RSS
write_file "src/pages/blog/category/[category]/rss.xml.ts" "$(cat <<'EOF'
import rss from '@astrojs/rss';
import { getCollection } from 'astro:content';
import { ALLOWED_CATEGORIES } from '@/content/config';

export async function getStaticPaths() {
  return ALLOWED_CATEGORIES.map((category) => ({ params: { category } }));
}

export async function GET(context: any) {
  const { category } = context.params;
  const posts = await getCollection('posts', ({ data }) => !data.draft && data.categories.includes(category));

  return rss({
    title: `Category: ${category}`,
    description: `Latest posts in ${category}`,
    site: context.site,
    items: posts
      .sort((a,b) => +new Date(b.data.publishDate) - +new Date(a.data.publishDate))
      .map(p => ({
        title: p.data.title,
        description: p.data.description,
        pubDate: p.data.publishDate,
        link: `/blog/${p.slug}/`,
        author: p.data.author,
      })),
  });
}
EOF
)"

# Tag RSS
write_file "src/pages/blog/tag/[tag]/rss.xml.ts" "$(cat <<'EOF'
import rss from '@astrojs/rss';
import { getCollection } from 'astro:content';
import { ALLOWED_TAGS } from '@/content/config';

export async function getStaticPaths() {
  return ALLOWED_TAGS.map((tag) => ({ params: { tag } }));
}

export async function GET(context: any) {
  const { tag } = context.params;
  const posts = await getCollection('posts', ({ data }) => !data.draft && (data.tags ?? []).includes(tag));

  return rss({
    title: `Tag: ${tag}`,
    description: `Latest posts tagged ${tag}`,
    site: context.site,
    items: posts
      .sort((a,b) => +new Date(b.data.publishDate) - +new Date(a.data.publishDate))
      .map(p => ({
        title: p.data.title,
        description: p.data.description,
        pubDate: p.data.publishDate,
        link: `/blog/${p.slug}/`,
        author: p.data.author,
      })),
  });
}
EOF
)"

# sitemap.xml.ts
write_file "src/pages/sitemap.xml.ts" "$(cat <<'EOF'
import type { APIContext } from 'astro';
import { getCollection } from 'astro:content';
import { ALLOWED_CATEGORIES, ALLOWED_TAGS } from '@/content/config';

export async function GET({ site }: APIContext) {
  if (!site) {
    return new Response('site missing in astro.config', { status: 500 });
  }
  const urls: string[] = [];
  // Home + Blog index
  urls.push(new URL('/', site).toString());
  urls.push(new URL('/blog/', site).toString());

  const posts = await getCollection('posts', ({ data }) => !data.draft);
  for (const p of posts) {
    urls.push(new URL(`/blog/${p.slug}/`, site).toString());
  }

  // Category listings + category RSS
  for (const cat of ALLOWED_CATEGORIES) {
    urls.push(new URL(`/blog/category/${cat}/`, site).toString());
    urls.push(new URL(`/blog/category/${cat}/rss.xml`, site).toString());
  }

  // Tag listings + tag RSS
  for (const tag of ALLOWED_TAGS) {
    urls.push(new URL(`/blog/tag/${tag}/`, site).toString());
    urls.push(new URL(`/blog/tag/${tag}/rss.xml`, site).toString());
  }

  // Main RSS
  urls.push(new URL('/rss.xml', site).toString());

  const xml = `<?xml version="1.0" encoding="UTF-8"?>
<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">
  ${urls.map(u => `<url><loc>${u}</loc></url>`).join('\n  ')}
</urlset>`;

  return new Response(xml, {
    headers: { 'Content-Type': 'application/xml; charset=utf-8' }
  });
}
EOF
)"

# robots.txt
write_file "public/robots.txt" "$(cat <<'EOF'
User-agent: *
Allow: /

Sitemap: /sitemap.xml
EOF
)"

# Sample content
write_file "src/content/posts/welcome-to-our-blog.mdx" "$(cat <<'EOF'
---
title: Welcome to Our Blog
description: A quick tour of what you’ll find here.
publishDate: 2025-09-01
draft: false
author: Team
categories: ["news"]
tags: ["bond-cleaning"]
---

Welcome! This blog ships with a content collection, taxonomy, RSS, and a quote form baked into every post page to keep the business path front-and-center.
EOF
)"

write_file "src/content/posts/how-to-choose-a-bond-cleaner.mdx" "$(cat <<'EOF'
---
title: How to Choose a Bond Cleaner in Ipswich
description: A practical checklist for selecting a reliable end-of-lease cleaner.
publishDate: 2025-09-02
draft: false
author: Team
categories: ["guides"]
tags: ["checklists","bond-cleaning"]
---

When comparing bond cleaners, look for transparent pricing, clear scope, and a guarantee period. Bonus points for before/after photo logs and itemized receipts.
EOF
)"

# Playwright configuration + smoke test
write_file "playwright.config.ts" "$(cat <<'EOF'
import type { PlaywrightTestConfig } from '@playwright/test';

const config: PlaywrightTestConfig = {
  webServer: {
    command: 'npm run build && npm run preview',
    port: 4321,
    timeout: 120000,
    reuseExistingServer: !process.env.CI,
  },
  use: { baseURL: 'http://localhost:4321' }
};

export default config;
EOF
)"

write_file "tests/e2e.smoke.spec.ts" "$(cat <<'EOF'
import { test, expect } from '@playwright/test';

test('home loads & has quote form', async ({ page }) => {
  await page.goto('/');
  await expect(page.locator('text=Welcome')).toBeVisible();
  await expect(page.locator('form#quote')).toBeVisible();
});

test('blog index lists posts', async ({ page }) => {
  await page.goto('/blog/');
  await expect(page.locator('h1:text("Blog")')).toBeVisible();
  await expect(page.locator('a >> text=Welcome to Our Blog')).toBeVisible();
});

test('analytics shim is present', async ({ page }) => {
  await page.goto('/');
  const hasShim = await page.evaluate(() => typeof (window as any).e_send === 'function');
  expect(hasShim).toBeTruthy();
});
EOF
)"

# Sync content
npm run --silent sync || true

# Final message
log_success "Astro blog transformation complete!"
log_info "Run: npm install && npm run dev   (or: npm run test:e2e)"
