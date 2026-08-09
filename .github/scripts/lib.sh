#!/usr/bin/env bash
# Shared helpers for the signatory workflows. Sourcing this has no side effects.

# The sibling repo holding the canonical manifesto text (this repo holds the
# site + the signatory roster only). Read-only API access to it needs no
# auth beyond the default token: it's public.
MANIFESTO_REPO="loom-foundation/manifesto"

# Lowercase a string (GitHub handles and org names are case-insensitive).
lc() { printf '%s' "$1" | tr '[:upper:]' '[:lower:]'; }

# The manifesto's own `version` frontmatter field, fetched live from
# $MANIFESTO_REPO. Stamped into signatory files at record time so a signature
# is provably tied to the text it was signed against, even though the two
# repos no longer share a git history. Echoes nothing on failure (never fails
# the caller).
manifesto_version() {
  gh api "repos/$MANIFESTO_REPO/contents/manifesto.md" \
      -H "Accept: application/vnd.github.raw" 2>/dev/null \
    | awk '/^---[[:space:]]*$/{n++; next} n==1' \
    | grep -iE '^version:' | head -1 \
    | sed -E 's/^version:[[:space:]]*//I' | tr -d "\"'\r" || true
}

# Split a mill path into "org<TAB>team", both lowercased.
#   signatories/mills/<org>.md         -> org, team=""      (the whole org)
#   signatories/mills/<org>/<team>.md  -> org, team
mill_split() { # $1=path
  local rel="${1#signatories/mills/}" org team
  if [[ "$rel" == */* ]]; then
    org="${rel%%/*}"
    team="$(basename "$rel" .md)"
  else
    org="$(basename "$rel" .md)"
    team=""
  fi
  printf '%s\t%s\n' "$(lc "$org")" "$(lc "$team")"
}

# The signature marker id: "<org>" for a whole org, "<org>/<team>" for a team.
sig_id() { # $1=org  $2=team
  if [ -n "$2" ]; then printf '%s/%s\n' "$1" "$2"; else printf '%s\n' "$1"; fi
}

# Prove a private member controls the org. The `url` must be a blob in a PUBLIC
# repo OWNED by <org>, containing a line `loom-signatory: <sig>`. Only someone
# with write access to that org could arrange both. Echoes the SHA-pinned proof
# URL on success, nothing on failure. Never fails the caller (returns 0).
control_proof() { # $1=org  $2=sig  $3=blob-url
  local org="$1" sig="$2" url="$3" rest owner repo kind ref path content sha
  case "$url" in
    https://github.com/*) rest="${url#https://github.com/}" ;;
    *) return 0 ;;
  esac
  owner="${rest%%/*}"; rest="${rest#*/}"
  repo="${rest%%/*}";  rest="${rest#*/}"
  kind="${rest%%/*}";  rest="${rest#*/}"
  ref="${rest%%/*}";   path="${rest#*/}"
  [ "$kind" = blob ] || return 0
  owner="$(lc "$owner")"
  [ "$owner" = "$org" ] || return 0
  content="$(gh api "repos/$owner/$repo/contents/$path?ref=$ref" \
    -H "Accept: application/vnd.github.raw" 2>/dev/null)" || return 0
  printf '%s' "$content" \
    | grep -qiE "^loom-signatory:[[:space:]]*${sig}[[:space:]]*$" || return 0
  sha="$(gh api "repos/$owner/$repo/commits/$ref" -q '.sha' 2>/dev/null || echo "$ref")"
  printf 'https://github.com/%s/%s/blob/%s/%s\n' "$owner" "$repo" "$sha" "$path"
}
