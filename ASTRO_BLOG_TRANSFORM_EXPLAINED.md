# Astro Blog Transformation (Patched)

This package includes a **single, patched `astro-blog-transform.sh`** that turns a basic (or greenfield) project into a **production‑ready Astro blog** with:

- Content Collections + strict schema (Zod)
- Centralized taxonomy (categories/tags)
- Blog index, single post pages, **category & tag listing pages**
- **Main RSS + category RSS + tag RSS**
- **Business conversion path**: `QuoteForm.astro` + analytics shim
- **Analytics endpoint** at `/api/e` (no 404 beacons)
- **AEST‑friendly dates** on UI
- **Sitemap + robots.txt**
- **Playwright guardrails** (home/blog load, analytics shim present)
- Idempotent‑leaning behavior (file backups on overwrite)
- `@/` alias support in **tsconfig** for IDE harmony
- `astro.config.mjs` written with **site** set to your URL

---

## Why these patches matter

### 1) `@astrojs/rss` + `public/`
RSS feed files require the RSS package and a public directory. The script ensures both exist so **feeds work on first run**.

### 2) Analytics Endpoint
The analytics shim posts to `/api/e`. Without this endpoint, your tests (and beacon) would **404**. We add a minimal `204 No Content` handler so **guardrails stay green** while you wire real analytics later.

### 3) Category/Tag Listings + Tag RSS
Your blueprint promised them; now they actually exist. Both **listing pages** and **feeds** are generated from the centralized taxonomy for **SEO coverage + UX discoverability**.

### 4) Home Page
Some tests and beacons expect `/` to render and load the shim. We add a **minimal home** that links to the blog and includes the quote form.

### 5) `@/` TS Alias
We align **Vite-style imports** with TypeScript so your editor and type-checkers agree (`@/*` → `src/*`).

### 6) Backups on Overwrite
We preserve prior edits via `.bak` files whenever we write a new one—safer reruns and easier rollbacks.

### 7) AEST-friendly Dates
Dates on blog UI render in `Australia/Brisbane`, preventing timezone off-by-one surprises in AU contexts.

### 8) Sitemap Completeness
Home, blog, individual posts, **category/tag listings**, and **all RSS endpoints** are included so search engines have **complete discovery**.

---

## What the script does step-by-step

1. **Preflight & deps**  
   Initializes a Node project if needed; installs `@astrojs/rss`, `typescript`, `@types/node`, and `@playwright/test`.

2. **Business data (NAP)**  
   Prompts you (or reads env vars) and writes `src/data/business.json` as the **single source of truth**.

3. **Content Collections**  
   `src/content/config.ts` defines a strict posts schema and exports `ALLOWED_CATEGORIES`/`ALLOWED_TAGS` (also re-exported via `taxonomy.ts`).

4. **Layouts & Components**  
   `BaseLayout.astro` injects the **analytics shim** and handles canonical URLs.  
   `QuoteForm.astro` posts data via the shim and displays a “thank you” alert.

5. **Pages & Feeds**  
   - `/` home with QuoteForm  
   - `/blog/` index  
   - `/blog/[slug]/` single post (uses content collection)  
   - `/blog/category/[category]/` + RSS  
   - `/blog/tag/[tag]/` + RSS  
   - `/rss.xml` (main feed)  
   - `/sitemap.xml` and `/robots.txt`

6. **Testing Guardrails**  
   Playwright config spins up a built preview; smoke tests verify **home**, **blog**, and the **analytics shim** presence.

7. **DX niceties**  
   - `tsconfig.json` alias for `@/`  
   - `astro.config.mjs` with `site` set to your provided URL  
   - File backups on overwrite (`.bak`)

---

## Usage

```bash
chmod +x astro-blog-transform.sh
./astro-blog-transform.sh
```

You’ll be prompted for business information. You can also pre-seed with env vars (useful for CI/scaffolding):

```bash
BUSINESS_NAME="One N Done Bond Clean" \
BUSINESS_LEGAL_NAME="One N Done Bond Clean" \
BUSINESS_PHONE="+61 400 000 000" \
BUSINESS_EMAIL="hello@example.com" \
BUSINESS_URL="https://example.com" \
BUSINESS_STREET="123 Sample St" \
BUSINESS_LOCALITY="Ipswich" \
BUSINESS_REGION="QLD" \
BUSINESS_POSTCODE="4305" \
BUSINESS_COUNTRY="AU" \
BUSINESS_ABN="" \
BUSINESS_HOURS="Mo-Fr 08:00-18:00" \
./astro-blog-transform.sh
```

Then:

```bash
npm install
npm run dev
# or
npm run test:e2e
```

---

## Extending

- **Analytics**: replace the `/api/e` handler with your real logging/analytics broker.  
- **Design System**: drop in Tailwind or your preferred CSS framework; the markup is classable.  
- **More Schemas**: add content collections for authors, products, FAQs, etc.  
- **CI**: wire this into a template repo or a “Create App” flow for repeatable scaffolding.

---

## Notes

- The script **backs up** any overwritten files as `*.bak`.  
- If you already have `astro.config.mjs`, it will be **backed up** then replaced to ensure `site` is set. Merge by hand if you have integrations.  
- The included sample posts live at `src/content/posts/` and are set `draft: false` so they appear immediately.
