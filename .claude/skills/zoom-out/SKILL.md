---
name: zoom-out
description: Zoom out and give a higher-level map of an unfamiliar section of code before planning or grilling. Use when starting on a legacy project, a module you haven't touched before, or before running grill-me on a large codebase. Also useful at the start of a ralph-implement iteration when the issue's "Modules touched" list looks unfamiliar. Adapted from mattpocock/skills (disable-model-invocation in original — here adapted as a HITL orientation skill).
---

# Zoom Out

I don't know this area of code well. Go up a layer of abstraction and give me a map of all relevant modules and callers, using the project's domain glossary vocabulary.

## What to produce

A concise orientation report covering:

### 1. Module map
For each module relevant to the area in question:
- **Path** and one-line responsibility
- **Interface** — the public functions / exported types / HTTP endpoints it exposes (not implementation details)
- **Consumers** — who calls it (callers, importers, workflow nodes)
- **Dependencies** — what it calls outward

Draw relationships as a simple text diagram if there are more than 3 modules.

### 2. Data flow
Trace the primary data path end-to-end — from the entry point (user action / scheduled trigger / HTTP request / R dataset load) to the final output (database write / API response / rendered table / figure). One paragraph, concrete variable names where known.

### 3. Domain glossary (for this area)
List the 5–10 most important domain terms used in this area's code, with one-line definitions. Cross-reference against any `PRDs/` files if present. Flag any naming inconsistencies (e.g., the same concept called "patient" in one module and "subject" in another).

### 4. Current health signals
- Tests: what exists, what coverage looks like, any known gaps
- Known rough edges: TODOs, FIXMEs, deprecated paths, or comments that say "this is a hack"
- For R Markdown projects: does `verify-rmd-prose.R` currently pass? Does a clean `rmarkdown::render()` succeed?

### 5. Recommended entry points
Given the current task or question, suggest the 1–3 files to read first. Explain why each one.

---

## Rules

- **Use the project's domain glossary, not generic CS terminology.** If the codebase calls it a "subject" not a "patient", use "subject".
- **Don't read every file.** The goal is orientation, not exhaustive analysis. Stop at the level of module interfaces.
- **Flag uncertainty explicitly.** "I haven't read module X fully — this is inferred from its exports and callers" is better than confident wrongness.
- **Don't start implementing.** This skill ends with a map. The next step is `grill-me` or `prd-to-issues`, not code.

## When to hand off

After producing the map, ask:
> "Does this match your mental model? Anything I've mis-characterised or missed? Ready to run `grill-me` with this context in hand."

If the user says the map looks right, proceed to `grill-me` (if planning a new feature) or to `prd-to-issues` (if a destination doc already exists).
