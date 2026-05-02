# AI Coding Plugin for Claude Code

A skill plugin implementing the [Matt Pocock](https://www.youtube.com/@mattpocock) workflow (**humans-plan / AI-implements-AFK**), adapted for mixed software + clinical research work.

Built and used by [Minh Truong](https://github.com/drminhtruong) — oncologist and software developer. The standing instructions (Vietnamese prose annotations in R Markdown, clinical-reasoning-first) reflect real constraints from his workflow. Fork and adapt to yours.

## Core idea

Every LLM session has a **smart zone (~0–100K tokens)** and a **dumb zone (>100K)**. This plugin fights the dumb zone by:

1. **Persisting all state to files** — PRDs, issues, commits, reviews. Never relying on conversation memory.
2. **Clearing context between phases** — don't compact, just `/clear` and re-pull the artifacts.
3. **Splitting big tasks into vertical slices** — each unit fits in the smart zone.
4. **Push vs pull for standards** — the implementer pulls coding standards when needed; the reviewer has them pushed into context on every iteration.

## Pipeline

```
IDEA
  ↓ grill-me                              (HITL — you)
ALIGNMENT TRANSCRIPT
  ↓ write-prd-software | write-analysis-plan | write-research-protocol
DESTINATION DOCUMENT
  ↓ prd-to-issues                         (HITL — you)
KANBAN BACKLOG  (issues/*.md)
  ↓ ralph-implement                       (AFK — Docker overnight)
COMMITS
  ↓ auto-review                           (AFK — Docker, fresh context)
REVIEW VERDICTS  (reviews/*.md)
  ↓ qa-loop                               (HITL — your taste)
NEW ISSUES → back to ralph-implement
```

## Skills

| Skill | Phase | Type | Purpose |
|---|---|---|---|
| `grill-me` | 1 | HITL | Interview you about an idea until alignment is reached |
| `write-prd-software` | 1 | HITL | Write a PRD for a software project |
| `write-analysis-plan` | 1 | HITL | Write a Statistical Analysis Plan for an R Markdown clinical analysis |
| `write-research-protocol` | 1 | HITL | Write a clinical study protocol |
| `prd-to-issues` | 1 | HITL | Break a destination doc into vertical-slice issues in `issues/` |
| `ralph-implement` | 2 | AFK | Per-iteration implementer: pick one issue, TDD, commit |
| `tdd-red-green-refactor` | 2 | AFK | TDD in code mode (TS/Python/n8n) and analysis mode (R Markdown) |
| `auto-review` | 3 | AFK | Per-issue reviewer: re-run feedback loop, apply coding standards, write verdict |
| `qa-loop` | 3 | HITL | Walk through review verdicts, approve follow-up issues |
| `diagnose` | 2 | HITL | Disciplined bug diagnosis when ralph blocks |
| `zoom-out` | any | HITL | Orientation map of unfamiliar code before planning |
| `git-guardrails-claude-code` | setup | one-time | Install a PreToolUse hook blocking destructive git commands |

## Prerequisites

- [Claude Code CLI](https://docs.anthropic.com/en/docs/claude-code) installed and authenticated
- [Docker Desktop](https://www.docker.com/products/docker-desktop/) (for the AFK phases — ralph and auto-review run in a sandbox container)
- Git

## Setup

**1. Copy the plugin into your project:**

```bash
cp -r .claude/ your-project/.claude/
```

**2. Build the Docker sandbox image once** (from your project root):

```bash
docker build -t ralph-sandbox -f .claude/skills/ralph-implement/Dockerfile .
```

This takes 10–15 minutes the first time (installs Node 20, Claude Code CLI, R + tidyverse, Python, pandoc).

**3. (Optional) Install git guardrails:**

```bash
claude  # open an interactive session in your project
# then invoke the skill:
# /skill git-guardrails-claude-code
```

## Running the AFK loops

**Phase 2 — implement:**

```bash
docker run --rm -it \
  -v "$(pwd)":/work \
  -e ANTHROPIC_API_KEY \
  ralph-sandbox \
  bash .claude/skills/ralph-implement/ralph.sh
```

**Phase 3 — review:**

```bash
docker run --rm -it \
  -v "$(pwd)":/work \
  -e ANTHROPIC_API_KEY \
  ralph-sandbox \
  bash .claude/skills/auto-review/review-loop.sh
```

Both loops stop automatically when all issues are done (status = `DONE`) or when a blocker is hit (status = `BLOCKED`). Check `.ralph/last-block-reason` or `.review/last-block-reason` for details.

**If a loop was interrupted mid-iteration:**

```bash
bash .claude/skills/ralph-implement/reset-interrupted.sh
```

## File layout created in your project

```
your-project/
├── PRDs/          # destination documents (PRD, SAP, protocol)
├── issues/        # kanban backlog — one .md per issue
├── reviews/       # auto-review verdicts — one .md per issue
├── qa-log/        # qa-loop session decisions
├── transcripts/   # optional: saved grill-me sessions
├── .ralph/        # ralph loop state
└── .review/       # review loop state
```

## Standing instructions (domain-specific)

These are baked into the skills and reflect Minh's workflow. Fork and edit to match yours:

- **Vietnamese prose annotations in `.Rmd` / `.qmd`:** After every import/cleaning chunk, and before every analysis chunk, a Vietnamese prose block is required. Verified automatically by `verify-rmd-prose.R` on every commit.
- **Variable-test mapping:** If a single table/figure uses multiple statistical tests, the prose block must name which test applies to which variable.
- **Clinical reasoning first, code second** for any clinical analysis work.

To adapt these for your own language or domain, edit:
- `.claude/skills/write-analysis-plan/SKILL.md` (§9)
- `.claude/skills/tdd-red-green-refactor/SKILL.md` (§B)
- `.claude/skills/auto-review/coding-standards.md`
- `.claude/skills/tdd-red-green-refactor/verify-rmd-prose.R`

## Phase status

- **Phase 1 — done:** `grill-me`, 3× `write-*`, `prd-to-issues`
- **Phase 2 — done:** `ralph-implement`, `tdd-red-green-refactor`, Docker sandbox
- **Phase 3 — done:** `auto-review`, `qa-loop`
- **Phase 4 — pending:** `improve-codebase-architecture`, `token-budget-guard`, `n8n-workflow`

## License

MIT
