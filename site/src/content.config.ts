/**
 * Content Collections — manifesto loader.
 *
 * The manifesto markdown lives in the sibling `manifesto` repo
 * (`../../manifesto/manifesto.md` relative to the site), checked out
 * alongside this repo the same way `../../org` (brand assets) is — see
 * astro.config.mjs's `vite.server.fs.allow` and the CI checkout steps.
 * It is not moved or copied here; the glob loader reads it in place.
 *
 * The collection has a single entry (`manifesto`). The page reads it
 * via `getEntry('manifesto', 'manifesto')` and renders the body inside
 * the `.manifesto` article, which the site's own global.css styles.
 */
import { defineCollection, z } from 'astro:content';
import { glob } from 'astro/loaders';

const manifesto = defineCollection({
  loader: glob({
    pattern: 'manifesto.md',
    base: '../../manifesto/',
  }),
  schema: z.object({
    title: z.string(),
    description: z.string(),
    abstract: z.string(),
    keywords: z.string(),
    version: z.string().optional(),
  }),
});

/**
 * Signatories — the roster of those who stand with the manifesto.
 *
 * The signature files live OUTSIDE the site's `src/` tree, at this repo's
 * own root under `signatories/` (unlike `manifesto.md`, they are not in the
 * sibling `manifesto` repo — signing is a site/publishing concern). They are
 * first-class artefacts contributed by pull request (one file per
 * signatory), not site source — the site is a consumer that renders them at
 * build time. The markdown is never moved or copied; the glob loader reads
 * it in place.
 *
 * Two tiers, two collections, two schemas:
 *   - `weavers` — individuals. The GitHub handle IS the filename (the entry
 *     `id`); the avatar and profile link derive from it, so identity is
 *     self-authenticating. A `github` field is optional — CI checks it
 *     matches the filename when present, but signers need not write it.
 *   - `mills` — teams / organisations. `name` and a verifiable `url` are
 *     required; these are maintainer-gated on review.
 */

/**
 * The evidence block stamped into a Mill file AFTER merge by the
 * `record-signatures` workflow. It is never hand-written; signers omit it and
 * the action strips and rewrites it on every merge. It is the durable,
 * committed record of which org insider signed, how they were verified
 * (`public-member` or `control-file`), and when. Kept optional so a file is
 * valid before the stamp lands. See .github/workflows/record-signatures.yml.
 */
const verification = z
  .object({
    'signed-by': z.string(),
    org: z.string(),
    'org-membership': z.enum(['public-member', 'control-file', 'unverified']),
    'verified-via': z.string().url().optional(),
    signed: z.coerce.date().optional(),
  })
  .optional();

// Weavers: the handle IS the filename; identity is self-authenticating, so no
// field is required. `name` is an optional display override, `github` an
// optional guard CI checks against the filename, and `role` an optional label
// shown alongside the name (defaults to "Weaver" at render time).
// `manifesto-version` is stamped by sign-from-issue.sh at merge time from the
// signed manifesto's own `version` frontmatter — never hand-written, and
// optional so pre-split signatures without it stay valid.
const weavers = defineCollection({
  loader: glob({
    pattern: '*.md',
    base: '../signatories/weavers/',
  }),
  schema: z.object({
    github: z.string().optional(),
    name: z.string().optional(),
    role: z.string().optional(),
    signed: z.coerce.date().optional(),
    'manifesto-version': z.string().optional(),
  }),
});

// Mills: the path is `mills/<org>/<team>.md`. The org (the entry `id`'s first
// segment) is the verifiable anchor and drives the logo/link; the team slug is
// a self-asserted label. `url` is only present on the private-member path,
// pointing at the org-owned control file. Nothing here is required.
// `manifesto-version` is stamped by record.sh alongside `verification`, from
// the signed manifesto's own `version` frontmatter at the time of merge.
const mills = defineCollection({
  loader: glob({
    pattern: '**/*.md',
    base: '../signatories/mills/',
  }),
  schema: z.object({
    name: z.string().optional(),
    logo: z.string().url().optional(),
    url: z.string().url().optional(),
    signed: z.coerce.date().optional(),
    'manifesto-version': z.string().optional(),
    verification,
  }),
});

export const collections = { manifesto, weavers, mills };
