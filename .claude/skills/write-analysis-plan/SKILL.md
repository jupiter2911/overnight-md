---
name: write-analysis-plan
description: Use this skill to write a Statistical Analysis Plan (SAP) destination document for an R Markdown / Quarto clinical data analysis project. Trigger this AFTER a `grill-me` session, when the user is about to start (or restart) an analysis and needs a written plan covering dataset, population, endpoints, statistical tests per variable, expected tables/figures, and missing-data strategy. The plan ENFORCES Minh's standing R Markdown workflow: Vietnamese prose annotations after import/cleaning chunks and before each analysis chunk, with explicit specification of which test applies to which variable when multiple tests appear in the same output. Do NOT use this for software PRDs (use `write-prd-software`) or research protocols (use `write-research-protocol`). Do NOT skip grilling first — clinical analyses are particularly sensitive to misaligned definitions.
---

# Write Analysis Plan (R Markdown / Quarto Clinical)

Capture a clinical data analysis as a Statistical Analysis Plan (SAP) destination document. The SAP is the destination — it is the input to `prd-to-issues` (which will then break the analysis into vertical slices: import → clean → one analysis end-to-end before adding more).

## Pre-flight check

If grilling has not happened, stop and recommend `grill-me` first. Clinical analyses fail most often on definitional issues (which patients qualify, what counts as the event, censoring rules) — exactly what grilling surfaces.

## Standing instructions (inherited from user memory)

These rules MUST be reflected in the SAP and inherited by all downstream skills:

1. **After every data import / cleaning chunk** in the produced `.Rmd` / `.qmd`, a Vietnamese prose block is required. It must summarize: how missing values were handled, which variables were recoded, and which were assigned labels / factor levels.
2. **Before every analysis chunk** (table or figure), a Vietnamese prose block is required. It must state: the filtered dataset conditions and the statistical tests used. **If a single table/figure uses multiple tests, state explicitly which test applies to which variable or section.**
3. The prose blocks are part of the `.Rmd` source (not just the rendered output). They serve as both working annotations and explanatory text.

The SAP must include these as named requirements so `prd-to-issues` produces issues that respect them.

## Workflow

1. Locate the grilling transcript or the conversation alignment.
2. Briefly inspect the dataset if available (column names, n rows, dtypes). If not available, note it as an assumption to validate in the first issue.
3. Propose the analysis module structure first:
   - `R/import.R` (or import chunk)
   - `R/clean.R` (one chunk per derived variable family)
   - `R/table1.R`, `R/survival.R`, etc. — one analysis target per file/chunk
   Show this skeleton to the user, get yes/no.
4. Write the SAP using the template below.
5. Save to `PRDs/YYYY-MM-DD-<short-slug>-SAP.md`.
6. Hand off to `prd-to-issues`.

## Template

```markdown
# SAP: <Analysis title>

**Date:** YYYY-MM-DD
**Analyst:** <user>
**Status:** Draft | Approved | Locked | Reported

## 1. Background and objective

<2–4 sentences. The clinical question. Reference any prior analyses or protocols.>

**Primary research question:** <one sentence, PICO-style>
**Secondary questions:** <list>

## 2. Dataset

- **Source file:** `data/raw/<filename>.<ext>`
- **Unit of observation:** one row = one patient | one visit | one event
- **Expected n:** <number, with breakdown by group if known>
- **Period of data collection:** <YYYY-MM to YYYY-MM>
- **Known data quality issues:** <missing dates, free-text fields, etc.>

## 3. Population

**Inclusion criteria:**
- ...

**Exclusion criteria:**
- ...

**Expected attrition (CONSORT-style flow):** <screened → included → analyzed>

## 4. Variables

| Variable name | Type | Source | Recoding / derivation | Label (Vietnamese) |
|---|---|---|---|---|
| `age` | continuous | raw | none | Tuổi (năm) |
| `age_group` | factor (≥65 vs <65) | derived from `age` | `cut(age, c(0, 65, Inf))` | Nhóm tuổi |
| ... | | | | |

(Use this table as the contract for all downstream analysis. Each derived variable here becomes a deterministic test target during QA.)

## 5. Endpoints

**Primary:** <variable, operational definition, comparison>
**Secondary:** <list>
**Safety / exploratory:** <list>

## 6. Statistical analysis

For each output (table or figure), specify the test(s) and the variable-test mapping.

### 6.1 Table 1 (baseline characteristics)
- Continuous, normal: t-test or ANOVA — applies to: `age`, `bmi`
- Continuous, non-normal: Mann–Whitney or Kruskal–Wallis — applies to: `psa`, `tumor_size`
- Categorical: chi-squared — applies to: `sex`, `stage`
- Categorical with small cells: Fisher exact — applies to: `rare_mutation_subtype`

### 6.2 <Survival analysis name>
- Method: Kaplan–Meier with log-rank test
- Covariates for Cox regression: <list>
- Proportional hazards assumption check: Schoenfeld residuals

### 6.3 <Other analyses>
- ...

(Be exhaustive enough that the analyst — including a future you — knows which test applies to which variable in every output.)

## 7. Missing data

- **Reporting:** missingness summary per variable in the cleaning chunk.
- **Handling strategy:** complete-case | multiple imputation | LOCF | other (justify).
- **Sensitivity analysis if missingness >X%:** <plan>

## 8. Required tables and figures

- Table 1: baseline characteristics by group
- Table 2: ...
- Figure 1: ...
- ...

## 9. Vietnamese prose annotation requirements (STANDING)

Every produced `.Rmd` / `.qmd` MUST include:

- A Vietnamese prose block immediately after each data import / cleaning chunk, summarizing: missing-data handling, recoding decisions, factor level assignments.
- A Vietnamese prose block immediately before each analysis chunk, stating: filter conditions on the dataset, and the statistical test(s) used. If multiple tests appear in a single output, the block must specify which test applies to which variable.

These blocks are part of the source file, not generated post-hoc.

## 10. Reproducibility

- Random seed: `set.seed(<int>)` declared once
- Package versions: `renv.lock` or session info chunk at end
- Output directory: `outputs/YYYY-MM-DD-<slug>/`

## 11. Out of scope

- ...

## 12. Definition of done

- [ ] All variables in §4 are derived and pass cross-tab validation
- [ ] All outputs in §8 are produced with Vietnamese prose annotations as specified in §9
- [ ] Missing-data strategy applied as specified in §7
- [ ] Code knits cleanly from a fresh R session
- [ ] Sensitivity analyses (if any) completed
- [ ] <other domain-specific checks>

## 13. Open questions

(Anything grilling didn't resolve. Becomes HITL issues.)
```

## Key rules

- **The variable table in §4 is the contract.** Every recoding decision lands there. Downstream issues will validate against it (cross-tab, range checks).
- **§6 must be exhaustive on variable-test mapping.** This is the most common source of statistical errors and the standing instruction is explicit about it.
- **§9 is non-negotiable.** Don't soften the language. The Vietnamese prose annotation rule must propagate downstream.
- **Don't write the actual R code in the SAP.** This is the destination doc; code lives in issues / `.Rmd` chunks.

## Hand-off message

> SAP saved to `PRDs/YYYY-MM-DD-<slug>-SAP.md`. Run `prd-to-issues` next. Note: the Vietnamese prose annotation rule (§9) is propagated automatically — `prd-to-issues` will reference it in every analysis-chunk issue.
