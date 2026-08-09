#!/usr/bin/env bash
# Post-merge attestation. Stamps a `verification` block into each merged Mill
# file, re-deriving the facts from the merged state, and stamps
# `manifesto-version` into every merged Mill AND Weaver file (fetched live
# from the sibling manifesto repo — see lib.sh's manifesto_version). Weavers
# get no `verification` block: the filename is the identity, git history the
# date.
# Expects env: REPO, SHA, BEFORE, GH_TOKEN. Leaves changes in the working tree
# for the workflow's commit step.
set -euo pipefail
here="$(dirname "${BASH_SOURCE[0]}")"
# shellcheck source=lib.sh
. "$here/lib.sh"

now="$(date -u +%Y-%m-%d)"
mv="$(manifesto_version)"
[ -n "$mv" ] || echo "::warning::Could not read the manifesto's version; signatures in this push will not be stamped with one."

# A field from a local (checked-out) file's frontmatter. Case preserved.
fm_field() { # $1=path  $2=field
  awk '/^---[[:space:]]*$/{n++; next} n==1' "$1" \
    | grep -iE "^$2:" | head -1 \
    | sed -E "s/^$2:[[:space:]]*//I" | tr -d "\"'\r" || true
}

# Signatory files added/modified in this push (skip deletions).
if git rev-parse --verify -q "$BEFORE^{commit}" >/dev/null 2>&1; then
  all_files="$(git diff --name-only --diff-filter=AM "$BEFORE" "$SHA" -- signatories)"
else
  all_files="$(git show --name-only --diff-filter=AM --format= "$SHA" -- signatories)"
fi
[ -n "$all_files" ] || { echo "No signatory files in this push."; exit 0; }

weaver_files="$(printf '%s\n' "$all_files" | grep -E '^signatories/weavers/.*\.md$' || true)"
while IFS= read -r path; do
  [ -n "$path" ] && [ -f "$path" ] || continue
  KIND=weaver MANIFESTO_VERSION="$mv" python3 "$here/inject-verification.py" "$path"
  echo "Stamped $path (manifesto-version=$mv)."
done <<< "$weaver_files"

files="$(printf '%s\n' "$all_files" | grep -E '^signatories/mills/.*\.md$' || true)"
[ -n "$files" ] || { echo "No Mill files in this push."; exit 0; }

# The PR that introduced this commit gives the true signer.
pr_author="$(gh api "repos/$REPO/commits/$SHA/pulls" -q '.[0].user.login' 2>/dev/null || true)"
# Issue-form Mill PRs are opened by the bot, not the signer, so the bot records
# the real signer in a machine-readable "Signed-by:" line in the PR body. Reading
# it here survives any merge method (a squash merge would otherwise drop the
# signer-authored commit).
pr_signed_by="$(gh api "repos/$REPO/commits/$SHA/pulls" -q '.[0].body' 2>/dev/null \
  | grep -iE '^Signed-by:' | head -1 | sed -E 's/^Signed-by:[[:space:]]*@?//I' | tr -d '\r' || true)"

while IFS= read -r path; do
  [ -n "$path" ] && [ -f "$path" ] || continue
  case "$path" in signatories/mills/*.md) : ;; *) continue ;; esac
  IFS=$'\t' read -r org team < <(mill_split "$path")
  sig="$(sig_id "$org" "$team")"

  # The PR author is the true signer, except for issue-form Mill PRs, which are
  # opened by the bot: for those, trust the "Signed-by:" marker the bot wrote.
  # If neither is available, this push was not PR-driven (a maintainer's
  # direct commit, a bulk migration, ...) — a bare git-log commit author is
  # not a reliable signer identity (it need not even be a GitHub handle), so
  # leave any existing verification block untouched rather than fabricate one.
  signer=""
  if [ -n "$pr_author" ] && [ "$pr_author" != "github-actions[bot]" ]; then
    signer="$pr_author"
  elif [ -n "$pr_signed_by" ]; then
    signer="$pr_signed_by"
  fi

  if [ -z "$signer" ]; then
    echo "::warning::No pull request found for $path; leaving its verification block untouched (stamping manifesto-version only)."
    KIND=mill MANIFESTO_VERSION="$mv" python3 "$here/inject-verification.py" "$path"
    echo "Stamped $path (manifesto-version=$mv, verification unchanged)."
    continue
  fi
  signer="$(lc "$signer")"

  membership="unverified"; proof=""
  if gh api "orgs/$org/public_members/$signer" --silent 2>/dev/null; then
    membership="public-member"
  else
    url="$(fm_field "$path" url)"
    [ -n "$url" ] && proof="$(control_proof "$org" "$sig" "$url")"
    [ -n "$proof" ] && membership="control-file"
  fi

  KIND=mill SIGNED_BY="$signer" ORG="$org" MEMBERSHIP="$membership" \
  VERIFIED_VIA="$proof" SIGNED="$now" MANIFESTO_VERSION="$mv" \
    python3 "$here/inject-verification.py" "$path"
  echo "Stamped $path (signer=$signer, $membership, manifesto-version=$mv)."
done <<< "$files"
