---
name: prd-to-issues
description: Use this skill to break a destination document (PRD, SAP, or research protocol) into a kanban backlog of independently-grabbable issues, stored as local markdown files in `issues/`. Trigger this AFTER `write-prd-software`, `write-analysis-plan`, or `write-research-protocol` has produced a destination doc, and the user is ready to define the work units. The skill ENFORCES vertical slices (tracer bullets) — each issue must cut across all relevant layers (schema → service → UI for software; import → clean → one analysis → one output for analysis plans) so that feedback arrives at the end of each issue, not at the end of phase 3. Issues are tagged AFK (an agent can do it unattended) or HITL (needs human in the loop), carry an explicit `Priority` (`critical | infra | tracer | normal | polish`) so `ralph-implement` knows what to grab first, and have explicit blocking relationships so multiple agents can work in parallel.
---

# PRD to Issues

Break a destination document into vertical-slice issues with blocking relationships and explicit priority. The output is a kanban backlog of `.md` files in `issues/` that downstream skills (`ralph-implement` in Phase 2) can consume.

## Core principle: vertical slices, not horizontal

AI loves to code horizontally — do all the schema first, then all the API, then all the UI. This is wrong. By the time horizontal phase 3 starts, nobody has seen the system end-to-end and feedback is delayed.

