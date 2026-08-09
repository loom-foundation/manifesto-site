# Signing The Loom Manifesto

Sign by opening a pull request that adds one file. Every signature is a small, inspectable artefact: a file anyone can read, merged through a review anyone can follow. You are not filling in a form; you are making a public commitment.

Two tiers:

```
signatories/
  weavers/<github-handle>.md    # individuals
  mills/<org>/<team>.md         # a team within an organisation
  mills/<org>.md                # an organisation as a whole
```

## The easiest way: the manifesto site

On <https://theloommanifesto.org> the sign buttons do the work for you. Each opens a short **issue form** on this repository from your own GitHub account: no fork, no clone, no file editing.

- **Sign the manifesto** opens the Weaver form. Both fields are optional; submit it and a bot opens and merges your one-line file for you.
- **Sign as a team or organisation** opens the Mill form. A bot runs the insider check and opens a pull request for a maintainer to merge.

Signing from your own account is the verification: the hand that submits is the hand that owns the account. If you would rather sign by hand as a pull request (the path for technical signers), or want the detail, the two sections below explain each tier.

## Weaver (individual)

Your signature is the filename, and signing from your own account is the whole check.

1. Add `weavers/<your-github-handle>.md` from your own GitHub account. The file can be empty.
2. Open the pull request. The bot confirms the filename is your handle and merges.

Your name, avatar, and profile link come from your handle, so there is nothing to fill in. To show a display name other than your handle (it still links to your profile), add one line:

```yaml
---
name: Ada Lovelace
---
```

## Mill (team or organisation)

Sign on behalf of a group. The path is the signature, and `<org>` is your GitHub org handle, the verifiable part.

1. Add the file from your own account, choosing the shape that fits:
   - a team within the org: `mills/<org>/<team>.md`
   - the whole organisation: `mills/<org>.md`

   The file can be empty; the org comes from the path. Add a `name:` line only if you want a display label other than the slug.
2. Open the pull request.

We verify that you are a real insider of the org; the team name is yours to assert. Two teams in different orgs never clash, because the org handle is unique, and one org can hold many teams.

**If you are a public member of the org**, that is the whole check. The bot confirms it and merges.

**If your membership is private**, either publicise it (GitHub → Organizations → publicise, one click) and you are done, or prove control another way. Add a file to any public repo your org owns, containing this line:

```
loom-signatory: <org>/<team>     # for a team; use just <org> for a whole-org signature
```

then point `url:` at that file:

```yaml
---
url: https://github.com/<org>/<repo>/blob/main/loom-manifesto.md
---
```

The bot checks the file lives in a repo owned by `<org>` and names your signature, which only someone with write access to that org could arrange. No org-admin rights, no `.github` repo needed; any public repo you can write to works.

If neither path fits, a maintainer can review and merge manually.

## Recorded automatically

Every signature, once merged, is stamped with the `manifesto-version` it was signed against — read live from the manifesto's own `version` frontmatter in the sibling [`manifesto`](https://github.com/loom-foundation/manifesto) repo. Don't write this yourself; it is rewritten on every merge.

```yaml
manifesto-version: "1.0"
```

Weavers get nothing else: the filename is the identity, git history is the date. On a Mill, the bot additionally writes a `verification` block:

```yaml
verification:
  signed-by: octocat            # the org insider who opened the pull request
  org: acme
  org-membership: public-member # or: control-file
  verified-via: https://github.com/acme/repo/blob/<sha>/loom-manifesto.md  # private path only
  signed: 2026-07-02
```

This keeps the roster provable: it records which insider signed on behalf of the org and how they were verified, so the record stands even if that person later leaves, and which text of the manifesto they stood behind even as it evolves.

## The one rule

Don't sign for someone who didn't ask you to. A Weaver signature must come from the account it names; a Mill signature must come from a verified insider of the org. Impersonation gets a pull request closed on sight.
