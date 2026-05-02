---
name: ralph-implement
description: Use this skill INSIDE each iteration of `once.sh` / `ralph.sh` to pick one open AFK issue from `issues/`, implement it end-to-end with TDD, run the full feedback loop, and commit. Trigger ONLY from a runner script — never from a regular interactive Claude session, because this skill assumes a Docker sandbox, `--permission-mode acceptEdits`, and a clean per-iteration context. Selects issues by priority (critical → infra → tracer → normal → polish) and within tier by lowest issue number, requires all `Blocked by` to be `done`, refuses HITL issues, and writes `.ralph/status` (`DONE` | `CONTINUE` | `BLOCKED`) so the wrapping loop knows when to stop. Pulls `tdd-red-green-refactor` for actual implementation; does not duplicate that logic. The skill ENFORCES self-verification before commit (full feedback loop for code, fresh knit + `verify-rmd-prose.R` for `.Rmd` / `.qmd`) — refuse to commit without it.
---

# Ralph Implement

Per-iteration AFK implementation skill. One run of this skill = one issue end-to-end (or one explicit no-op if nothing is grabbable).

## Triggering rules

This skill is invoked by `once.sh` (which is invoked by `ralph.sh`). It assumes:

- The current process is inside a Docker container with the project mounted at `/work`.
- `--permission-mode acceptEdits` is in effect.
- Context is fresh for this iteration (no carry-over from previous iterations besides files on disk).
- Git is configured with a non-pushable identity (no remote credentials).

If any of these are missing, refuse to run and exit 0 after writing `BLOCKED` to `.ralph/status`. The only acceptable use outside the runner is a dry run with the env var `RALPH_DRY_RUN=1`, in which case stop after issue selection and print the chosen issue id.

## Recovering from an interrupted loop

If `ralph.sh` was killed mid-iteration (container crash, timeout, host sleep), an issue may be stuck at `Status: in-progress` with no corresponding `[#NNN]` commit. That issue will be silently skipped on the next run, blocking progress indefinitely.

Run this from the project root before restarting the loop:

```bash
bash .claude/skills/ralph-implement/reset-interrupted.sh
# or to preview without making changes:
bash .claude/skills/ralph-implement/reset-interrupted.sh --dry-run
```

The script finds any `in-progress` issues with no matching commit, resets them to `open`, and clears `.ralph/status` so the next `ralph.sh` starts clean.

## Pre-flight checks (in order)

1. `issues/` exists and contains at least one `*.md`.
2. `git status` shows we are on a non-default branch (refuse on `main` / `master`).
3. `.ralph/` directory exists; create if not.
4. Last commit is not empty / not a merge in flight.

If any fails: write `BLOCKED` to `.ralph/status` with a reason in `.ralph/last-block-reason`, print the reason, exit 0. The loop will surface it.

## Issue selection

Load every `issues/*.md`. Parse the bold-key front-matter lines (`**Type:** ...`, `**Priority:** ...`, `**Status:** ...`, `**Blocked by:** ...`). Build candidates:

- `Status: open` — skip `in-progress`, `done`, `blocked`.
- `Type: AFK` — refuse HITL. If the only remaining issues are HITL, write `DONE` to `.ralph/status` and exit (the human handles HITL).
- All `Blocked by` issues have `Status: done` in their files.

Sort candidates by:

1. **Priority tier**: `critical` < `infra` < `tracer` < `normal` < `polish` (lower = sooner). Issues without a `Priority` field default to `normal`.
2. **Issue number** ascending within tier.

If no candidate: write `DONE` to `.ralph/status`, print "No more grabbable AFK issues. Stop.", exit 0.

Otherwise pick the top candidate. Write its issue id to `.ralph/current-issue`. Edit the issue file: `Status: in-progress`. Commit that single change with message `chore: pick up #NNN` so the change is durable across iterations.

## Implementation

1. **Explore.** Read only the modules listed in the issue's `Modules touched`. Do NOT cast a wide net — that burns the smart zone for no gain.
2. **Pull TDD skill.** Read `.claude/skills/tdd-red-green-refactor/SKILL.md`. Detect mode from file extensions in `Modules touched`:
   - any of `.Rmd | .qmd` → **analysis mode**
   - everything else → **code mode**
   - mixed → run analysis mode for the `.Rmd` / `.qmd` parts, code mode for the rest, in that order.
3. **Follow TDD per the pulled skill.** Do not paraphrase its rules — re-read them. The TDD skill is authoritative; this skill only orchestrates.
4. **Self-verify** as defined in the TDD skill. Do NOT skip this step even if you "know it works".
5. **Fail-loud on red.** If the feedback loop is still red after 3 honest attempts, do not commit. Write `BLOCKED` to `.ralph/status` with the failing output snippet in `.ralph/last-block-reason`. Mark the issue back to `Status: open` (not `blocked` — that's reserved for "blocked by another issue") and append a `## Blocker note (YYYY-MM-DD)` section in the issue body describing what failed and what was tried. Exit 0.

## Commit and finalize

When green:

1. Commit working changes. Commit message format:
   ```
   [#NNN] <issue title verbatim>

   <one-line outcome restated>

   DoD checklist:
   - [x] <each DoD line that is now satisfied, copied from the issue>
   - [x] ...
   ```
2. Edit the issue file: set `Status: done`. Tick the DoD checkboxes that are done. Commit that edit separately with message `chore: close #NNN`. Two commits are intentional — the implementation is reviewable on its own.
3. Decide next status:
   - If at least one other AFK issue is grabbable now (after this issue's `Blocks` resolved): write `CONTINUE` to `.ralph/status`.
   - Otherwise: write `DONE`.

## Hard rules — do not negotiate

- **Never push to a remote.** The sandbox has no credentials anyway, but do not try.
- **Never edit issues other than the current one** (with one exception: when closing, you may need to note that this issue's resolution unblocks others — do not silently re-tag those, just rely on the `Blocked by` field).
- **Never modify `Type: HITL` to `AFK`** to grab an issue. If you think it should be AFK, skip it and let the human re-tag.
- **Never weaken DoD criteria.** If a criterion can't be met, mark the issue blocked, don't quietly drop it.
- **Never commit if self-verify failed.** Even if it "looks right".
- **Never run `npm install` / `pip install` of new top-level packages without an issue authorizing it.** Adding deps is a design decision, not an implementation detail.
- **Respect the Vietnamese prose rule for `.Rmd` / `.qmd` issues.** The TDD analysis-mode skill enforces this; do not bypass.

## Anti-patterns to refuse

- **"Just commit and move on, the test is flaky."** Refuse. Either fix it, mark the test `.skip` with a TODO and a new HITL issue filed in `issues/`, or block.
- **Picking up an HITL issue because no AFK issue is available.** Refuse. Write `DONE`, exit.
- **Implementing two issues in one commit because they "go together".** Refuse — issues are the atomic unit for review.
- **Skipping fresh-knit verification on `.Rmd` because "I already tested it in my session".** Refuse. State is in the file system, not in your head.
- **Editing `PRDs/` files.** Refuse. PRDs are upstream artifacts.
- **Adding new files outside `Modules touched` without justification.** Refuse — drop the file or surface the need as a comment in the issue body for the next iteration to address.
- **Auto-resolving merge conflicts.** Refuse — the wrapping loop should be on a clean branch. If there's a conflict, something is wrong; mark blocked.

## Hand-off message

> Iteration complete. `.ralph/status = <DONE|CONTINUE|BLOCKED>`. The wrapping loop (`ralph.sh`) decides what's next. After all iterations, recommend running `auto-review` (Phase 3) on the resulting commits — fresh context, push-style standards.
