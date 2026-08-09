# The Loom Manifesto — site

*When machines build at speed, clarity becomes the craft.*

The Astro site that publishes [the manifesto](https://github.com/loom-foundation/manifesto) at <https://theloommanifesto.org>, and the roster of those who have signed it.

## Contents

| Path            | What                                                                          |
| --------------- | ---------------------------------------------------------------------------- |
| `site/`         | The Astro site that renders the manifesto and the roster.                     |
| `signatories/`  | The roster: Weavers (individuals) and Mills (teams). See its README to sign.  |

The manifesto text itself lives in the sibling [`loom-foundation/manifesto`](https://github.com/loom-foundation/manifesto) repo; this site reads it in place rather than copying it, so the two can never drift.

## Signing

Anyone can sign by opening a pull request: see [`signatories/README.md`](signatories/README.md).

## Licensing

This repository's source (`site/` and `.github/`) is licensed under the **Apache License 2.0** (see [`LICENSE`](LICENSE) and [`NOTICE`](NOTICE)), matching the rest of the Loom Foundation's code.

Signatory files under `signatories/` record a name; by opening a pull request you agree the entry may be published and retained. They are not source code and are not covered by the Apache license.

The manifesto text this site publishes is a separate work, licensed under CC BY-ND 4.0 in the `manifesto` repo.

## Running the site

The site reads sibling repositories in the west workspace (the manifesto content in `manifesto/`, brand assets in `org/`), so assemble the workspace first:

```sh
cd path/to/loom-foundation && west update
cd manifesto-site/site && npm install && npm run dev
```
