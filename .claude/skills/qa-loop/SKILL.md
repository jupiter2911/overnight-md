---
name: qa-loop
description: Use this skill INTERACTIVELY (HITL — human in the loop) AFTER `auto-review` has produced one or more `reviews/*.md` files. The skill walks Minh through review verdicts, gathers approval before turning proposed follow-ups into actual issue files, and writes a `qa-log/YYYY-MM-DD-batch.md` recording decisions. The skill REFUSES to run unattended (no AFK mode) — its purpose is to apply human taste where review verdicts are ambiguous, where a "blocker" might actually be a feature negotiation, or where two minors should be merged into one issue. Refuses to write to `issues/` without explicit per-issue approval. Refuses to silently drop blockers. Designed for use in a regular Claude session (claude.ai or `claude` interactive), NOT inside a Docker loop.
---

# QA Loop

Interactive HITL skill. Walks Minh through review verdicts, gathers approval, materialises agreed-upon follow-ups as new issue files.

## Triggering rules

- At least one `reviews/*.md` file with no corresponding entry in `qa-log/` — i.e., a review that hasn't been reconciled yet.
- Working tree clean (so any new issue files written are visible as their own commits).
- This is **not** an AFK skill. If invoked from `once.sh` / `once-review.sh` / a Docker loop / any non-interactive context, refuse — print a one-line reason and exit.

## Workflow

### 1. Aggregate

Scan `reviews/*.md`. For each, parse:
- Issue number
- Verdict (`PASS` | `NEEDS_CHANGES` | `BLOCKED`)
- Counts per severity (`blocker`, `major`, `minor`, `nit`)
- List of proposed follow-up issues

Print a single batch summary table:

```
Issue  Verdict          Blocker  Major  Minor  Nit  Proposed follow-ups
#001   PASS                   0      0      1    2  1
#002   NEEDS_CHANGES          1      2      0    0  3
#003   PASS                   0      0      0    1  0
```

Then ask: "Walk through NEEDS_CHANGES first?" Default order is verdict severity (`BLOCKED` → `NEEDS_CHANGES` → `PASS`), then issue number ascending. PASS reviews still get a quick pass for nit / minor follow-ups; do not skip them entirely — nits compound across batches.

### 2. Per-review walkthrough

For each review, in order:

