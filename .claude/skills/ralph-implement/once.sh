#!/usr/bin/env bash
# once.sh — run one iteration of the ralph-implement loop.
#
# Human-in-the-loop / debugging variant of the ralph loop: synchronous,
# single iteration, output streamed to terminal so you can watch the agent
# and tune the prompt before scaling up to ralph.sh (the unattended
# Docker loop).
#
# What it does:
#   1. Builds a prompt that points Claude at the ralph-implement skill.
#   2. Embeds the last 5 commits and every issues/*.md file in the prompt.
#   3. Pipes the prompt to `claude -p --permission-mode acceptEdits` and
#      tees the streamed output to .ralph/last-iteration.log.
#
# Exit codes:
#   0   claude exited 0
#   2   pre-flight failure (no issues/ dir, no issue files)
#   *   forwarded from claude
#
# Env vars:
#   RALPH_DRY_RUN=1   skip the claude invocation, print the prompt only
#   ISSUES_DIR        override default 'issues'

set -euo pipefail

ISSUES_DIR="${ISSUES_DIR:-issues}"
STATUS_DIR=".ralph"
LOG_FILE="${STATUS_DIR}/last-iteration.log"

# --- Pre-flight ---
if [[ ! -d "$ISSUES_DIR" ]]; then
  echo "[once.sh] FATAL: $ISSUES_DIR/ not found in $(pwd)" >&2
  exit 2
fi

shopt -s nullglob
issue_files=("$ISSUES_DIR"/*.md)
if (( ${#issue_files[@]} == 0 )); then
  echo "[once.sh] FATAL: no *.md files in $ISSUES_DIR/" >&2
  exit 2
fi

mkdir -p "$STATUS_DIR"

# --- Build prompt ---
recent_commits="$(git log --oneline -n 5 2>/dev/null || echo '<no git history>')"

issues_section=""
for f in "${issue_files[@]}"; do
  issues_section+=$'\n=== '"$f"$' ===\n'
  issues_section+="$(cat "$f")"
  issues_section+=$'\n'
done

PROMPT=$(cat <<EOF
You are running one iteration of the ralph-implement loop.

Read \`.claude/skills/ralph-implement/SKILL.md\` and follow it exactly. The
skill governs issue selection, implementation, self-verification, commit,
and the \`.ralph/status\` write at the end. Do not paraphrase its rules.

When the skill instructs you to pull \`tdd-red-green-refactor\`, read
\`.claude/skills/tdd-red-green-refactor/SKILL.md\` and follow it.

=== Recent commits (last 5) ===
$recent_commits

=== Open backlog (issues/*.md) ===
$issues_section

Begin one iteration now. End your turn after writing \`.ralph/status\`.
EOF
)

# --- Dry run ---
if [[ "${RALPH_DRY_RUN:-0}" == "1" ]]; then
  echo "[once.sh] RALPH_DRY_RUN=1 — printing prompt only:"
  echo "----- PROMPT BEGIN -----"
  printf '%s\n' "$PROMPT"
  echo "----- PROMPT END -----"
  exit 0
fi

# --- Invoke claude ---
# Pipe the prompt via a temp file so we don't hit argv length limits on
# large backlogs and so PIPESTATUS[1] is unambiguously claude's rc.
PROMPT_FILE="$(mktemp)"
trap 'rm -f "$PROMPT_FILE"' EXIT
printf '%s' "$PROMPT" > "$PROMPT_FILE"

echo "[once.sh] starting claude -p at $(date -Iseconds)" | tee -a "$LOG_FILE"
set +e
# shellcheck disable=SC2002
cat "$PROMPT_FILE" | claude -p --permission-mode acceptEdits 2>&1 | tee -a "$LOG_FILE"
rc=${PIPESTATUS[1]}
set -e
echo "[once.sh] claude exit=$rc at $(date -Iseconds)" | tee -a "$LOG_FILE"

exit "$rc"