A **vertical slice** (Pragmatic Programmer's "tracer bullet") cuts through all layers needed to produce one observable outcome. The first slice should be the smallest end-to-end thing that proves the architecture works.

| Domain | Bad (horizontal) first slice | Good (vertical) first slice |
|---|---|---|
| Web feature | "Create database schema for points" | "Award points for one lesson completion, visible on dashboard" |
| n8n workflow | "Set up all integrations" | "One webhook → one transform → one Telegram message" |
| Clinical analysis (R Markdown) | "Write all data cleaning" | "Import → clean one outcome variable → produce Table 1 row for that variable" |
| Retrospective study (data extraction) | "Define all REDCap variables" | "Extract demographics for 5 pilot patients end-to-end" |

If you find yourself proposing a first slice that's "do all of layer X", stop and re-slice.

## Workflow

1. **Locate the destination doc.** Search `PRDs/` for the most recent file, or ask the user which one.
2. **Brief codebase / dataset exploration** if context is fresh. Just enough to ground the slicing.
3. **Draft the slice list.** For each slice, name it as an outcome ("Award points for lesson completion → dashboard"), not a task ("Create points table").
4. **Quiz the user on the proposed slices.** Show the list; ask if the first slice is small enough to be the first observable thing. Iterate.
5. **For each accepted slice, create one issue file** under `issues/NNN-<slug>.md` using the template below, including the `Priority` field.
6. **Verify the dependency graph** is acyclic. Print it as a simple text diagram.
7. **Hand off to `ralph-implement`** (Phase 2).

## Vertical slice rules

For each issue, validate:

- **Crosses all needed layers.** If the user will eventually click something / see a number / read a table, the slice should produce a (minimal) version of that.
- **Has at least one observable outcome.** A failing test that drives the slice is the cheapest one.
- **Is independently grabbable.** Can an agent pick this up without having to also do another open issue at the same time? If not, split or merge.
- **Has explicit blocking relationships.** "Blocked by #001" means #001 must merge before this can start. Use sparingly — over-blocking serializes the work.
- **Is correctly tagged AFK or HITL.**
  - AFK: implementation work, refactoring, adding tests, applying a known recipe.
  - HITL: anything requiring taste / domain judgment — UI design choices, statistical method selection where multiple are defensible, ethics decisions, ambiguous clinical definitions.
- **Has a sensible `Priority`** — see the next section.

## Priority field

Each issue carries a `Priority` so `ralph-implement` can pick the most important unblocked AFK issue first, not just the lowest-numbered. Values, in processing order:

- **critical** — bug or regression blocking core functionality, or a security / data-integrity defect. Pre-empts everything else. Use sparingly; if everything is critical, nothing is.
- **infra** — infrastructure / scaffolding / DX work without which other slices cannot proceed (CI setup, dataset import boilerplate, REDCap base config, project skeleton, shared test harness). Does not have a user-visible outcome by itself, but unblocks several slices that do.
- **tracer** — the first vertical slice(s) that prove the architecture end-to-end. Typically the first 1–2 issues per project. Producing one of these flushes out misalignment cheaply.
- **normal** — regular feature slices after the tracer is green. Most issues sit here.
- **polish** — docs, edge cases, accessibility passes, performance tuning, cleanup. Last.

`ralph-implement` processes in the order: critical → infra → tracer → normal → polish, and within a tier sorts by issue number ascending.

When in doubt, default to `normal`. Do NOT mark everything `critical` — it loses meaning. Do NOT mark a tracer slice `infra` because it has scaffolding work in it; `tracer` always wins if there's an observable end-to-end outcome.

## Issue template

Save to `issues/NNN-<slug>.md`:

```markdown
# Issue NNN: <Title — phrased as an outcome, not a task>

**Type:** AFK | HITL
**Priority:** critical | infra | tracer | normal | polish
**Status:** open | in-progress | done | blocked
**Blocked by:** [#NNN, #NNN] | none
**Blocks:** [#NNN] | none
**Estimated tokens:** S (<10K) | M (10–30K) | L (>30K, consider splitting)
**Source PRD:** `PRDs/<filename>.md`

## Outcome

<One paragraph. What will be observably true after this issue is done? Phrase from the user / system perspective, not the implementer perspective.>

## Modules touched

- `path/to/module` — <create | modify | test only>
- ...

## Definition of done

- [ ] <concrete, testable criterion>
- [ ] <concrete, testable criterion>
- [ ] Tests added / extended (specify what kind)
- [ ] Feedback loop runs clean (`npm test && npm run typecheck` or equivalent)

## Implementation notes

<Optional. Any non-obvious constraint, pointer to a relevant existing module, or a "gotcha" the implementer should know. Keep brief — the implementer will explore the codebase themselves.>

## Out-of-scope for this issue

<Anything tempting to do here but belongs in a later slice. Pin it.>
```

## Domain-specific issue patterns

### Software (web / n8n / TS / Python)

First slice typically `Priority: tracer`: smallest end-to-end behavior. Schema + service + UI minimal change + happy-path test.

For n8n specifically, treat each workflow as one deep module — slice by triggering event, not by node type.

### R Markdown / Quarto analysis

When the destination doc is a SAP, the first slice typically (`Priority: tracer`):

- Set up the `.Rmd` skeleton with import chunk + Vietnamese prose annotation block (per SAP §9).
- Clean exactly the variables needed for *one* output (e.g., Table 1 row).
- Produce that single output with the correct statistical test, with the Vietnamese prose annotation block before it specifying which test applies to which variable.

Subsequent slices add one analysis target each, usually `Priority: normal`. Do NOT write a slice that says "do all of cleaning" — that's horizontal.

**Standing-instruction reminder for analysis issues:** Every analysis slice's "Definition of done" must include:
- [ ] Vietnamese prose block immediately after the cleaning chunk(s) for the variables this slice introduces
- [ ] Vietnamese prose block immediately before the analysis chunk, specifying filter conditions and the statistical test(s) used (with variable-test mapping if multiple tests)
- [ ] `verify-rmd-prose.R` exits 0 on the touched `.Rmd` files
- [ ] Fresh `rmarkdown::render()` from a subprocess R session completes with exit 0

### Clinical research protocol → data extraction

For retrospective studies, slices typically map to:
- Pilot extraction (5 patients end-to-end) — `Priority: tracer`
- Per-domain extraction (demographics, disease, treatment, outcome) — `Priority: normal`, only after the pilot proves the schema
- Quality control (inter-rater agreement on a subset) — `Priority: normal`
- Lock and export — `Priority: polish`

## Verifying the dependency graph

After creating all issue files, output a simple text graph:

```
Phase 0 (no blockers, can start immediately):
  #001 [tracer] Schema + service skeleton
  #002 [infra]  Empty dashboard widget

Phase 1 (blocked by Phase 0):
  #003 [tracer] Wire one event end-to-end (blocked by #001, #002)
  #004 [normal] Backfill script (blocked by #001)

Phase 2:
  #005 [normal] Add second event type (blocked by #003)
  ...
```

Confirm with the user that the parallelization is sane. Two unblocked issues at the same level should genuinely be independent.

## Anti-patterns to refuse

- **One giant issue ("implement the feature").** Refuse. Slice it.
- **Numbered phases with no blocking metadata.** Refuse. Use `Blocked by` instead — it's what enables parallel agents.
- **Issues whose Definition of Done is "code is written".** Refuse. DoD is what is *observably true* after.
- **An analysis issue without the Vietnamese prose annotation criteria.** Refuse and add them.
- **Issues without `Priority`.** Refuse. Default to `normal` if genuinely unsure, but make the choice.
- **Marking everything `critical`.** Refuse and re-prioritize — only true blockers / regressions are critical.

## Hand-off message

> Backlog created in `issues/`. <N> issues, <M> can start in parallel. Recommend reviewing the dependency graph above, then running `ralph-implement` (Phase 2 of the plugin) on the AFK issues. Priority order will be: critical → infra → tracer → normal → polish, then by issue number.
