#!/usr/bin/env bash
# reset-interrupted.sh — recover from a ralph loop that was killed mid-iteration.
#
# Problem: ralph.sh was interrupted (container died, timeout, Ctrl-C) while an
# issue was in-progress. The issue file now has Status: in-progress but the
# corresponding [#NNN] commit was never made. On the next ralph run, that issue
# is skipped (not "open"), creating a zombie issue that blocks forever.
#
# This script detects that state and resets the issue back to open so ralph
# can pick it up cleanly on the next run.
#
# Usage (from project root, on host or inside the sandbox):
#   bash .claude/skills/ralph-implement/reset-interrupted.sh [--dry-run]
#
# What it does:
#   1. Find issues/*.md with Status: in-progress
#   2. For each, check if a "[#NNN]" commit exists in git log
#   3. If no commit found → reset Status back to "open" and clear .ralph state
#   4. If a commit IS found → the issue was committed; something else is wrong.
#      Print a warning and leave it alone.
#
# Exit codes:
#   0  clean (nothing to do, or reset succeeded)
#   1  git not available or issues/ not found
#   2  --dry-run mode (printed what would happen, made no changes)

set -euo pipefail

DRY_RUN=0
for arg in "$@"; do
  [[ "$arg" == "--dry-run" ]] && DRY_RUN=1
done

if ! command -v git &>/dev/null; then
  echo "[reset-interrupted] ERROR: git not found" >&2
  exit 1
fi

if [[ ! -d "issues" ]]; then
  echo "[reset-interrupted] No issues/ directory found — nothing to do." >&2
  exit 1
fi

found=0
reset_count=0

for f in issues/*.md; do
  [[ -f "$f" ]] || continue
  status=$(grep -i '^\*\*Status:\*\*' "$f" 2>/dev/null | head -1 | sed 's/.*\*\*Status:\*\*[[:space:]]*//' | tr -d '[:space:]') || true
  [[ "$status" == "in-progress" ]] || continue

  found=$((found + 1))

  # Extract issue number from filename (issues/NNN-slug.md)
  num=$(basename "$f" | grep -oE '^[0-9]+') || true
  if [[ -z "$num" ]]; then
    echo "[reset-interrupted] WARN: could not parse issue number from $f, skipping" >&2
    continue
  fi

  # Check if an implementation commit exists for this issue
  commit=$(git log --oneline --all 2>/dev/null | grep -E "^\S+ \[#${num}\]" | head -1) || true

  if [[ -n "$commit" ]]; then
    echo "[reset-interrupted] WARN: $f is in-progress AND has a commit ($commit)."
    echo "  This may mean the issue was committed but Status was never updated."
    echo "  Inspect manually — not resetting."
    continue
  fi

  echo "[reset-interrupted] Found zombie: $f (in-progress, no commit)"
  if [[ "$DRY_RUN" -eq 1 ]]; then
    echo "  DRY-RUN: would reset Status to open"
  else
    # Reset Status: in-progress → open using a portable sed replacement
    if [[ "$(uname)" == "Darwin" ]]; then
      sed -i '' 's/\*\*Status:\*\* in-progress/**Status:** open/' "$f"
    else
      sed -i 's/\*\*Status:\*\* in-progress/**Status:** open/' "$f"
    fi
    echo "  Reset to open: $f"
    reset_count=$((reset_count + 1))
  fi
done

if [[ "$found" -eq 0 ]]; then
  echo "[reset-interrupted] No in-progress issues found — nothing to reset."
  exit 0
fi

# Clear .ralph loop state so the next ralph.sh starts fresh
if [[ "$DRY_RUN" -eq 0 ]] && [[ "$reset_count" -gt 0 ]]; then
  if [[ -f ".ralph/status" ]]; then
    rm -f ".ralph/status"
    echo "[reset-interrupted] Cleared .ralph/status"
  fi
  if [[ -f ".ralph/current-issue" ]]; then
    rm -f ".ralph/current-issue"
    echo "[reset-interrupted] Cleared .ralph/current-issue"
  fi
  echo "[reset-interrupted] Done. $reset_count issue(s) reset to open. Run ralph.sh to resume."
elif [[ "$DRY_RUN" -eq 1 ]]; then
  exit 2
fi
