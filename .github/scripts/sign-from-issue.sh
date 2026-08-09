#!/usr/bin/env bash
# Turn a signature Issue Form into a signature pull request, so people can sign
# without forking (GitHub's prefilled-file editor requires a fork for
# non-members, which is where the old flow failed). Reuses the shared
# verification helpers in lib.sh and the same file layout the pull-request path
# uses, so a signature made here is identical to one made by hand.
#
# Expects env: REPO, ISSUE, GH_TOKEN.
set -euo pipefail
here="$(dirname "${BASH_SOURCE[0]}")"
# shellcheck source=lib.sh
. "$here/lib.sh"

readme="https://github.com/$REPO/blob/main/signatories/README.md"

# Read the issue from the API rather than the event payload: form-applied labels
# can be absent from the `issues.opened` payload, and workflow_dispatch has no
# issue payload at all. Everything below treats this content as untrusted data.
issue_json="$(gh api "repos/$REPO/issues/$ISSUE")"
AUTHOR="$(printf '%s' "$issue_json" | jq -r '.user.login')"
BODY="$(printf '%s' "$issue_json" | jq -r '.body // ""')"
labels=" $(printf '%s' "$issue_json" | jq -r '[.labels[].name] | join(" ")') "

case "$labels" in
  *" signature "*) : ;;
  *) echo "Issue #$ISSUE is not a signature issue; nothing to do."; exit 0 ;;
esac

# --- issue-form parsing -----------------------------------------------------
# GitHub renders each form field as "### <label>\n\n<value>", using the literal
# "_No response_" for a blank optional field (markdown-only blocks are omitted).
field() { # $1 = field label
  printf '%s\n' "$BODY" \
    | awk -v want="### $1" '
        { sub(/\r$/, "") }
        index($0, "### ") == 1 { grab = ($0 == want); next }
        grab { print }
      ' \
    | grep -v '^[[:space:]]*$' \
    | head -1 \
    | sed -E 's/^[[:space:]]+//; s/[[:space:]]+$//'
}
# Field value with GitHub's blank placeholder normalised to empty.
val() { local v; v="$(field "$1")"; [ "$v" = "_No response_" ] && v=""; printf '%s' "$v"; }

# Comment on the issue and stop (input errors).
fail() { gh issue comment "$ISSUE" --repo "$REPO" --body "$1"$'\n\nSee '"${readme}"'.'; echo "::error::$1"; exit 1; }

# A GitHub handle / org / team slug: alphanumeric and hyphens only. Guards the
# untrusted org and team fields (used in file paths) against traversal and injection.
is_slug() { printf '%s' "$1" | grep -qE '^[A-Za-z0-9][A-Za-z0-9-]*$'; }

# Emit an untrusted value as a safe YAML double-quoted scalar for file content:
# strip control characters, escape backslashes and quotes. Keeps display names
# (spaces, accents, apostrophes) intact while preventing frontmatter injection.
yaml_str() {
  printf '%s' "$1" | tr -d '\000-\037' | sed -e 's/\\/\\\\/g' -e 's/"/\\"/g' \
    | awk '{ printf "\"%s\"", $0 }'
}

git config user.name  'github-actions[bot]'
git config user.email '41898282+github-actions[bot]@users.noreply.github.com'

# ---------------------------------------------------------------------------
# Weaver: the issue author IS the verified handle. Create the one-line file,
# open a PR, and merge it immediately (identity already proven). The bot PR is
# authored by github-actions[bot], which no fork can spoof; validate.sh skips
# such PRs (see its bot guard), so the fork-time gate does not fight this path.
sign_weaver() {
  local handle name path branch pr
  handle="$(lc "$AUTHOR")"
  is_slug "$handle" || fail "Could not read your GitHub handle as a valid signature name."
  name="$(val 'Display name')"
  path="signatories/weavers/${handle}.md"

  git checkout -B "sign/weaver/${handle}" main
  branch="sign/weaver/${handle}"
  {
    [ -n "$name" ] && printf -- '---\nname: %s\n---\n' "$(yaml_str "$name")"
  } > "$path"

  git add "$path"
  if git diff --cached --quiet; then
    gh issue comment "$ISSUE" --repo "$REPO" --body "You are already a signatory (\`$path\` is unchanged). Closing."
    gh issue close "$ISSUE" --repo "$REPO"
    return 0
  fi

  git commit -m "Sign the manifesto: ${handle} (Weaver)"
  git push -f origin "$branch"
  pr="$(gh pr create --repo "$REPO" --base main --head "$branch" \
        --title "Sign: ${handle} (Weaver)" --label signature --label weaver \
        --body "Weaver signature via issue #${ISSUE}. The signer is @${handle}, the issue author — the account that opened the issue is the signature, so this is pre-verified and merged automatically.")"
  gh pr merge "$pr" --repo "$REPO" --squash --delete-branch
  gh issue comment "$ISSUE" --repo "$REPO" --body "Signed. Your Weaver signature was merged in ${pr}, and appears on the site with the next daily signatories release. Thank you for standing with the manifesto."
  gh issue close "$ISSUE" --repo "$REPO"
}

