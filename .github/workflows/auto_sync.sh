#!/usr/bin/env bash
set -euo pipefail

# Auto sync script:
# - Check LiveContainer nightly (or upstream main if nightly missing)
# - Check SideStore default branch HEAD (no prerelease)
# - If new upstream content detected, create branch, merge upstream with -X ours,
#   if merge is clean: commit, push, create PR
# - If merge has conflicts: create an Issue with details and abort
# - Save last synced SHAs to .github/upstream_state.json

STATE_FILE=".github/upstream_state.json"
BRANCH_PREFIX="auto-sync"
LC_REPO="LiveContainer/LiveContainer"
SS_REPO="SideStore/SideStore"
UPSTREAM_REMOTE="upstream"
SIDESTORE_REMOTE="sidestore"

# Ensure state file exists
mkdir -p .github
if [ ! -f "$STATE_FILE" ]; then
  cat > "$STATE_FILE" <<'JSON'
{
  "lc_sha": "",
  "ss_sha": "",
  "lc_tag": "",
  "ss_tag": "",
  "updated_at": ""
}
JSON
fi

# Helpers
log() { echo "==> $*"; }
err() { echo "ERROR: $*" >&2; }

# Do authenticated API request when token present
api_get() {
  local url="$1"
  if [ -n "${GITHUB_TOKEN:-}" ]; then
    curl -fsS -H "Accept: application/vnd.github+json" -H "Authorization: Bearer ${GITHUB_TOKEN}" "$url"
  else
    curl -fsS -H "Accept: application/vnd.github+json" "$url"
  fi
}

# Get LiveContainer nightly release JSON (if exists)
get_lc_nightly_json() {
  api_get "https://api.github.com/repos/${LC_REPO}/releases/tags/nightly" || true
}

# Get SideStore default branch HEAD SHA (avoid prerelease)
get_ss_main_sha() {
  # request commits/main (assumes default branch 'main'); fallback to repo API to detect default branch if needed
  local resp
  resp=$(api_get "https://api.github.com/repos/${SS_REPO}/commits/main" 2>/dev/null || true)
  if [ -n "$resp" ]; then
    echo "$resp" | python3 -c 'import sys,json; d=json.load(sys.stdin); print(d.get("sha",""))'
    return 0
  fi
  # fallback: get repo info default_branch then get its head
  resp=$(api_get "https://api.github.com/repos/${SS_REPO}" 2>/dev/null || true)
  if [ -n "$resp" ]; then
    local branch
    branch=$(echo "$resp" | python3 -c 'import sys,json; d=json.load(sys.stdin); print(d.get("default_branch","main"))')
    resp=$(api_get "https://api.github.com/repos/${SS_REPO}/commits/${branch}" 2>/dev/null || true)
    echo "$resp" | python3 -c 'import sys,json; d=json.load(sys.stdin); print(d.get("sha",""))'
    return 0
  fi
  echo ""
}

# Read previous state values
OLD_LC_SHA=$(python3 - <<'PY'
import json
try:
  d=json.load(open('.github/upstream_state.json'))
  print(d.get('lc_sha','') or '')
except Exception:
  print('')
PY
)
OLD_SS_SHA=$(python3 - <<'PY'
import json
try:
  d=json.load(open('.github/upstream_state.json'))
  print(d.get('ss_sha','') or '')
except Exception:
  print('')
PY
)

log "Old state: LC_SHA=${OLD_LC_SHA:-n/a}, SS_SHA=${OLD_SS_SHA:-n/a}"

# Detect upstream latests
LC_RAW_JSON=$(get_lc_nightly_json)
LC_TAG=$(echo "$LC_RAW_JSON" | python3 -c 'import sys,json; d=json.load(sys.stdin) if sys.stdin.readable() else {}; print(d.get("tag_name","") if d else "")' 2>/dev/null || true)
LC_SHA=$(echo "$LC_RAW_JSON" | python3 -c 'import sys,json; d=json.load(sys.stdin) if sys.stdin.readable() else {}; print(d.get("target_commitish","") if d else "")' 2>/dev/null || true)

