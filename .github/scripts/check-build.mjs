#!/usr/bin/env node
/**
 * Post-build gate for the release pipeline.
 *
 * Asserts that the production build in `dist/` carries the things a release
 * must never ship without: the rendered manifesto, its raw-Markdown twin, the
 * crawler/agent surface (robots, sitemap, llms), and the core SEO + structured
 * metadata. If any check fails the script exits non-zero, which fails the CI
 * job and blocks the deploy.
 *
 * Usage: node check-build.mjs <dist-dir>
 */
import { readFileSync, existsSync } from 'node:fs';
import { resolve } from 'node:path';

const dist = resolve(process.argv[2] ?? 'dist');
const failures = [];
const read = (rel) => readFileSync(resolve(dist, rel), 'utf-8');

/** Assert a file exists. */
function file(rel) {
  if (!existsSync(resolve(dist, rel))) {
    failures.push(`missing file: ${rel}`);
    return false;
  }
  return true;
}

/** Assert `haystack` contains `needle`, else record a failure. */
function contains(rel, haystack, needle, label) {
  if (!haystack.includes(needle)) {
    failures.push(`${rel}: expected ${label ?? `\`${needle}\``}`);
  }
}

// --- The two representations of the manifesto -------------------------------
if (file('index.html')) {
  const html = read('index.html');
  contains('index.html', html, '<title>The Loom Manifesto</title>', 'page title');
  contains('index.html', html, 'name="description"', 'meta description');
  contains('index.html', html, 'rel="canonical" href="https://theloommanifesto.org"', 'canonical URL');
  contains('index.html', html, 'property="og:title"', 'Open Graph title');
  contains('index.html', html, '/og-card.png', 'Open Graph preview image');
  contains('index.html', html, 'name="twitter:card"', 'Twitter card');
  contains('index.html', html, 'type="text/markdown"', 'Markdown alternate link');
  contains('index.html', html, 'application/ld+json', 'JSON-LD structured data');
  contains('index.html', html, '"@type":"CreativeWork"', 'CreativeWork schema');
  contains('index.html', html, '/manifesto.md', 'link to raw Markdown encoding');
  // The manifesto body must actually be present, not just the chrome. The
  // section headings are uppercase in the source, so this matches the
  // rendered body text (not the mixed-case JSON-LD abstract).
  contains('index.html', html, 'IN NOTE G WE BELIEVE', 'manifesto body text');
}

if (file('manifesto.md')) {
  const md = read('manifesto.md');
  contains('manifesto.md', md, 'IN NOTE G WE BELIEVE', 'manifesto source text');
}

// --- Assets + crawler / AI-agent surface -----------------------------------
file('og-card.png');
file('robots.txt');
file('llms.txt');
if (file('sitemap-index.xml')) {
  contains('sitemap-index.xml', read('sitemap-index.xml'), 'theloommanifesto.org', 'site URL in sitemap');
}

if (failures.length) {
  console.error(`✗ Build verification failed (${failures.length}):`);
  for (const f of failures) console.error(`  - ${f}`);
  process.exit(1);
}
console.log('✓ Build verification passed');
