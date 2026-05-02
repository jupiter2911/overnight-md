# AI Coding Plugin — Pipeline Overview

A skill plugin implementing the Matt Pocock workflow (humans-plan / AI-implements-AFK), adapted for Minh Truong's mixed software + clinical research work.

## Core principle

Every session with an LLM has a **smart zone (~0–100K tokens)** and a **dumb zone (>100K)**. The plugin fights the dumb zone by:

1. **Persisting all state to files** (PRD, issues, commits, reviews) — never relying on conversation memory.
2. **Clearing context between phases** (don't compact, just `/clear` and re-pull artifacts).
3. **Splitting big tasks into vertical slices** so each unit fits in the smart zone.
4. **Pushing vs pulling standards**: implementer pulls coding standards as needed; reviewer has them pushed in.

## Pipeline

```
IDEA
  ↓ grill-me                              (HITL — human in the loop)
ALIGNMENT TRANSCRIPT
  ↓ write-prd-software   |  write-analysis-plan  |  write-research-protocol
DESTINATION DOCUMENT
  ↓ prd-to-issues                         (HITL)
KANBAN BACKLOG (issues/*.md)
  ↓ ralph-implement                       (AFK in Docker)         ← Phase 2
  │   ↳ [blocked by bug?] → diagnose      (HITL — then back to ralph)
COMMITS
  ↓ auto-review                           (AFK in Docker, fresh)  ← Phase 3
REVIEW VERDICTS (reviews/*.md)
  ↓ qa-loop                               (HITL — human taste)    ← Phase 3
NEW ISSUES → back to ralph-implement

  zoom-out: invoke at any phase when starting on unfamiliar code before grill-me or prd-to-issues.
```

Cross-cutting (pulled when relevant): `tdd-red-green-refactor` (Phase 2), `diagnose` (Phase 2 — when ralph blocks on a bug), `zoom-out` (any phase — before diving into unfamiliar code), `improve-codebase-architecture`, `n8n-workflow`, `token-budget-guard` (Phase 4 — pending).

One-time setup (run once per machine / project, not per session): `git-guardrails-claude-code`.

## Domain variants

The destination document differs by project type. Use the matching skill:

| Project type | Use this skill |
|---|---|
| Web app, n8n workflow, TypeScript / Python service, CLI tool | `write-prd-software` |
| R Markdown / Quarto clinical data analysis | `write-analysis-plan` |
| Clinical research protocol (study design, IRB-bound) | `write-research-protocol` |

`grill-me` and `prd-to-issues` are **domain-agnostic** and compose with all three.

## Standing instructions inherited

These rules are baked into the relevant skills, not relisted at every step:

- **R Markdown prose annotations (Vietnamese)**: After data import/cleaning chunks, and before every analysis chunk, include a Vietnamese prose block. If a single table/figure uses multiple statistical tests, state which test applies to which variable. Enforced in `write-analysis-plan`, `tdd-red-green-refactor` (analysis variant), `auto-review` (via `coding-standards.md`), and verified by `verify-rmd-prose.R`.
- **No em-dashes / en-dashes** in emails composed for Minh. (Not relevant in code/docs, but called out here so future skills know.)
- **Clinical reasoning first, code second** for any clinical work.

## When to use what

| Trigger | Skill |
|---|---|
| Vague feature request, client brief, Slack message with an idea, "I want to build X" | `grill-me` |
| Starting on a large or unfamiliar codebase before grilling or planning | `zoom-out` |
| Right after a grilling session, ready to write the destination doc | one of the `write-*` skills |
| PRD/analysis plan exists, need to break it into work units | `prd-to-issues` |
| Issues exist, want to start implementing | `ralph-implement` (Phase 2) |
| ralph-implement wrote `.ralph/status = BLOCKED` due to a bug it can't resolve | `diagnose` (Phase 2) |
| Implementation done, want code review before merging | `auto-review` (Phase 3) |
| Code reviewed, ready for human eyes | `qa-loop` (Phase 3) |
| Codebase feels "shallow", AI gets confused often | `improve-codebase-architecture` (Phase 4 — pending) |
| Building n8n automation flow specifically | `n8n-workflow` (Phase 4 — pending) |
| Context approaching 80K tokens | `token-budget-guard` (Phase 4 — pending) |

## File layout this plugin creates in your project

```
your-project/
├── PRDs/                      # destination documents
│   └── 2026-04-29-feature-x.md
├── issues/                    # kanban backlog (one .md per issue)
│   ├── 001-schema-and-service.md
│   └── ...
├── reviews/                   # auto-review verdicts (one .md per issue reviewed)
│   └── 001-schema-and-service-review.md
├── qa-log/                    # qa-loop session decisions
│   └── 2026-04-30-batch.md
├── transcripts/               # optional — saved grill-me sessions
│   └── 2026-04-29-feature-x-grilling.md
├── .ralph/                    # ralph-implement loop state (status, logs)
└── .review/                   # auto-review loop state (status, logs)
```

## Phase status

- **Phase 1 — done.** `grill-me`, 3× `write-*`, `prd-to-issues`, this `PLUGIN.md`.
- **Phase 2 — done.** `ralph-implement` (skill + `once.sh` + `ralph.sh` + `Dockerfile`), `tdd-red-green-refactor` (skill + `verify-rmd-prose.R`). Also back-ported `Priority` field into `prd-to-issues` so ralph can sort by priority tier.
- **Phase 3 — done.** `auto-review` (skill + `coding-standards.md` + `once-review.sh` + `review-loop.sh`), `qa-loop` (skill, interactive HITL only). Also updated `grill-me` with cut-off scaling, batched-question rule, and self-verify-before-handoff.
- **Phase 4 — pending.** `improve-codebase-architecture`, `token-budget-guard`, `n8n-workflow`, final `PLUGIN.md` polish. Recommended to test Phases 1–3 end-to-end on a real project before building Phase 4 — Phase 4 skills are cross-cutting helpers whose scope is best informed by real friction.
- **Backlog — from mattpocock/skills.** Three skills worth porting/adapting:
  - `diagnose` — systematic bug diagnosis before fixing (invoke when ralph blocks). Port as a lightweight HITL skill: reproduce → isolate → hypothesize → verify → fix.
  - `zoom-out` — helicopter view of unfamiliar code section before planning. Useful before `grill-me` on a legacy project or a new module.
  - `git-guardrails-claude-code` — Claude Code `PreToolUse` hook that intercepts `git push`, `git reset --hard`, `git clean -f`, `git branch -D`, `git checkout .` before they execute. One-time setup per project (`.claude/settings.json`) or globally (`~/.claude/settings.json`). **Run this on any project before enabling ralph-implement on the host** — the Docker sandbox already has no push credentials, but the hook protects interactive sessions.

## Sandbox image

Phases 2 and 3 share one Docker image (`ralph-sandbox`), built from `ralph-implement/Dockerfile`. Build once, use for both `ralph.sh` (implement loop) and `auto-review/review-loop.sh` (review loop). Image contains: Node 20 + Claude Code CLI, R + tidyverse + rmarkdown + knitr, Python 3 + pandas/numpy, pandoc, git. No host credentials, no remote-push capability.

## Loop runner conventions

| Phase | Loop runner | Per-iteration runner | Status file |
|---|---|---|---|
| 2 | `ralph-implement/ralph.sh` | `ralph-implement/once.sh` | `.ralph/status` |
| 3 | `auto-review/review-loop.sh` | `auto-review/once-review.sh` | `.review/status` |

Both loops respect: max iterations env var, timeout env var, stop-file (touch to halt cleanly), `DONE | CONTINUE | BLOCKED` status protocol. Both refuse to run on host without an explicit `*_FORCE_HOST=1` override.
