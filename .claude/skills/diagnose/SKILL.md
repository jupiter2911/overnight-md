---
name: diagnose
description: Disciplined diagnosis loop for hard bugs and performance regressions. Reproduce → minimise → hypothesise → instrument → fix → regression-test. Use when ralph-implement writes `.ralph/status = BLOCKED` due to a bug, when a test suite is red and the cause is unclear, or when user says "debug this" / "something is broken". In analysis mode (R Markdown / Quarto), also use when `rmarkdown::render()` fails, an R chunk errors, or a sanity-check value is wrong. Adapted from mattpocock/skills.
---

# Diagnose

A discipline for hard bugs. Skip phases only when explicitly justified.

When exploring the codebase, use domain glossary from `PRDs/` and issue files in `issues/` to understand module responsibilities. Check `coding-standards.md` for any invariants relevant to the failing area.

## Entry points

- **From ralph-implement:** Read `.ralph/last-block-reason` first. It contains what ralph tried, which command failed, and the exact error output. Start Phase 1 from there — do NOT re-read the whole codebase blind.
- **From auto-review:** Read `reviews/NNN-*-review.md` for the blocker finding with file:line reference. Start Phase 2 directly if auto-review already reproduced the failure.
- **Interactive session:** User describes the bug. Start Phase 1.

---

## Phase 1 — Build a feedback loop

This is the skill. Everything else is mechanical. If you have a fast, deterministic, agent-runnable pass/fail signal for the bug, you will find the cause. If you don't, no amount of staring at code will save you.

Spend disproportionate effort here. Be aggressive. Be creative. Refuse to give up.

### Ways to construct a loop — try in roughly this order

**For code (TS / Python / n8n):**
1. Failing test at whatever seam reaches the bug — unit, integration, e2e.
2. `curl` / HTTP script against a running dev server.
3. CLI invocation with a fixture input, diffing stdout against a known-good snapshot.
4. Headless browser script (Playwright) — drives UI, asserts on DOM/console/network.
5. Throwaway harness: spin up a minimal subset of the system (one service, mocked deps) exercising just the bug path.
6. Property / fuzz loop: if the bug is "sometimes wrong output", run 1000 random inputs and look for the failure mode.
7. Bisection: if the bug appeared between two commits, automate `git bisect run`.
8. Differential: run the same input through old-version vs new-version and diff outputs.

**For R Markdown / Quarto (analysis mode):**
1. **Minimal-repro chunk.** Extract only the failing chunk(s) into a throwaway `.Rmd`, run via `Rscript -e "rmarkdown::render('repro.Rmd', quiet=FALSE)"`. Smaller file = faster iteration.
2. **Session state isolation.** Run in a fresh R subprocess — not your interactive session. Interactive sessions carry loaded packages and objects that mask bugs.
3. **Sanity-check inspection.** If `verify-rmd-prose.R` failed, read its output line by line. If a knit failed, scroll to the first `Error` in the output, not the last.
4. **Package version check.** Run `sessionInfo()` in the same subprocess. Version mismatches between interactive and subprocess R explain ~30% of Rmd-only failures.
5. **Data probe.** If a sanity-check value is wrong (N off, % missing unexpected, cross-tab off-diagonal), `print(str(df_filtered))` immediately after the filter — confirm the filter expression is doing what the Vietnamese prose block said it would.

### Iterate on the loop itself

Once you have a loop, ask:
- Can I make it faster? (Cache setup, narrow scope.)
- Can I make the signal sharper? (Assert on the specific symptom, not "didn't crash".)
- Can I make it more deterministic? (Pin seed, freeze time, isolate filesystem.)

A 30-second flaky loop is barely better than no loop. A 2-second deterministic loop is a debugging superpower.

### Non-deterministic bugs

Loop the trigger 100x, add stress, narrow timing windows. A 50%-flake bug is debuggable; 1% is not — keep raising the rate.

### When you genuinely cannot build a loop

