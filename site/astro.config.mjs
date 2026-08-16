// @ts-check
import { defineConfig } from 'astro/config';
import { unified } from '@astrojs/markdown-remark';
import sitemap from '@astrojs/sitemap';

import { rehypeClosingAphorism } from './src/plugins/rehype-closing-aphorism.mjs';
import { remarkStripHeroImage } from './src/plugins/remark-strip-hero-image.mjs';
import { remarkStripCopyright } from './src/plugins/remark-strip-copyright.mjs';

// The canonical public site URL — used by sitemap, canonical link,
// Open Graph URL, and JSON-LD structured data.
const SITE = 'https://theloommanifesto.org';

export default defineConfig({
  site: SITE,
  trailingSlash: 'never',
  build: {
    format: 'file',
  },
  integrations: [sitemap()],
  vite: {
    server: {
      // Allow Vite to serve the site's own tree (`..` covers signatories/,
      // which live in this repo), the manifesto content in the workspace
      // ../../../manifesto repo, and the org brand artefacts in
      // ../../../org/brand (favicon, wordmarks, logo). This repo sits at
      // apps/manifesto-site in the west workspace, so workspace siblings
      // are three levels up from site/. The site does not depend on the
      // design-system package, so ../../../packages is deliberately left out
      // of the allowlist.
      fs: { allow: ['..', '../../../manifesto', '../../../org'] },
    },
  },
  markdown: {
    // Astro 7 configures remark/rehype through an explicit unified()
    // processor from @astrojs/markdown-remark. Plugins run in order: strip
    // first so injection works against the intended document shape. The
    // copyright block is lifted out of the body here and re-presented as a
    // site footer (see index.astro), so `manifesto.md` still reads as a
    // standalone document while the page ends the manifesto proper at THE
    // CALL. gfm + smartypants are kept on to preserve the document's
    // typographic rendering (curly quotes, en/em handling).
    processor: unified({
      remarkPlugins: [
        remarkStripHeroImage,
        remarkStripCopyright,
      ],
      rehypePlugins: [
        rehypeClosingAphorism,
      ],
      gfm: true,
      smartypants: true,
    }),
  },
});
