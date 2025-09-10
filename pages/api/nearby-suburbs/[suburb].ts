import type { APIRoute } from 'astro';
export const prerender = false; // dynamic API route served at runtime
import snapshot from '~/content/_generated/proximity.json';
import { findSuburbBySlug } from '~/lib/clusters';

export const GET: APIRoute = ({ params, url, request }) => {
  const slug = (params.suburb || '').toLowerCase();
  const suburb = findSuburbBySlug(slug);
  if (!suburb) return new Response(JSON.stringify({ error: 'Unknown suburb' }), { status: 404 });

  const limit = Math.max(1, Math.min(12, parseInt(url.searchParams.get('limit') || '6', 10)));
  const etag = '"' + (snapshot as any).etag + '"';
  if (request.headers.get('if-none-match') === etag) return new Response(null, { status: 304 });

  const list = ((snapshot as any).nearby?.[slug] || []).slice(0, limit);
  return new Response(JSON.stringify({ suburb, nearby: list }, null, 2), {
    headers: {
      'Content-Type': 'application/json',
      'Cache-Control': 'public, max-age=60, stale-while-revalidate=300',
      ETag: etag
    }
  });
};
