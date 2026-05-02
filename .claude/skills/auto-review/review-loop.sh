#!/usr/bin/env bash
# review-loop.sh — unattended auto-review loop. MUST run inside the project's
# Docker sandbox (same image as ralph.sh).
#
# Loops once-review.sh until one of:
#   - .review/status reads "DONE"
#   - max iterations reached  (default 50)
#   - timeout reached         (default 14400, 4 hours)
#   - stop file exists        (default /tmp/review.stop)
#   - once-review.sh returns non-zero
#
# Hard refusal to run on the host: review reads from coding-standards.md,
# re-runs the project's feedback loop, and writes to reviews/. None of that
# requires host credentials, but the principle is the same as ralph.sh —
# unattended Claude invocations belong in the sandbox. Override with
# REVIEW_FORCE_HOST=1 only if you understand the implications.
#
# Exit codes:
#   0   loop completed cleanly (status=DONE)
#   3   not running inside a Docker container — refusing
#   4   timeout reached
#   5   once-review.sh non-zero, status=BLOCKED, or unrecognised status
#   6   max iterations reached without DONE
#   7   stop file detected
#
# Env vars:
#   REVIEW_MAX_ITERS    default 50
#   REVIEW_TIMEOUT_S    default 14400 (4h — review is faster than implement)
#   REVIEW_STOP_FILE    default /tmp/review.stop
#   REVIEW_SLEEP_S      default 2

set -euo pipefail

# --- Sandbox refusal ---
if [[ ! -f /.dockerenv ]] && [[ -z "${REVIEW_FORCE_HOST:-}" ]]; then
  cat >&2 <<'EOF'
[review-loop.sh] REFUSING TO RUN ON HOST.

This loop is designed to run only inside the Docker sandbox built from the
plugin's Dockerfile (the same image as ralph.sh).

Build and run via:
  docker build -t ralph-sandbox -f .claude/skills/ralph-implement/Dockerfile .
  docker run --rm -it \
    -v "$(pwd)":/work \
    -e ANTHROPIC_API_KEY \
    ralph-sandbox \
    bash .claude/skills/auto-review/review-loop.sh

Override with REVIEW_FORCE_HOST=1 only if you understand the implications.
EOF
  exit 3
fi

# --- Config ---
MAX_ITERS="${REVIEW_MAX_ITERS:-50}"
TIMEOUT_S="${REVIEW_TIMEOUT_S:-14400}"
STOP_FILE="${REVIEW_STOP_FILE:-/tmp/review.stop}"
SLEEP_S="${REVIEW_SLEEP_S:-2}"

STATUS_DIR=".review"
STATUS_FILE="${STATUS_DIR}/status"
mkdir -p "$STATUS_DIR"

start_ts=$(date +%s)
iter=0

HERE="$(cd "$(dirname "$0")" && pwd)"
ONCE_SH="${HERE}/once-review.sh"
if [[ ! -f "$ONCE_SH" ]]; then
  echo "[review-loop.sh] FATAL: $ONCE_SH not found" >&2
  exit 5
fi

echo "[review-loop.sh] starting loop. max_iters=$MAX_ITERS timeout=${TIMEOUT_S}s stop_file=$STOP_FILE"

# --- Main loop ---
while :; do
  iter=$((iter + 1))
  now=$(date +%s)
  elapsed=$((now - start_ts))

  if [[ -f "$STOP_FILE" ]]; then
    echo "[review-loop.sh] stop file $STOP_FILE detected, halting after iter=$iter"
    exit 7
  fi
  if (( elapsed >= TIMEOUT_S )); then
    echo "[review-loop.sh] timeout reached (${elapsed}s >= ${TIMEOUT_S}s)"
    exit 4
  fi
  if (( iter > MAX_ITERS )); then
    echo "[review-loop.sh] max iterations reached ($MAX_ITERS) without DONE"
    exit 6
  fi

  echo "[review-loop.sh] === iter $iter / $MAX_ITERS  (elapsed=${elapsed}s) ==="
  set +e
  bash "$ONCE_SH"
  rc=$?
  set -e
  if (( rc != 0 )); then
    echo "[review-loop.sh] once-review.sh failed with exit=$rc, halting"
    exit 5
  fi

  if [[ ! -f "$STATUS_FILE" ]]; then
    echo "[review-loop.sh] WARN: $STATUS_FILE not written by iteration. Treating as failure."
    exit 5
  fi
  status=$(tr -d '[:space:]' < "$STATUS_FILE")

  case "$status" in
    DONE)
      echo "[review-loop.sh] status=DONE after $iter iterations, ${elapsed}s. Exiting clean."
      exit 0
      ;;
    CONTINUE)
      echo "[review-loop.sh] status=CONTINUE, looping."
      ;;
    BLOCKED)
      echo "[review-loop.sh] status=BLOCKED. See $STATUS_DIR/last-block-reason. Halting."
      [[ -f "$STATUS_DIR/last-block-reason" ]] && cat "$STATUS_DIR/last-block-reason" >&2
      exit 5
      ;;
    *)
      echo "[review-loop.sh] WARN: unrecognised status '$status', halting"
      exit 5
      ;;
  esac

  sleep "$SLEEP_S"
done
