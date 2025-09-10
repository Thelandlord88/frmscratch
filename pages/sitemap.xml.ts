export const prerender = true;
import type { APIRoute } from 'astro';

import { paths } from '~/lib/paths';
import serviceCoverage from '~/data/serviceCoverage.json';
import { absoluteUrl } from '~/lib/url';

export const GET: APIRoute = async () => {
  // Ensure all URLs are absolute by using a consistent site URL
  const siteUrl = 'https://onendonebondclean.com.au';
  
  const baseUrls = [
    paths.home(),
    paths.service('bond-cleaning'),
    paths.service('spring-cleaning'),
    paths.service('bathroom-deep-clean'),
    paths.blogRoot(),
    paths.legal.privacy,
    paths.legal.terms,
    paths.legal.gallery,
    paths.legal.quote,
  ];
  
  const svcPages: string[] = [];
  for (const [svc, subs] of Object.entries(serviceCoverage as Record<string,string[]>)) {
    for (const s of subs) {
      // Ensure service pages are absolute URLs
      const relativeUrl = `/services/${svc}/${s}/`;
      svcPages.push(absoluteUrl(relativeUrl, siteUrl));
    }
  }
  
  const urls = [...baseUrls, ...svcPages];
  const body = `<?xml version="1.0" encoding="UTF-8"?>\n` +
    `<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">` +
    urls.map(u => `<url><loc>${u}</loc></url>`).join('') +
    `</urlset>`;
  return new Response(body, {
    headers: {
      'Content-Type': 'application/xml; charset=utf-8',
      'Cache-Control': 'public, max-age=300',
    },
  });
};