Stop and say so explicitly. List what you tried. Ask Minh for: (a) access to the environment that reproduces it, (b) a captured artifact (log dump, `.Rmd` rendered output, R session dump), or (c) permission to add temporary instrumentation. Do not proceed to hypothesise without a loop.

**Do not proceed to Phase 2 until you have a loop you believe in.**

---

## Phase 2 — Reproduce

Run the loop. Watch the bug appear. Confirm:

- [ ] The loop produces the failure mode described in `.ralph/last-block-reason` or the user report — not a different failure nearby. Wrong bug = wrong fix.
- [ ] Failure is reproducible across multiple runs (or high-rate for non-deterministic).
- [ ] You have captured the exact symptom (error message, wrong value, wrong N) so Phase 5 can verify the fix addresses it.

**Do not proceed until you reproduce the bug.**

---

## Phase 3 — Hypothesise

Generate 3–5 ranked hypotheses before testing any of them.

Each hypothesis must be falsifiable:
> "If **[X]** is the cause, then **[Y]** will make the bug disappear / **[Z]** will make it worse."

If you cannot state the prediction, the hypothesis is a vibe — discard or sharpen it.

Show the ranked list before testing. Minh often has domain knowledge that re-ranks instantly ("we just changed that import query"). Don't block on it — proceed with your ranking if no response.

**Common hypotheses for R Markdown failures:**
- Wrong filter expression (patients excluded who shouldn't be, or vice-versa)
- Variable recoding in cleaning chunk does not match the derivation rule in SAP section 4
- Package function behaviour changed between interactive and subprocess R sessions (e.g., dplyr group_by scoping)
- Missing data pattern unexpected — NAs propagating through a statistical test
- Vietnamese prose block placed after the chunk instead of before (verify-rmd-prose.R catches this)

---

## Phase 4 — Instrument

Each probe maps to a specific prediction from Phase 3. Change one variable at a time.

**Tool preference:**
1. Debugger / REPL inspection if env supports it. One breakpoint beats ten logs.
2. Targeted logs at boundaries that distinguish hypotheses.
3. Never "log everything and grep".

Tag every debug log with a unique prefix, e.g. `[DEBUG-a4f2]`. Cleanup = one grep. Untagged logs survive; tagged logs die.

**For R Markdown performance regressions:** Logs are usually wrong. Establish a baseline measurement first (`system.time({...})`), then bisect. Measure first, fix second.

---

## Phase 5 — Fix + regression test

Write the regression test **before** the fix — but only if there is a correct seam for it.

A correct seam is one where the test exercises the real bug pattern as it occurs at the call site. If no correct seam exists, note it — the architecture is preventing the bug from being locked down. Flag this as a follow-up issue.

If a correct seam exists:
1. Turn the minimised repro into a failing test at that seam.
2. Watch it fail.
3. Apply the fix.
4. Watch it pass.
5. Re-run the Phase 1 feedback loop one more time from clean state.

**For R Markdown:** The sanity-check chunk IS the regression test. Do not delete it after fixing — set `include = FALSE` to hide from output but keep `eval = TRUE` so it runs every knit.

---

## Hand-off

After Phase 5:

- If called from ralph-implement: clear `.ralph/last-block-reason`, set `.ralph/status = CONTINUE`, and commit the fix under the original issue number with message `fix: [#NNN] <one-line description of bug>`.
- If called interactively: summarise the root cause and the fix in plain language. Offer to file a follow-up issue via `qa-loop` if the fix revealed a deeper architectural problem.

## Hard rules

- **Never propose a fix before completing Phase 2 (reproduction).** "I think the issue is..." without a reproducible loop is a guess, not a diagnosis.
- **Never skip Phase 3 (hypothesise) because "the fix is obvious".** Obvious fixes for hard bugs are usually wrong.
- **Never delete a sanity-check chunk** in an `.Rmd` to "clean up" during a debug session.
- **Never instrument with `print()` statements without tagging them** — untagged debug output survives into committed code.
