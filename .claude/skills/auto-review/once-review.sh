#!/usr/bin/env bash
# once-review.sh — run one iteration of the auto-review loop.
#
# Mirrors ralph-implement/once.sh in structure, but for the review side:
#   1. Builds a prompt that points Claude at the auto-review skill.
#   2. Embeds the project's coding-standards.md (push, not pull).
#   3. Embeds recent commits + the list of existing reviews so Claude can
#      pick the next unreviewed issue.
#   4. Pipes the prompt to `claude -p --permission-mode acceptEdits` and
#      tees the streamed output to .review/last-iteration.log.
#
# Synchronous, single iteration. Safe to run on host for prompt tuning;
# the review-loop.sh wrapper enforces Docker-only for unattended use.
#
# Exit codes:
#   0   claude exited 0
#   2   pre-flight failure (missing standards file, missing reviews dir)
#   *   forwarded from claude
#
# Env vars:
#   RALPH_DRY_RUN=1   skip the claude invocation, print the prompt only
#   REVIEWS_DIR       override default 'reviews'
#   ISSUES_DIR        override default 'issues'

set -euo pipefail

REVIEWS_DIR="${REVIEWS_DIR:-reviews}"
ISSUES_DIR="${ISSUES_DIR:-issues}"
STATUS_DIR=".review"
LOG_FILE="${STATUS_DIR}/last-iteration.log"
STANDARDS_FILE=".claude/skills/auto-review/coding-standards.md"

# --- Pre-flight ---
if [[ ! -f "$STANDARDS_FILE" ]]; then
  echo "[once-review.sh] FATAL: $STANDARDS_FILE not found" >&2
  exit 2
fi
if [[ ! -d "$ISSUES_DIR" ]]; then
  echo "[once-review.sh] FATAL: $ISSUES_DIR/ not found" >&2
  exit 2
fi

mkdir -p "$REVIEWS_DIR" "$STATUS_DIR"

# --- Build prompt ---
recent_commits="$(git log --oneline -n 20 2>/dev/null || echo '<no git history>')"

shopt -s nullglob
existing_reviews=("$REVIEWS_DIR"/*.md)
if (( ${#existing_reviews[@]} == 0 )); then
  reviews_section="(no reviews yet)"
else
  reviews_section=""
  for f in "${existing_reviews[@]}"; do
    reviews_section+=$'\n- '"$(basename "$f")"
  done
fi

issues_section=""
issue_files=("$ISSUES_DIR"/*.md)
for f in "${issue_files[@]}"; do
  issues_section+=$'\n=== '"$f"$' ===\n'
  issues_section+="$(cat "$f")"
  issues_section+=$'\n'
done

standards_content="$(cat "$STANDARDS_FILE")"
standards_sha="$(sha1sum "$STANDARDS_FILE" | awk '{print $1}')"

PROMPT=$(cat <<EOF
You are running one iteration of the auto-review loop.

Read \`.claude/skills/auto-review/SKILL.md\` and follow it exactly. The
skill governs scoping, the per-issue review pass, severity classification,
verdict format, the \`reviews/NNN-*.md\` write, and the \`.review/status\`
write at the end. Do not paraphrase its rules.

The coding standards are pushed below. The skill expects you to apply
them in the standards check step. Record the sha1 in your verdict file
as \`Standards version: $standards_sha\`.

=== Coding standards (sha1: $standards_sha) ===
$standards_content
=== End coding standards ===

=== Recent commits (last 20) ===
$recent_commits

=== Existing reviews ===
$reviews_section

=== Backlog (issues/*.md, for cross-reference with commits) ===
$issues_section

Begin one iteration now. End your turn after writing \`.review/status\`.
EOF
)

# --- Dry run ---
if [[ "${RALPH_DRY_RUN:-0}" == "1" ]]; then
  echo "[once-review.sh] RALPH_DRY_RUN=1 — printing prompt only:"
  echo "----- PROMPT BEGIN -----"
  printf '%s\n' "$PROMPT"
  echo "----- PROMPT END -----"
  exit 0
fi

# --- Invoke claude ---
PROMPT_FILE="$(mktemp)"
trap 'rm -f "$PROMPT_FILE"' EXIT
printf '%s' "$PROMPT" > "$PROMPT_FILE"

echo "[once-review.sh] starting claude -p at $(date -Iseconds)" | tee -a "$LOG_FILE"
set +e
# shellcheck disable=SC2002
cat "$PROMPT_FILE" | claude -p --permission-mode acceptEdits 2>&1 | tee -a "$LOG_FILE"
rc=${PIPESTATUS[1]}
set -e
echo "[once-review.sh] claude exit=$rc at $(date -Iseconds)" | tee -a "$LOG_FILE"

exit "$rc"
