#!/usr/bin/env bash
# PR-time signature gate. Reads PR metadata and public file contents through the
# API only; it never executes the PR's code. Expects env: REPO, PR, ACTION,
# AUTHOR, HEAD_REPO, HEAD_SHA, GH_TOKEN.
set -euo pipefail
here="$(dirname "${BASH_SOURCE[0]}")"
# shellcheck source=lib.sh
. "$here/lib.sh"

author="$(lc "$AUTHOR")"
readme="https://github.com/$REPO/blob/main/signatories/README.md"
errors=()

# Signatures opened by the issue-form bot (sign-from-issue.sh) are already
# verified there: for a Weaver the issue author is the signer; for a Mill the
# insider check ran before the PR. Such PRs are authored by github-actions[bot],
# which no fork can spoof, so the fork-time "filename == author" gate below does
# not apply. (In practice a GITHUB_TOKEN-opened PR does not trigger this
# workflow at all; this guard just makes a manual re-run a no-op.)
if [ "$author" = "github-actions[bot]" ]; then
  echo "Bot-opened signature PR; pre-verified in sign-from-issue.sh."
  exit 0
fi

# A field from a PR file's frontmatter, read via the API (raw), case preserved.
fm_field() { # $1=path  $2=field
  gh api "repos/$HEAD_REPO/contents/$1?ref=$HEAD_SHA" \
      -H "Accept: application/vnd.github.raw" 2>/dev/null \
    | awk '/^---[[:space:]]*$/{n++; next} n==1' \
    | grep -iE "^$2:" | head -1 \
    | sed -E "s/^$2:[[:space:]]*//I" | tr -d "\"'\r" || true
}

# A verified insider is a public member of the org, or proves control via a file
# the org owns. Appends to `errors` when neither holds. Always returns 0.
verify_mill() { # $1=path
  local path="$1" org team sig url proof
  IFS=$'\t' read -r org team < <(mill_split "$path")
  sig="$(sig_id "$org" "$team")"
  if gh api "orgs/$org/public_members/$author" --silent 2>/dev/null; then
    return 0
  fi
  url="$(fm_field "$path" url)"
  proof=""
  [ -n "$url" ] && proof="$(control_proof "$org" "$sig" "$url")"
  if [ -z "$proof" ]; then
    errors+=("- \`$path\`: could not verify you as an insider of \`$org\`. Either make your org membership public (GitHub → Organizations → publicise), or add a file to any public \`$org\` repo containing the line \`loom-signatory: $sig\` and point \`url:\` at it.")
  fi
  return 0
}

# Walk the PR's changed files. `signatories/mills/*.md` matches both whole-org
# (mills/<org>.md) and team (mills/<org>/<team>.md) files; mill_split tells them apart.
while IFS=$'\t' read -r status path; do
  case "$path" in
    signatories/weavers/*.md)
      handle="$(lc "$(basename "$path" .md)")"
      if [ "$handle" != "$author" ]; then
        errors+=("- \`$path\`: the filename must be your own GitHub handle. You are \`$author\`, so add \`signatories/weavers/$author.md\`.")
        continue
      fi
      declared="$(lc "$(fm_field "$path" github)")"
      if [ -n "$declared" ] && [ "$declared" != "$handle" ]; then
        errors+=("- \`$path\`: optional \`github: $declared\` does not match the filename \`$handle\`. Remove it or make it match.")
      fi
      ;;
    signatories/mills/*.md)
      verify_mill "$path"
      ;;
  esac
done < <(gh api "repos/$REPO/pulls/$PR/files" --paginate \
           -q '.[] | select(.status != "removed") | [.status, .filename] | @tsv')

if [ "${#errors[@]}" -gt 0 ]; then
  body="$(printf '%s\n' "${errors[@]}")"
  if [ "$ACTION" != "synchronize" ]; then
    gh pr comment "$PR" --body "**Signature check failed**"$'\n\n'"$body"$'\n\n'"See ${readme}. If none of these paths fit your case, a maintainer can review and merge manually." || true
  fi
  echo "::error::Signature validation failed"
  printf '%s\n' "${errors[@]}"
  exit 1
fi
echo "Signature checks passed."
