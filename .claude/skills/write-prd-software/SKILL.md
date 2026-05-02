---
name: write-prd-software
description: Use this skill to write a Product Requirements Document (PRD) for a software project — web app, n8n workflow, TypeScript/Python service, CLI tool, or library. Trigger this AFTER a `grill-me` session has reached alignment, when the user is ready to capture the destination. The PRD is the destination document — it captures problem, solution, user stories, implementation decisions, testing strategy, out-of-scope, and the proposed module map. Do NOT use this for clinical data analysis (use `write-analysis-plan`) or research protocols (use `write-research-protocol`). Do NOT skip the grilling session before writing — a PRD without grilling will be misaligned.
---

# Write PRD (Software)

Capture a software feature as a PRD destination document. The PRD's job is to summarize the design concept agreed during grilling, plus the proposed module map, so that `prd-to-issues` can split it into vertical slices.

## Pre-flight check

If there is no grilling transcript and no clear alignment in the conversation history:

> A PRD without prior grilling tends to be misaligned. Run `grill-me` first, or confirm you want to proceed without it.

Otherwise, proceed.

## Workflow

1. **Locate context.** Check the conversation for grilling output, and check `transcripts/` for a saved grilling session.
2. **Brief codebase exploration.** If you don't already know the repo, look at the top-level structure, existing services/modules, package.json or pyproject.toml. Just enough to propose a module map — don't read every file.
3. **Propose the module map first.** Before writing the full PRD, list the modules/services you expect to create or modify. Show this to the user and get a yes/no. This catches misalignment cheaply.
4. **Write the PRD** using the template below.
5. **Save** to `PRDs/YYYY-MM-DD-<short-slug>.md`. Create the `PRDs/` directory if it doesn't exist.
6. **Hand off**: tell the user the PRD is saved and recommend running `prd-to-issues` next.

## Template

```markdown
# PRD: <Feature name>

**Date:** YYYY-MM-DD
**Author:** <user>
**Status:** Draft | Approved | Implemented | Archived

## Problem

<2–4 sentences. What pain are we solving? Who feels it? What evidence do we have that it's real?>

## Solution (one paragraph)

<What we're going to build, at a high level. No implementation details yet.>

## User stories

- As a <role>, I want to <action>, so that <outcome>.
- ...

(Aim for 5–20. Each story should be independently testable.)

## Module map

Modules to create:
- `path/to/new-module` — <one-line responsibility>

Modules to modify:
- `path/to/existing-module` — <what changes>

(Use *deep modules*: small interface, lots of internal logic. If you find yourself proposing many small modules with overlapping responsibilities, push back and consolidate.)

## Implementation decisions

- **Language / framework:** ...
- **Data model:** <key tables / types and their relationships>
- **External services:** ...
- **Auth / permissions:** ...
- **Error handling strategy:** ...
- **Observability:** <logs, metrics, traces if applicable>
- **Migrations / backfills:** <if any>

## Testing strategy

- **Unit / integration test boundaries:** <wrap deep modules, not every function>
- **Test data:** <fixtures, in-memory DB, mocked external services>
- **What we will NOT test automatically:** <visual UI, third-party billing, etc.>
- **Manual QA checklist:** <key user flows the human will click through>

## Out of scope

- ...
- ...

(These are the *negative decisions* from grilling. Without this section the AI will scope-creep.)

## Definition of done

- [ ] All user stories have passing tests
- [ ] Manual QA checklist passes
- [ ] No regressions in existing test suite
- [ ] <Other concrete checks specific to this feature>

## Open questions

(If grilling left anything unresolved, list it here. These should become issues marked `HITL` in `prd-to-issues`.)
```

## Key rules

- **Stay at the destination level, don't slip into the journey.** No phase plans, no task breakdowns. That's `prd-to-issues`'s job.
- **Module map is mandatory.** This is what keeps the codebase from sprawling. If you don't know the repo well enough to propose one, stop and explore first.
- **Out-of-scope section is mandatory.** Use the negative decisions from grilling. If grilling didn't surface any, ask the user for at least 2.
- **Don't read this PRD back to the user once written.** They were aligned during grilling; making them re-read is testing the LLM's summarization, not their understanding. Just confirm it's saved and hand off.

## Hand-off message

> PRD saved to `PRDs/YYYY-MM-DD-<slug>.md`. Run `prd-to-issues` next to break it into vertical slices.
