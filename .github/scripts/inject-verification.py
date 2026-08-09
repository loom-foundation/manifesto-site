#!/usr/bin/env python3
"""Insert (or refresh) the post-merge stamp in a signatory file.

Mills get a `verification:` block plus `manifesto-version:`. Weavers get only
`manifesto-version:` (their filename is the identity; git history is the
signing date — see signatories/README.md). Both are stamped by the
record-signatures workflow after merge and are never hand-written; all facts
arrive via the environment so this script only performs the YAML-frontmatter
surgery. Re-running is idempotent: existing stamped keys are stripped before
the fresh ones are written. A weaver file may have no frontmatter at all
(signatory files "can be empty"); one is created if there is something to
stamp into it.
"""
import os
import sys


def strip_key(block: list[str], key: str) -> list[str]:
    out, skipping = [], False
    for ln in block:
        if ln.startswith(f"{key}:"):
            skipping = True
            continue
        if skipping:
            if ln.strip() == "" or ln[:1] in (" ", "\t"):
                continue
            skipping = False
        out.append(ln)
    return out


def main() -> int:
    path = sys.argv[1]
    kind = os.environ["KIND"]  # "mill" or "weaver"
    manifesto_version = os.environ.get("MANIFESTO_VERSION", "")

    with open(path, encoding="utf-8") as fh:
        text = fh.read()
    lines = text.split("\n")

    has_frontmatter = bool(lines) and lines[0].strip() == "---"
    close = None
    if has_frontmatter:
        close = next((i for i in range(1, len(lines)) if lines[i].strip() == "---"), None)

    if has_frontmatter and close is not None:
        kept, body = lines[1:close], lines[close + 1:]
    elif kind == "weaver":
        # No frontmatter yet (an empty file is the common case); safe to add
        # one. Mills always arrive with frontmatter (name/url at creation),
        # so an unparsable Mill file is left untouched instead.
        kept, body = [], (lines if text.strip() else [])
    else:
        return 0

    kept = strip_key(kept, "manifesto-version")
    while kept and kept[-1].strip() == "":
        kept.pop()

    # Only touch the verification block when the caller actually has a
    # signer to attribute it to (record.sh omits SIGNED_BY when this push
    # wasn't PR-driven). Otherwise leave whatever is already there alone —
    # better a stale-but-correct block than a fresh, wrong one.
    signed_by = os.environ.get("SIGNED_BY", "")
    if kind == "mill" and signed_by:
        org = os.environ["ORG"]
        membership = os.environ["MEMBERSHIP"]
        verified_via = os.environ.get("VERIFIED_VIA", "")
        signed = os.environ["SIGNED"]
        kept = strip_key(kept, "verification")
        block = [
            "verification:",
            f"  signed-by: {signed_by}",
            f"  org: {org}",
            f"  org-membership: {membership}",
        ]
        if verified_via:
            block.append(f"  verified-via: {verified_via}")
        block.append(f"  signed: {signed}")
        kept += block

    if manifesto_version:
        kept.append(f'manifesto-version: "{manifesto_version}"')

    if not kept:
        # Nothing to stamp (e.g. the manifesto-version lookup failed for a
        # weaver file that otherwise had no frontmatter): leave it untouched.
        return 0

    new = ["---"] + kept + ["---"] + body
    with open(path, "w", encoding="utf-8") as fh:
        fh.write("\n".join(new))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