# If nightly release absent or doesn't provide SHA, fallback to upstream main tip
if [ -z "${LC_SHA:-}" ] || [ "$LC_SHA" = "null" ]; then
  log "No LC nightly tag or SHA found; falling back to upstream/main tip"
  LC_SHA=$(git ls-remote https://github.com/${LC_REPO}.git refs/heads/main | awk '{print $1}' || true)
  LC_TAG=""
fi

SS_SHA=$(get_ss_main_sha || true)

log "Detected upstream: LC_TAG=${LC_TAG:-n/a}, LC_SHA=${LC_SHA:-n/a}; SS_SHA=${SS_SHA:-n/a}"

# Compare to previous state
changed="false"
if [ -n "$LC_SHA" ] && [ "$LC_SHA" != "$OLD_LC_SHA" ]; then
  log "LiveContainer upstream changed or first sync (old=${OLD_LC_SHA}, new=${LC_SHA})"
  changed="true"
fi
if [ -n "$SS_SHA" ] && [ "$SS_SHA" != "$OLD_SS_SHA" ]; then
  log "SideStore upstream changed or first sync (old=${OLD_SS_SHA}, new=${SS_SHA})"
  changed="true"
fi

if [ "$changed" != "true" ]; then
  log "No upstream change detected; nothing to do."
  exit 0
fi

# Prepare branch
TIMESTAMP=$(date -u +"%Y%m%d-%H%M%S")
BRANCH_NAME="${BRANCH_PREFIX}/${TIMESTAMP}"
log "Creating branch ${BRANCH_NAME} from current main"
# Ensure we are on main
git fetch origin main:refs/remotes/origin/main || true
git checkout -B "$BRANCH_NAME" origin/main || git checkout -b "$BRANCH_NAME"

# Ensure remotes
git remote remove "$UPSTREAM_REMOTE" >/dev/null 2>&1 || true
git remote add "$UPSTREAM_REMOTE" "https://github.com/${LC_REPO}.git" >/dev/null 2>&1 || true
git remote remove "$SIDESTORE_REMOTE" >/dev/null 2>&1 || true
git remote add "$SIDESTORE_REMOTE" "https://github.com/${SS_REPO}.git" >/dev/null 2>&1 || true

git fetch "$UPSTREAM_REMOTE" --tags --force || true
git fetch "$SIDESTORE_REMOTE" --force || true

# Merge upstream main and sidestore main into this branch, preserving Extended changes by -X ours
# First merge LC upstream/main
log "Merging ${UPSTREAM_REMOTE}/main into ${BRANCH_NAME} (strategy: -X ours to preserve local patches)"
set +e
git merge --no-edit -X ours "$UPSTREAM_REMOTE/main"
merge_rc_lc=$?
set -e

# Try to merge SideStore main as well (if SS_SHA available)
if [ -n "${SS_SHA}" ]; then
  log "Merging ${SIDESTORE_REMOTE}/main into ${BRANCH_NAME} (strategy: -X ours)"
  set +e
  git merge --no-edit -X ours "$SIDESTORE_REMOTE/main"
  merge_rc_ss=$?
  set -e
else
  merge_rc_ss=0
fi

# Check for merge conflicts / problems
# git merge exits non-zero for conflicts; also check git status for unmerged paths
if ! git diff --check --quiet; then
  err "Merge produced conflicts or whitespace errors. Creating an Issue and aborting this sync."
  # Prepare issue body
  ISSUE_TITLE="Auto-sync conflict: LiveContainer/SideStore merge conflict on ${TIMESTAMP}"
  ISSUE_BODY=$(cat <<EOF
Automated sync detected a merge conflict while attempting to merge upstream changes.

Summary:
- LiveContainer tag: ${LC_TAG:-n/a}
- LiveContainer SHA: ${LC_SHA:-n/a}
- SideStore SHA: ${SS_SHA:-n/a}
- Branch attempted: ${BRANCH_NAME}
- Time (UTC): $(date -u +"%Y-%m-%dT%H:%M:%SZ")

Action taken:
- The automatic merge used strategy '-X ours' to preserve Extended's local patches.
- Because the merge resulted in conflicts or git-check issues, this sync did NOT create a PR.
- Please inspect branch '${BRANCH_NAME}' or manually fetch upstream and resolve conflicts.

Commands to reproduce locally:
  git fetch origin
  git checkout -b ${BRANCH_NAME} origin/main
  git remote add upstream https://github.com/${LC_REPO}.git
  git fetch upstream
  git merge -X ours upstream/main
  # OR inspect conflict markers and resolve manually

The automation aborted and created this issue to notify maintainers.
EOF
)

  # create an issue (best-effort)
  gh issue create --title "$ISSUE_TITLE" --body "$ISSUE_BODY" || true

  # abort merge and return to main branch
  git merge --abort >/dev/null 2>&1 || true
  git checkout main || true
  exit 0
fi

# If no changes after merge, nothing to push
if git diff --quiet --ignore-submodules; then
  log "Upstream merge resulted in no changes relative to this repo HEAD. Updating state file and exiting."
  # update state file (no branch/PR needed)
  python3 - <<PY
import json, time
p = ".github/upstream_state.json"
try:
  d = json.load(open(p))
except Exception:
  d = {}
d['lc_sha'] = "$LC_SHA"
d['ss_sha'] = "$SS_SHA"
d['lc_tag'] = "$LC_TAG"
d['ss_tag'] = ""
d['updated_at'] = "$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
open(p,"w").write(json.dumps(d, indent=2) + "\n")
PY
  exit 0
fi

# Commit merge result (if any)
log "Committing merged changes"
git add -A
git commit -m "chore: automated sync from upstream (LC/SS) at ${TIMESTAMP}" || true

# Push branch to origin
log "Pushing branch ${BRANCH_NAME} to origin"
git push --set-upstream origin "$BRANCH_NAME"

# Create PR
PR_TITLE="chore: sync upstream LiveContainer + SideStore (${TIMESTAMP})"
PR_BODY=$(cat <<EOF
Automated upstream sync PR.

- LiveContainer tag: ${LC_TAG:-n/a}
- LiveContainer SHA: ${LC_SHA:-n/a}
- SideStore SHA: ${SS_SHA:-n/a}

This PR merges upstream changes while preserving Extended local patches (merge strategy: -X ours).
If the PR needs manual conflict resolution, please resolve locally and merge.

This PR was generated automatically by the scheduled auto-sync workflow.
EOF
)

log "Creating PR"
gh pr create --base main --head "$BRANCH_NAME" --title "$PR_TITLE" --body "$PR_BODY" --fill || true

# Update state file on success
log "Updating state file with new SHAs"
python3 - <<PY
import json, time
p = ".github/upstream_state.json"
try:
  d = json.load(open(p))
except Exception:
  d = {}
d['lc_sha'] = "$LC_SHA"
d['ss_sha'] = "$SS_SHA"
d['lc_tag'] = "$LC_TAG"
d['ss_tag'] = ""
d['updated_at'] = "$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
open(p,"w").write(json.dumps(d, indent=2) + "\n")
PY

log "Auto-sync completed: PR created (if merge clean)."