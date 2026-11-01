#!/usr/bin/env bash
# Promote the "nightly" prerelease to a public (non-prerelease) GitHub Release.
set -euo pipefail

export GH_TOKEN="${GH_TOKEN:-${GITHUB_TOKEN:-}}"
if [ -z "${GH_TOKEN}" ]; then
  echo "ERROR: GITHUB_TOKEN / GH_TOKEN is empty"
  exit 1
fi

# Prefer GH_TOKEN for gh (no interactive auth)
export GH_PROMPT_DISABLED=1
export GH_NO_UPDATE=1

REPO="${GITHUB_REPOSITORY:-}"
if [ -z "$REPO" ]; then
  REPO=$(gh repo view --json nameWithOwner -q .nameWithOwner 2>/dev/null || true)
fi
if [ -z "$REPO" ]; then
  echo "ERROR: cannot determine repository"
  exit 1
fi

echo "==> Repository: $REPO"
gh auth status 2>/dev/null || true

NIGHTLY_TAG="${NIGHTLY_TAG:-nightly}"

if ! gh release view "$NIGHTLY_TAG" --repo "$REPO" >/dev/null 2>&1; then
  echo "No '$NIGHTLY_TAG' release found — nothing to promote. Exiting 0."
  exit 0
fi

echo "==> Found nightly release"
gh release view "$NIGHTLY_TAG" --repo "$REPO"

# Resolve version for public tag
VERSION=""
if [ -f VERSION ]; then
  VERSION=$(tr -d '[:space:]' < VERSION || true)
fi
if [ -z "$VERSION" ]; then
  VERSION=$(gh release view "$NIGHTLY_TAG" --repo "$REPO" --json name,tagName --jq '.name // .tagName' | head -1 | tr -d '[:space:]' || true)
fi
# sanitize to semver-ish tag
VERSION=$(echo "$VERSION" | sed -E 's/^v//; s/[^0-9A-Za-z.+_-]/-/g')
if [ -z "$VERSION" ] || [ "$VERSION" = "nightly" ]; then
  VERSION="4.2.7-$(date -u +%Y%m%d)"
fi
PUBLIC_TAG="v${VERSION}"

# Avoid clobbering an existing public release unless FORCE=1
if gh release view "$PUBLIC_TAG" --repo "$REPO" >/dev/null 2>&1; then
  if [ "${FORCE_PROMOTE:-0}" != "1" ]; then
    echo "Public release $PUBLIC_TAG already exists. Set FORCE_PROMOTE=1 to recreate assets."
    exit 0
  fi
  echo "FORCE_PROMOTE=1 — will re-upload assets onto $PUBLIC_TAG"
fi

WORKDIR=$(mktemp -d)
trap 'rm -rf "$WORKDIR"' EXIT
cd "$WORKDIR"

echo "==> Downloading assets from $NIGHTLY_TAG"
gh release download "$NIGHTLY_TAG" --repo "$REPO" --dir . || {
  echo "WARNING: no downloadable assets on nightly"
}

shopt -s nullglob
ASSETS=( *.ipa *.zip *.dmg *.txt *.json *.md )
if [ ${#ASSETS[@]} -eq 0 ]; then
  echo "No assets found on nightly — creating notes-only public release"
fi

NOTES_FILE="$WORKDIR/notes.md"
{
  echo "## Public release promoted from nightly"
  echo ""
  echo "- Source tag: \`$NIGHTLY_TAG\`"
  echo "- Public tag: \`$PUBLIC_TAG\`"
  echo "- Promoted at: $(date -u +"%Y-%m-%dT%H:%M:%SZ")"
  echo ""
  echo "### Assets"
  if [ ${#ASSETS[@]} -eq 0 ]; then
    echo "- (none attached)"
  else
    for a in "${ASSETS[@]}"; do echo "- \`$a\`"; done
  fi
  echo ""
  echo "> Promoted automatically by **Promote Nightly → Public Release** workflow."
} > "$NOTES_FILE"

TITLE="LiveContainer Extended ${VERSION}"

if gh release view "$PUBLIC_TAG" --repo "$REPO" >/dev/null 2>&1; then
  gh release edit "$PUBLIC_TAG" --repo "$REPO" \
    --title "$TITLE" \
    --notes-file "$NOTES_FILE" \
    --latest \
    --prerelease=false
  if [ ${#ASSETS[@]} -gt 0 ]; then
    gh release upload "$PUBLIC_TAG" --repo "$REPO" --clobber "${ASSETS[@]}"
  fi
else
  if [ ${#ASSETS[@]} -gt 0 ]; then
    gh release create "$PUBLIC_TAG" --repo "$REPO" \
      --title "$TITLE" \
      --notes-file "$NOTES_FILE" \
      --latest \
      "${ASSETS[@]}"
  else
    gh release create "$PUBLIC_TAG" --repo "$REPO" \
      --title "$TITLE" \
      --notes-file "$NOTES_FILE" \
      --latest
  fi
fi

echo "==> Promoted $NIGHTLY_TAG → $PUBLIC_TAG"
gh release view "$PUBLIC_TAG" --repo "$REPO"
