#!/usr/bin/env bash
set -euo pipefail

STATE_FILE=".github/upstream_state.json"
PROMOTE_BRANCH="promote/nightly-release"

mkdir -p .github

if [ ! -f "$STATE_FILE" ]; then
  echo '{"lc_sha":"","ss_sha":"","lc_tag":"","ss_tag":"","updated_at":""}' > "$STATE_FILE"
fi

get_json() {
  local url="$1"
  curl -fsSL \
    -H "Accept: application/vnd.github+json" \
    -H "Authorization: Bearer ${GITHUB_TOKEN:-}" \
    "$url"
}

# 1) Read last upstream state
LAST_LC_SHA=$(python3 - <<'PY'
import json
p=".github/upstream_state.json"
try:
    data=json.load(open(p))
    print(data.get("lc_sha",""))
except Exception:
    print("")
PY
)

LAST_UPDATED=$(python3 - <<'PY'
import json
p=".github/upstream_state.json"
try:
    data=json.load(open(p))
    print(data.get("updated_at",""))
except Exception:
    print("")
PY
)

# 2) Detect current latest LC nightly and current branch SHA
LC_NIGHTLY_JSON=$(get_json "https://api.github.com/repos/LiveContainer/LiveContainer/releases/tags/nightly" || true)
LC_TAG=$(echo "$LC_NIGHTLY_JSON" | python3 -c 'import sys, json; d=json.load(sys.stdin); print(d.get("tag_name",""))' 2>/dev/null || true)
LC_SHA=$(echo "$LC_NIGHTLY_JSON" | python3 -c 'import sys, json; d=json.load(sys.stdin); print(d.get("target_commitish",""))' 2>/dev/null || true)

if [ -z "$LC_SHA" ] || [ "$LC_SHA" = "null" ]; then
  LC_SHA=$(git ls-remote https://github.com/LiveContainer/LiveContainer.git refs/heads/main | awk '{print $1}' || true)
fi

if [ -z "$LC_SHA" ] || [ -z "$LAST_UPDATED" ]; then
  echo "No upstream state or no LC SHA found; skip promotion."
  exit 0
fi

# 3) If last update was less than 24h ago, do not promote.
NOW_EPOCH=$(date -u +%s)
UPDATED_EPOCH=$(date -u -d "$LAST_UPDATED" +%s 2>/dev/null || echo "$NOW_EPOCH")
AGE_SECONDS=$((NOW_EPOCH - UPDATED_EPOCH))

if [ "$AGE_SECONDS" -lt 86400 ]; then
  echo "Nightly was updated less than 24h ago; skip promotion."
  exit 0
fi

# 4) Also avoid promotion if there is a newer LC change than the state you already synced.
if [ -n "$LAST_LC_SHA" ] && [ "$LC_SHA" != "$LAST_LC_SHA" ]; then
  echo "A newer upstream change exists; defer release promotion until it settles."
  exit 0
fi

# 5) Create a promotion branch from main
git checkout -b "$PROMOTE_BRANCH" || git checkout "$PROMOTE_BRANCH"

# 6) Write release metadata (example)
cat > .github/release_policy.json <<EOF
{
  "channel": "release",
  "source": "nightly",
  "promoted_at": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")",
  "livecontainer_tag": "${LC_TAG:-n/a}",
  "livecontainer_sha": "${LC_SHA:-n/a}"
}
EOF

git add .github/release_policy.json
git commit -m "chore: promote nightly to release" || true

git push origin "$PROMOTE_BRANCH" --set-upstream || true

PR_TITLE="chore: promote nightly to release"
PR_BODY=$(cat <<EOF
## Promote nightly to release

This PR marks the currently synced nightly state as the release state after 24h stability window.

- LiveContainer tag: ${LC_TAG:-n/a}
- LiveContainer SHA: ${LC_SHA:-n/a}
- Promoted at: $(date -u +"%Y-%m-%dT%H:%M:%SZ")
- Policy: no overwrite of Extended patches
- No prerelease SideStore is used for this promotion
EOF
)

gh pr create \
  --base main \
  --head "$PROMOTE_BRANCH" \
  --title "$PR_TITLE" \
  --body "$PR_BODY" \
  --fill || true