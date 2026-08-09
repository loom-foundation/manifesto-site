import type { APIRoute } from 'astro';
import { readFileSync } from 'node:fs';
import { resolve } from 'node:path';

/**
 * Serves the canonical manifesto as raw Markdown at /manifesto.md.
 *
 * The rendered page at / is for humans; this endpoint exposes the primary
 * artefact in its structured source form so search engines, bots, and AI
 * agents can read and ingest the document verbatim (frontmatter, headings,
 * and all). The file is read in place from the sibling `manifesto` repo's
 * root — the same canonical source the content collection renders — so the
 * two can never drift.
 */
const source = readFileSync(resolve(process.cwd(), '../../manifesto/manifesto.md'), 'utf-8');

export const prerender = true;

export const GET: APIRoute = () =>
  new Response(source, {
    headers: {
      'content-type': 'text/markdown; charset=utf-8',
    },
  });
