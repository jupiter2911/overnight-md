---
name: auto-review
description: Use this skill in a FRESH Claude context (cleared between iterations) to review the commits produced by `ralph-implement`, one issue at a time. Trigger AFTER one or more `ralph-implement` iterations have committed. The skill ENFORCES standards-first review (read `auto-review/coding-standards.md` IN FULL before any review pass — this is push, not pull), per-issue verdict (PASS | NEEDS_CHANGES | BLOCKED) backed by re-running the feedback loop and (for `.Rmd` / `.qmd`) re-running `verify-rmd-prose.R` and a fresh subprocess `rmarkdown::render()`. Refuses to PASS an issue with a red feedback loop, refuses to skip verification because "the diff looks fine", and groups findings by severity (blocker | major | minor | nit) with concrete code references and proposed follow-up issues. Runs in the same Docker sandbox image as `ralph-implement`. Pulled by `once-review.sh` / `review-loop.sh`; do not invoke directly from interactive sessions.
---

# Auto Review

Per-issue, push-style review skill. One run = one issue's review file (or one explicit no-op when nothing remains to review).

## Triggering rules

This skill is invoked by `once-review.sh` (which is invoked by `review-loop.sh`). It assumes:

- Fresh Claude context for this iteration (no implementer carry-over from `ralph-implement`).
- Inside the same Docker sandbox image as `ralph-implement` (Node + R + claude CLI + pandoc).
- Working tree is clean (no uncommitted changes besides the new review file you'll write).
- Git history contains at least one `[#NNN] <title>` commit and a corresponding `chore: close #NNN`.

If preconditions fail, write `BLOCKED` to `.review/status` with a reason in `.review/last-block-reason` and exit 0. The wrapping loop will surface it.

## Boot sequence — push standards in

1. **Read `.claude/skills/auto-review/coding-standards.md` in full.** Do not skim. Do not summarise. Do not "remember from training". This is the *push* in push-vs-pull — the standards are part of the review's input on every iteration, by design.
2. Compute and record the file's `sha1sum` — it goes into the verdict file as `Standards version`. This catches drift if the standards change between batches.

## Issue scoping

1. List git log entries matching `^\[#\d+\]` since the start of history (or since a marker file `.review/last-batch` if present).
2. For each issue number, check whether `reviews/NNN-*.md` already exists.
3. Filter to issue numbers without a review file.
4. Pick the lowest-numbered remaining issue. If none: write `DONE` to `.review/status`, exit 0.

## Per-issue review pass

Steps in order. Do not reorder, do not short-circuit.

### 1. Read inputs
- Issue file `issues/NNN-*.md` (the contract: outcome, modules touched, DoD).
- Main implementation commit `[#NNN] ...` — `git show --stat <sha>` for the file list, `git show <sha>` for the diff.
- (Optional) the `chore: close #NNN` commit — confirms ralph thinks the issue is done and shows the ticked DoD.

### 2. Run the feedback loop fresh

- For code changes: run the project's test + typecheck + lint commands fresh (not from a watcher, not from cache).
- For `.Rmd` / `.qmd` changes:
  - `Rscript .claude/skills/tdd-red-green-refactor/verify-rmd-prose.R <file.Rmd> [...]` — must exit 0.
  - `Rscript -e "rmarkdown::render('<file.Rmd>', quiet = TRUE)"` from a subprocess — must exit 0.

If anything is red: this is a *blocker*. Continue the review (record the other findings too) but the verdict cannot be PASS.

### 3. Standards check

Walk through `coding-standards.md` section by section that's relevant to this issue's languages, and apply each rule against the diff. Record violations with file:line references.

### 4. DoD check

For every checkbox in the issue's `## Definition of done`: state whether it is satisfied and cite the evidence (file path, line range, test name). A ticked checkbox in the issue file is *not* evidence — only the actual code, test, or rendered output is.

### 5. Out-of-scope and modules-touched check

Compare the diff against the issue's `Modules touched` and `Out-of-scope for this issue`:
- Files modified outside `Modules touched` without a justification in the commit body → minor finding.
- Anything in the diff that the issue explicitly listed as out-of-scope → major finding.

### 6. Severity classification

For every finding from steps 2–5:

| Severity | When | Follow-up Type / Priority |
|---|---|---|
| **blocker** | Incorrect behaviour, data corruption risk, security defect, red feedback loop, missing core DoD criterion | HITL / critical |
| **major** | Architectural mismatch, missing test for a behaviour the issue introduced, Vietnamese prose annotation rule violation in `.Rmd`, in-scope DoD criterion only partially satisfied | HITL / normal |
| **minor** | Style violation, edge case not handled but documented as out-of-scope, small dead code | AFK / polish |
| **nit** | Typos, naming, doc wording | AFK / polish (one issue can bundle many nits) |

### 7. Verdict

- **PASS**: zero blocker, zero major, ≤3 minor, any number of nits.
- **NEEDS_CHANGES**: any blocker, OR ≥1 major, OR >3 minor.
- **BLOCKED**: cannot complete the review (missing tooling in sandbox, repository in unreviewable state). Different from NEEDS_CHANGES — this means *you* can't review, not that the implementation needs changes.

## Verdict file

Write to `reviews/NNN-<slug>-review.md` (slug copied from the issue filename):

```markdown
# Review: Issue #NNN — <title from issue>

**Verdict:** PASS | NEEDS_CHANGES | BLOCKED
**Reviewed at:** YYYY-MM-DD HH:MM
**Standards version:** <sha1 of coding-standards.md>
**Issue file:** `issues/NNN-<slug>.md`
**Main commit:** <short sha>

## Feedback loop result

- `<command>`: PASS | FAIL — <truncated relevant output>
- ...

## Findings

### Blocker (N)
- `path/to/file.ts:42-58` — <description>. Suggested fix: <one line>.

### Major (N)
- ...

### Minor (N)
- ...

### Nit (N)
- ...

## DoD verification

- [x] <criterion> — evidence: `path/to/test.ts:30` (`it("...")`).
- [✗] <criterion> — NOT satisfied: <why, with file:line if applicable>.
- ...

## Follow-up issues proposed

(These are *proposed*. They are written by the human via `qa-loop`, not by this skill.)

- [HITL / critical] <title for blocker>
- [HITL / normal]   <title for major>
- [AFK  / polish]   <title bundling nits>
```

Then commit the review file with message `chore: review #NNN`. Write `CONTINUE` to `.review/status` if more issues remain unreviewed, else `DONE`.

## Hard rules — do not negotiate

- **Never PASS an issue with a red feedback loop.** Re-running it is mandatory; trusting ralph's word is not.
- **Never skip `verify-rmd-prose.R` for `.Rmd` issues.** It's the automated check for the standing instruction.
- **Never write follow-up issues directly to `issues/`.** Propose them in the review file; `qa-loop` (HITL) writes them after Minh's approval.
- **Never edit the implementation under review** to fix a finding. The reviewer reviews; another `ralph-implement` iteration on a follow-up issue fixes.
- **Never compress findings to make a verdict cleaner.** If you found 4 minors, list 4 — don't drop one to land on PASS.
- **Never modify `coding-standards.md`** during a review. Standards drift belongs in a separate, deliberate change.

## Anti-patterns to refuse

- **"The diff looks fine, skipping the feedback loop."** Refuse — the feedback loop run is the strongest signal. A diff that looks fine but breaks tests is exactly what review catches.
- **PASS with a TODO comment in the verdict file.** Refuse — TODOs are follow-up issues, file them in the proposed list instead.
- **Bumping a major to a minor "because the fix is small".** Refuse — severity is about impact, not effort.
- **Reviewing two issues in one verdict file.** Refuse — one file per issue, one commit per review.
- **Adding new severity levels** like "warning" or "info". Refuse — use the four defined; don't multiply.
- **Skipping the standards re-read "because I read it last iteration".** Refuse — context is fresh, the file is a few hundred lines, read it.

## Hand-off message

> Review complete: `reviews/NNN-<slug>-review.md`. `.review/status = <DONE|CONTINUE|BLOCKED>`. Once `DONE`, run `qa-loop` (HITL, interactive) to convert proposed follow-ups into actual issues for the next `ralph-implement` cycle.
