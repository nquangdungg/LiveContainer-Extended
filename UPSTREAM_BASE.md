# Upstream base tracking (LiveContainer Extended)

This fork is based on **LiveContainer nightly**, not necessarily the latest *stable* GitHub Release.

## Why this matters

- `LiveContainer/LiveContainer` **stable** (`releases/latest`) can lag behind **nightly**.
- Extended patches (UI, GuestHooks, StatusBar, workflows) were applied on top of a **nightly-era** tree.
- Merging an *older* stable tag into this repo can **downgrade** core LC code while keeping Extended UI → broken or regressive builds.

## Rules

1. **Never** merge only because `releases/latest` has a new marketing tag.
2. Prefer integrating **`upstream/main`** (or the branch nightly builds from) by **commit date / SHA**, not tag name alone.
3. Before merge, compare:
   - `UPSTREAM_SHA` below (last integrated upstream tip)
   - current `upstream/main` SHA
4. If upstream tip is **behind** our recorded SHA → **do not merge** (would go backwards).
5. SideStore IPA is independent: rebuild to pick newer `SideStore.ipa` without merging LC at all.

## Record (update after each successful upstream integration)

```
UPSTREAM_REMOTE=https://github.com/LiveContainer/LiveContainer.git
UPSTREAM_REF=main
UPSTREAM_SHA=unknown
UPSTREAM_DATE=unknown
NOTES=Initial Extended tree from LiveContainer-nightly source package
```

After a good merge, replace `UPSTREAM_SHA` / `UPSTREAM_DATE` with:

```bash
git fetch upstream
git rev-parse upstream/main
git log -1 --format=%ci upstream/main
```
