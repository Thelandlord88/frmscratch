import { z, defineCollection } from 'astro:content';
const blog = defineCollection({
  type: 'content',
  schema: z.object({
    title: z.string(),
    description: z.string().optional(),
    pubDate: z.date(),
    hero: z.string().optional(),
    tags: z.array(z.string()).default([]),
  })
});
export const collections = { blog };
