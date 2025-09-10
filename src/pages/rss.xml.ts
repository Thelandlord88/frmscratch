import type { APIContext } from 'astro';
import rss from '@astrojs/rss';
import { getCollection } from 'astro:content';

export async function GET(context: APIContext) {
  const posts = await getCollection('blog');
  return rss({
    title: 'One N Done Blog',
    description: 'Cleaning tips and local news',
    site: context.site?.toString() || 'https://example.com',
    items: posts.map(p => ({ title: p.data.title, pubDate: p.data.pubDate, link: `/blog/${p.slug}/` })),
  });
}