1. **Show the verdict and findings, grouped by severity.** Do not summarise the diff — Minh already saw the implementation. Reviewer's findings are what's new.
2. **For each proposed follow-up**, present:
   - Title
   - Severity / proposed Type / Priority (from the severity → action mapping)
   - One-line rationale
   And offer one of:
   - `[a]` Accept as proposed
   - `[e]` Edit (then collect Minh's edits inline)
   - `[m]` Merge with another proposed follow-up (specify which)
   - `[d]` Drop (with rationale logged)
3. **For blockers specifically**, do NOT allow `[d]` (drop) without an explicit rationale of length ≥1 sentence. The rationale lands in the QA log either way.

Bundle simple decisions where Minh's preference is likely uniform — e.g., "5 nits on naming, all the same kind: accept all? `[a/A]`" — but do NOT bundle blockers, do NOT bundle across reviews.

### 3. Spot-check helper

When walking a review with a `.Rmd` finding, offer:

> Open `outputs/<slug>.html` and eyeball the new table — does the group n match what the prose block said? (y/n)

When walking a UI / web finding, offer:

> Run the dev server, navigate to `<route>`, click `<element>` — does the behaviour match the issue's outcome statement? (y/n)

These are prompts for Minh to act, not automated checks. Record the answer in the QA log.

### 3b. Dropped blockers — mandatory trace issue

When Minh drops a blocker (chooses `[d]`), do NOT let it disappear silently. After collecting the rationale, immediately create a trace issue in `issues/`:

```markdown
# Issue NNN: [TRACE] Blocker dropped — <original blocker title>

**Type:** HITL
**Priority:** critical
**Status:** open
**Blocked by:** none
**Blocks:** none
**Estimated tokens:** S
**Source PRD:** <copy from parent issue>

## Outcome

Blocker finding from review of #MMM was dropped deliberately on YYYY-MM-DD.
This issue exists so the decision is auditable and revisitable.

**Original finding:** <paste the blocker description verbatim>
**Reason dropped:** <Minh's rationale, verbatim>

## Definition of done

- [ ] Minh has confirmed this finding is no longer a concern (re-review or documented exception)
- [ ] OR a follow-up fix has been implemented and reviewed in a subsequent cycle

## Implementation notes

This is a trace / decision-record issue. It may be closed immediately if Minh confirms the finding
was a false positive — but it must be closed explicitly, not silently.
```

Commit with `chore: trace dropped blocker from review of #MMM → #NNN`. Record in the QA log under the relevant review section.

This rule applies even if Minh says "just drop it" — the trace issue is the record that it was dropped intentionally, not forgotten.

### 4. Materialise approved follow-ups

After each review is fully walked:

1. Pick the next available issue number (one greater than the highest existing in `issues/`).
2. For each accepted follow-up, write `issues/NNN-<slug>.md` using the template from `prd-to-issues/SKILL.md`. Fill in:
   - `Type`, `Priority` per the severity → action mapping (blocker → HITL critical, major → HITL normal, minor / nit → AFK polish).
   - `Blocked by`: nothing by default; ask Minh if there's a logical dependency on another issue.
   - `Source PRD`: copy from the parent issue.
   - `Outcome`: rephrase the finding from the user / system perspective, not the reviewer's perspective.
   - `Definition of done`: at least one concrete testable criterion derived from the finding.
3. Commit each new issue file with `chore: file followup #NNN (from review of #MMM)`.

### 5. QA log

Write `qa-log/YYYY-MM-DD-batch.md`:

```markdown
# QA log: <date> batch

**Reviews processed:** <list of review filenames>
**New issues filed:** <list of #NNN>
**Findings dropped:** <list with rationale>
**Spot-check results:** <list>

## Per-issue decisions

### Review of #001
- Finding 1 (minor): Accepted as new #042
- Finding 2 (nit): Merged into #043 (bundle of nits)

### Review of #002
- ...
```

Commit with `chore: qa log <date>`.

## Hard rules — do not negotiate

- **Never write to `issues/` without explicit per-issue approval from Minh.** Bundles need a single explicit approval (`[A]` for the bundle), not silent consent.
- **Never drop a blocker without a rationale recorded in the QA log.**
- **Never edit `reviews/*.md`** — they are the auditable record of what `auto-review` saw. Disagreements live in the QA log instead.
- **Never drop a blocker without creating a trace issue in `issues/`.** The rationale alone in the QA log is not enough — the trace issue keeps the decision visible in the backlog until Minh explicitly closes it.
- **Never run unattended.** Refuse if invoked from `once-review.sh` or any loop runner.
- **Never propose follow-up issues that re-do work the original issue already covered.** If the original DoD is wrong, that's an SAP / PRD edit, not a new issue.

## Anti-patterns to refuse

- **"Just accept all the proposed follow-ups."** Refuse — that defeats the human-taste step. Walk them.
- **Filing a follow-up issue with `Type: AFK` for a blocker.** Refuse — blockers are HITL by mapping. If Minh disagrees, edit the mapping in the next round, don't bypass it now.
- **Skipping a PASS review's nit follow-ups entirely.** Refuse — at least skim them; nits compound and one nit-bundle issue per batch keeps the codebase from drifting.
- **Bundling 10 unrelated minor findings into one issue.** Refuse — bundle only the same kind (e.g., naming, doc wording, dead code).
- **Asking Minh 20 questions in one message.** Refuse — walk the reviews one verdict at a time, one finding at a time. The point of HITL is real attention, not throughput.

## Hand-off message

> QA log saved at `qa-log/YYYY-MM-DD-batch.md`. <N> new issues filed in `issues/`. Recommend running `ralph-implement` next to pick up the AFK ones. HITL ones — Minh handles those before re-running ralph.
