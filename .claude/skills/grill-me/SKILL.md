---
name: grill-me
description: Use this skill IMMEDIATELY at the start of any new work whenever the user presents a vague or under-specified idea, brief, Slack message, feature request, research question, analysis plan, or any "I want to build/analyze/study X" prompt. This skill interviews the user one decision at a time, each with a recommended answer, walking down the design tree to reach a shared design concept BEFORE any planning, PRD, or coding begins. The skill RESPECTS a question budget that scales with scope — 5 for a tiny change up to 40 for a large project — and BATCHES related simple choices into one message rather than asking each in isolation. Before declaring alignment reached, it self-verifies by listing locked decisions and scanning for residual vagueness. Trigger this even if the user seems to have a clear idea: alignment is the #1 cause of failure with AI, and a 20-minute grilling session prevents hours of rework. Do NOT skip ahead to writing a PRD or breaking into tasks until grilling is complete.
---

# Grill Me

Interview the user about every aspect of this plan until you reach shared understanding. Walk down each branch of the design tree, resolving dependencies one by one. Stop when alignment is reached — and not later.

## Rules

1. **One open question at a time per decision branch.** Never bundle independent decisions. Wait for the answer before the next question. (See rule 8 for the exception — batching *related* simple choices.)
2. **Always provide your recommended answer** with each question. Even if you're guessing — the user will correct you. This is faster than open-ended interviewing.
3. **Walk down the tree, don't flatten it.** Resolve high-level decisions (scope, primary outcome, target user) before low-level ones (button labels, variable encodings).
4. **Quote-and-suggest.** When the user's brief is ambiguous, quote the ambiguous phrase back and offer 2–3 interpretations.
5. **Stop when alignment is reached, but respect the cut-off ceiling for scope.** Do not over-grill. Question budget by scope:
   - **Tiny change** (one function, single bug fix, copy-tweak): max **5** questions.
   - **Small feature** (single module, well-understood domain): max **12**.
   - **Medium feature** (2–4 modules, or one analysis end-to-end): max **25**.
   - **Large project** (multi-module, novel architecture, new study design): max **40**.
   Hitting the ceiling is a signal to stop and capture residual ambiguity as `Open questions` in the destination doc — not to keep digging.
6. **Pin negative decisions.** When the user explicitly says "we will NOT do X", note it. These will land in the "out-of-scope" section of the PRD.
7. **Keep your own commentary minimal.** This is the user's design, not yours.
8. **Batch related simple choices.** "One open question at a time" applies per *decision branch*, not per *option*. If 2–4 binary or short-list choices sit at the same level of the tree (e.g., "session storage: cookie | JWT", "data file format: CSV | parquet", "log format: JSON | text"), bundle them into one message with one recommended answer per choice. The user replies in one turn instead of N. Do NOT batch across decision levels — scope decisions never bundle with naming decisions.
9. **Self-verify before declaring alignment.** Before saying "Alignment reached", list the 5–10 material decisions you believe are now locked and scan that list yourself for vagueness — phrases like "we'll handle errors gracefully" (how?) or "store the data appropriately" (where? what schema?) are red flags. Ask one final pass on anything still soft. Only after the self-check do you hand off.

## What to grill on (general checklist)

- **Scope & success.** What is the smallest thing that, if built, would already be useful? What does "done" look like?
- **Users & context.** Who triggers this? In what situation? On what device / in what room?
- **Inputs & outputs.** What data goes in, what comes out, in what format?
- **Constraints.** Time, budget, regulatory, technical (existing stack), people (who has to maintain this).
- **Edge cases & failure modes.** What if the input is empty / wrong / huge / late? What if the network/database/LLM is down?
- **Out-of-scope.** What are we explicitly NOT doing in this iteration?
- **Definition of done.** What's the test that proves it works?

## Domain-specific grilling

**For software (web, n8n, TypeScript, Python services):**
- Existing modules / services this touches
- Data model / schema changes
- Auth / permissions
- Deployment target
- Observability needs (logs, metrics)

**For R Markdown clinical analysis:**
- Dataset path and structure (one row = one patient? one visit? one event?)
- Inclusion / exclusion criteria
- Primary outcome variable and its type (continuous, categorical, time-to-event)
- Comparison groups
- Statistical tests planned per variable type
- Missing data strategy
- Required tables / figures (Table 1, K-M curves, forest plot, etc.)

**For clinical research protocol:**
- PICO (Population, Intervention, Comparison, Outcome)
- Study design (RCT, cohort, case-control, single-arm)
- Sample size justification
- Primary endpoint, secondary endpoints, safety endpoints
- Ethics / IRB status
- Timeline and deliverables

**For retrospective data extraction / REDCap / chart review:**
- Source of records: EMR, tumor registry, paper charts, or a mix?
- Unit of extraction: one row = one patient, one admission, one treatment cycle?
- List of variables to extract per domain (demographics, disease, treatment, outcome, safety) — ask for the variable list early, it drives everything
- Who extracts: one reviewer only, two independent reviewers with adjudication, or one + random QC sample?
- Inter-rater agreement plan: what % of records will be double-extracted? What threshold triggers re-extraction?
- Tool: REDCap (existing project vs. new), Excel/Google Sheets, other? Any institutional access constraints?
- Pilot plan: how many pilot patients (suggest 5–10) before full extraction begins?
- Missing data handling: will cases with missing primary variable be excluded, imputed, or analyzed as-is?
- Timeline: extraction deadline, QC deadline, lock date

## Output

The grilling session itself **is** the asset. The transcript becomes context for the next skill (`write-prd-*`).

If the user asks, save the transcript to `transcripts/YYYY-MM-DD-<topic>-grilling.md`.

When you believe you've run out of decisions to surface (or hit the cut-off for the scope tier), perform the rule-9 self-verification: list locked decisions, scan for vagueness, ask one final pass if needed. Then say:

> Alignment reached. Locked decisions: <bulleted list>. Residual open questions (will be captured in the destination doc): <bulleted list, possibly empty>. Ready to write the destination document — use one of: `write-prd-software`, `write-analysis-plan`, or `write-research-protocol`.

## What NOT to do

- Don't summarize what the user said back to them every turn. It's noise.
- Don't write a PRD inside this skill. Stop when alignment is reached and hand off.
- Don't accept "you decide" for material decisions. Push back: "I'd recommend X because Y — does that work, or do you want a different trade-off?"
- Don't ask leading questions designed to confirm your assumptions. Ask neutral questions.
- **Don't ask questions where the recommended answer is obviously right and the user would never disagree.** ("Should we have tests?" — yes, default it. "Should the variable have a label?" — yes, default it. Bake these into your recommendations and only surface them if the user pushes back.)
- **Don't ask the same question twice in different words.** If you already asked about scope, don't re-ask under "milestones". If you already asked about users, don't re-ask under "personas".
- **Don't blow through the cut-off.** If you're at the 12-question ceiling for a small feature and you still have 5 things you wanted to ask, those 5 things become `Open questions` in the destination doc — not 5 more grilling turns.
