#!/usr/bin/env bash
# update-fork.sh — Sync a new OpenClaw release into this fork and push to GitHub
# Usage: bash scripts/update-fork.sh /path/to/openclaw-2026.X.Y
set -euo pipefail

FORK_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
NEW_SRC="${1:-}"

# ── Validate argument ────────────────────────────────────────────────────────
if [[ -z "$NEW_SRC" || ! -d "$NEW_SRC" ]]; then
  echo "Usage: bash scripts/update-fork.sh /path/to/openclaw-NEW-VERSION"
  echo "Example: bash scripts/update-fork.sh ~/cursor/openclaw-src/openclaw-2026.4.0"
  exit 1
fi

NEW_SRC="$(cd "$NEW_SRC" && pwd)"
VERSION="$(basename "$NEW_SRC")"

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  Updating fork to: $VERSION"
echo "  Fork dir:         $FORK_DIR"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

cd "$FORK_DIR"

# ── 1. Sync new source files ──────────────────────────────────────────────────
echo ""
echo "▶ Syncing files from $VERSION ..."
rsync -av --exclude='.git' --exclude='node_modules' --exclude='.pnpm-store' \
  "$NEW_SRC/" "$FORK_DIR/" | grep -v '/$' | tail -20
echo "  Done."

# ── 2. Reinstall deps if lockfile changed ─────────────────────────────────────
if git diff --name-only 2>/dev/null | grep -q "pnpm-lock.yaml"; then
  echo ""
  echo "▶ pnpm-lock.yaml changed — reinstalling dependencies ..."
  pnpm install --frozen-lockfile
else
  echo ""
  echo "▶ pnpm-lock.yaml unchanged — skipping install."
fi

# ── 3. Rebuild a2ui bundle ───────────────────────────────────────────────────
echo ""
echo "▶ Rebuilding a2ui bundle ..."
bash "$FORK_DIR/scripts/bundle-a2ui.sh"

# ── 4. Stage all changes ──────────────────────────────────────────────────────
echo ""
echo "▶ Staging changes ..."
git add -A

CHANGED=$(git diff --cached --name-only | wc -l | tr -d ' ')
if [[ "$CHANGED" -eq 0 ]]; then
  echo "  No changes detected — already up to date."
  exit 0
fi

echo "  $CHANGED files changed."

# ── 5. Commit ─────────────────────────────────────────────────────────────────
echo ""
echo "▶ Committing ..."
git commit -m "update: $VERSION"

# ── 6. Push ───────────────────────────────────────────────────────────────────
echo ""
echo "▶ Pushing to GitHub ..."
git push

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  Done! GitHub Actions is building the image."
echo "  Check: https://github.com/prismocc-max/openclaw/actions"
echo ""
echo "  When done (~5-8 min), redeploy in Portainer:"
echo "  https://72.61.108.64:9443 → stack risqueold → Pull and redeploy"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
