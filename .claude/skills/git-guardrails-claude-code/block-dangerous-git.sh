#!/usr/bin/env bash
# block-dangerous-git.sh
# Claude Code PreToolUse hook — blocks destructive git commands.
# Adapted from mattpocock/skills/scripts/block-dangerous-git.sh
#
# Usage (called automatically by Claude Code via settings.json hooks):
#   echo '{"tool_input":{"command":"git push origin main"}}' | ./block-dangerous-git.sh
#
# Exit codes:
#   0 — command is safe, allow it
#   2 — command is BLOCKED, Claude sees the stderr message and cannot proceed

set -euo pipefail

# Read JSON from stdin
INPUT="$(cat)"

# Extract the command field
COMMAND="$(echo "$INPUT" | python3 -c "
import sys, json
data = json.load(sys.stdin)
# Handle both top-level and nested tool_input
cmd = data.get('tool_input', data).get('command', '')
print(cmd)
" 2>/dev/null || echo "")"

if [ -z "$COMMAND" ]; then
  exit 0  # Not a Bash tool call we can parse — allow
fi

# -----------------------------------------------------------------
# Blocked patterns
# Add or remove patterns here after running git-guardrails-claude-code skill.
# -----------------------------------------------------------------
block() {
  local reason="$1"
  echo "[GIT GUARDRAIL] BLOCKED: $reason" >&2
  echo "" >&2
  echo "Command attempted: $COMMAND" >&2
  echo "" >&2
  echo "This command is blocked in Claude Code sessions to prevent accidental" >&2
  echo "destructive git operations. If you genuinely need to run this, do it" >&2
  echo "manually in your own terminal." >&2
  exit 2
}

# git push (all variants)
if echo "$COMMAND" | grep -qE '(^|[;&|]\s*|`\s*)git\s+push(\s|$)'; then
  block "git push is not allowed — push manually if intentional"
fi

# git reset --hard
if echo "$COMMAND" | grep -qE 'git\s+reset\s+.*--hard'; then
  block "git reset --hard destroys uncommitted work"
fi

# git clean (with force flag)
if echo "$COMMAND" | grep -qE 'git\s+clean\s+.*-[fdx]*f[fdx]*'; then
  block "git clean -f removes untracked files permanently"
fi

# git branch -D (force delete)
if echo "$COMMAND" | grep -qE 'git\s+branch\s+.*-D'; then
  block "git branch -D force-deletes branches — use -d (safe delete) instead"
fi

# git checkout . (discard all working tree changes)
if echo "$COMMAND" | grep -qE "git\s+checkout\s+\."; then
  block "git checkout . discards all uncommitted changes"
fi

# git restore . (discard all working tree changes)
if echo "$COMMAND" | grep -qE "git\s+restore\s+\."; then
  block "git restore . discards all uncommitted changes"
fi

# git rebase --onto (destructive history rewrite)
if echo "$COMMAND" | grep -qE 'git\s+rebase\s+.*--onto'; then
  block "git rebase --onto rewrites history — do this manually if intentional"
fi

# All clear — allow the command
exit 0