# ---------------------------------------------------------------------------
# Mill: run the same insider check the PR path uses, create the file, and open a
# maintainer-gated PR (verification is noted in the body). record-signatures.yml
# stamps the verification block after a maintainer merges. The file commit is
# authored as the real signer so that stamp records the right person, not the bot.
sign_mill() {
  local org team name url signer sig path branch membership proof note pr
  org="$(lc "$(val 'Organisation')")"
  team="$(lc "$(val 'Team')")"
  name="$(val 'Display name')"
  url="$(val 'Control file URL')"
  signer="$(lc "$AUTHOR")"

  is_slug "$org" || fail "Organisation must be a GitHub org handle (letters, numbers, and hyphens only)."
  if [ -n "$team" ] && ! is_slug "$team"; then fail "Team must be a short slug (letters, numbers, and hyphens only)."; fi
  if [ -n "$url" ] && ! printf '%s' "$url" | grep -qE '^https?://[^[:space:]]+$'; then
    fail "The control file URL must be a plain http(s) link."
  fi

  sig="$(sig_id "$org" "$team")"
  if [ -n "$team" ]; then path="signatories/mills/${org}/${team}.md"; else path="signatories/mills/${org}.md"; fi
  [ -n "$name" ] || name="$org"

  # The same verification record.sh re-runs after merge: public member, else a
  # control file in a public repo the org owns.
  membership="unverified"; proof=""
  if gh api "orgs/${org}/public_members/${signer}" --silent 2>/dev/null; then
    membership="public-member"
  elif [ -n "$url" ]; then
    proof="$(control_proof "$org" "$sig" "$url")"
    [ -n "$proof" ] && membership="control-file"
  fi

  branch="sign/mill/${sig//\//-}"
  git checkout -B "$branch" main
  mkdir -p "$(dirname "$path")"
  {
    echo '---'
    printf 'name: %s\n' "$(yaml_str "$name")"
    [ -n "$url" ] && printf 'url: %s\n' "$(yaml_str "$url")"
    echo '---'
  } > "$path"

  git add "$path"
  if git diff --cached --quiet; then
    gh issue comment "$ISSUE" --repo "$REPO" --body "\`$path\` is already signed and unchanged. Closing."
    gh issue close "$ISSUE" --repo "$REPO"
    return 0
  fi

  git commit --author="${signer} <${signer}@users.noreply.github.com>" \
    -m "Sign the manifesto: ${sig} (Mill)"
  git push -f origin "$branch"

  case "$membership" in
    public-member) note="✅ Verified: @${signer} is a public member of \`${org}\`." ;;
    control-file)  note="✅ Verified via control file: ${proof}" ;;
    *)             note="⚠️ Could not verify @${signer} as an insider of \`${org}\` automatically. A maintainer will review. To self-verify, publicise your org membership or add a control file (see the README)." ;;
  esac

  pr="$(gh pr create --repo "$REPO" --base main --head "$branch" \
        --title "Sign: ${sig} (Mill)" --label signature --label mill \
        --body "Mill signature via issue #${ISSUE}, opened by @${signer}.

${note}

Merging is maintainer-gated. After merge, \`record-signatures.yml\` stamps the verification block.

Signed-by: ${signer}")"
  gh issue comment "$ISSUE" --repo "$REPO" --body "Thank you. Your Mill signature is proposed in ${pr}.

${note}

A maintainer will review and merge it; it then appears on the site with the next daily signatories release."
  gh issue close "$ISSUE" --repo "$REPO"
}

# ---------------------------------------------------------------------------
case "$labels" in
  *" weaver "*) sign_weaver ;;
  *" mill "*)   sign_mill ;;
  *) echo "Signature issue #$ISSUE has neither 'weaver' nor 'mill' label; nothing to do." ;;
esac
