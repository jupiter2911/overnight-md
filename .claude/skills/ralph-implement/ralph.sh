#!/usr/bin/env bash
# ralph.sh — unattended AFK loop. MUST run inside the project's Docker sandbox.
#
# Loops once.sh until one of:
#   - .ralph/status reads "DONE"
#   - max iterations reached  (default 50)
#   - timeout reached         (default 8 hours)
#   - stop file exists        (default /tmp/ralph.stop — touch from a host
#                              shell or an `exec`-ed shell into the container
#                              to halt cleanly between iterations)
#   - once.sh returns non-zero
#
# Hard refusal to run on the host: the sandbox has no remote git credentials
# and no host secrets, which is the layer that prevents accidental pushes
# and credential leaks. Running on the host would bypass that protection.
# Override with RALPH_FORCE_HOST=1 only if you understand the implications.
#
# Exit codes:
#   0   loop completed cleanly (status=DONE)
#   3   not running inside a Docker container — refusing
#   4   timeout reached
#   5   once.sh returned non-zero, or status=BLOCKED, or unrecognised status
#   6   max iterations reached without DONE
#   7   stop file detected
#
# Env vars (override at the docker-run line):
#   RALPH_MAX_ITERS    default 50
#   RALPH_TIMEOUT_S    default 28800 (8h)
#   RALPH_STOP_FILE    default /tmp/ralph.stop
#   RALPH_SLEEP_S      default 2 (between iterations, lets you Ctrl-C cleanly)

set -euo pipefail

# --- Sandbox refusal ---
if [[ ! -f /.dockerenv ]] && [[ -z "${RALPH_FORCE_HOST:-}" ]]; then
  cat >&2 <<'EOF'
[ralph.sh] REFUSING TO RUN ON HOST.

This loop is designed to run only inside the Docker sandbox built from the
plugin's Dockerfile. Running on the host would expose your git credentials,
SSH keys, and shell environment to an unattended agent.

Build and run via:
  docker build -t ralph-sandbox -f .claude/skills/ralph-implement/Dockerfile .
  docker run --rm -it \
    -v "$(pwd)":/work \
    -e ANTHROPIC_API_KEY \
    ralph-sandbox \
    bash .claude/skills/ralph-implement/ralph.sh

Override with RALPH_FORCE_HOST=1 only if you understand the implications.
EOF
  exit 3
fi

# --- Config ---
MAX_ITERS="${RALPH_MAX_ITERS:-50}"
TIMEOUT_S="${RALPH_TIMEOUT_S:-28800}"
STOP_FILE="${RALPH_STOP_FILE:-/tmp/ralph.stop}"
SLEEP_S="${RALPH_SLEEP_S:-2}"

STATUS_DIR=".ralph"
STATUS_FILE="${STATUS_DIR}/status"
mkdir -p "$STATUS_DIR"

start_ts=$(date +%s)
iter=0

# Locate once.sh next to this script.
HERE="$(cd "$(dirname "$0")" && pwd)"
ONCE_SH="${HERE}/once.sh"
if [[ ! -f "$ONCE_SH" ]]; then
  echo "[ralph.sh] FATAL: $ONCE_SH not found" >&2
  exit 5
fi

echo "[ralph.sh] starting loop. max_iters=$MAX_ITERS timeout=${TIMEOUT_S}s stop_file=$STOP_FILE"

# --- Main loop ---
while :; do
  iter=$((iter + 1))
  now=$(date +%s)
  elapsed=$((now - start_ts))

  if [[ -f "$STOP_FILE" ]]; then
    echo "[ralph.sh] stop file $STOP_FILE detected, halting after iter=$iter"
    exit 7
  fi
  if (( elapsed >= TIMEOUT_S )); then
    echo "[ralph.sh] timeout reached (${elapsed}s >= ${TIMEOUT_S}s)"
    exit 4
  fi
  if (( iter > MAX_ITERS )); then
    echo "[ralph.sh] max iterations reached ($MAX_ITERS) without DONE"
    exit 6
  fi

  echo "[ralph.sh] === iter $iter / $MAX_ITERS  (elapsed=${elapsed}s) ==="
  set +e
  bash "$ONCE_SH"
  rc=$?
  set -e
  if (( rc != 0 )); then
    echo "[ralph.sh] once.sh failed with exit=$rc, halting"
    exit 5
  fi

  if [[ ! -f "$STATUS_FILE" ]]; then
    echo "[ralph.sh] WARN: $STATUS_FILE not written by iteration. Treating as failure."
    exit 5
  fi
  status=$(tr -d '[:space:]' < "$STATUS_FILE")

  case "$status" in
    DONE)
      echo "[ralph.sh] status=DONE after $iter iterations, ${elapsed}s. Exiting clean."
      exit 0
      ;;
    CONTINUE)
      echo "[ralph.sh] status=CONTINUE, looping."
      ;;
    BLOCKED)
      echo "[ralph.sh] status=BLOCKED. See $STATUS_DIR/last-block-reason. Halting."
      [[ -f "$STATUS_DIR/last-block-reason" ]] && cat "$STATUS_DIR/last-block-reason" >&2
      exit 5
      ;;
    *)
      echo "[ralph.sh] WARN: unrecognised status '$status', halting"
      exit 5
      ;;
  esac

  sleep "$SLEEP_S"
done
