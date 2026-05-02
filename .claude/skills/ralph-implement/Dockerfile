# syntax=docker/dockerfile:1.6
#
# Ralph sandbox image.
#
# Design intent (see ralph-implement/SKILL.md):
#   - Read-write on the project work tree (mounted at /work).
#   - NO ability to push to git remotes — we deliberately do not bake any
#     credentials, do not mount ~/.ssh, do not install gh CLI, and do not
#     copy ~/.git-credentials. Push will fail naturally for lack of creds.
#   - NO ability to read host secrets — the only way to get the API key
#     into the container is `docker run -e ANTHROPIC_API_KEY=...`.
#   - Tooling: Node 20 (Claude Code CLI), R + tidyverse + rmarkdown + knitr
#     (analysis-mode TDD), Python 3 + pandas/numpy (utility), pandoc
#     (rmarkdown::render). No LaTeX — analysis output is HTML by default;
#     extend the image yourself if you need PDF output.
#
# Build (from project root, with this Dockerfile present in your skills dir):
#   docker build -t ralph-sandbox -f .claude/skills/ralph-implement/Dockerfile .
#
# Run:
#   docker run --rm -it \
#     -v "$(pwd)":/work \
#     -e ANTHROPIC_API_KEY \
#     ralph-sandbox \
#     bash .claude/skills/ralph-implement/ralph.sh
#
# DO NOT mount ~/.ssh, ~/.aws, ~/.git-credentials, or any credential
# directory into this container. The whole point of the sandbox is to
# deny those to an unattended agent.

FROM debian:12-slim

ENV DEBIAN_FRONTEND=noninteractive \
    LANG=C.UTF-8 \
    LC_ALL=C.UTF-8 \
    NODE_MAJOR=20

# --- System packages (one apt-update for system + R, separate layer for Node) ---
RUN apt-get update && apt-get install -y --no-install-recommends \
      ca-certificates curl gnupg \
      git \
      build-essential \
      r-base \
      r-cran-tidyverse \
      r-cran-rmarkdown \
      r-cran-knitr \
      python3 python3-pip python3-venv \
      pandoc \
      jq \
    && rm -rf /var/lib/apt/lists/*

# --- Node.js 20 (NodeSource) + Claude Code CLI ---
RUN curl -fsSL https://deb.nodesource.com/setup_${NODE_MAJOR}.x | bash - \
    && apt-get install -y --no-install-recommends nodejs \
    && rm -rf /var/lib/apt/lists/* \
    && npm install -g @anthropic-ai/claude-code \
    && npm cache clean --force

# --- Python utility packages ---
RUN pip3 install --no-cache-dir --break-system-packages \
      pandas numpy

# --- Non-root user ---
RUN useradd --create-home --shell /bin/bash ralph \
    && mkdir -p /work \
    && chown -R ralph:ralph /work
USER ralph
WORKDIR /work

# Sanity: ensure key tools resolve at build time. `claude --version` is
# offline so it works without an API key in the build context.
RUN node --version \
    && npm --version \
    && claude --version || true \
    && R --version | head -n 1 \
    && python3 --version \
    && pandoc --version | head -n 1

# Default command is a shell, so an operator can poke around. ralph.sh is
# the intended entrypoint, but we don't bake it as ENTRYPOINT — the script
# lives in /work/.claude/skills/ralph-implement/ via the host bind mount.
CMD ["/bin/bash"]
