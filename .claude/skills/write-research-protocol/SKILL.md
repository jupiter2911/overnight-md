---
name: write-research-protocol
description: Use this skill to write a clinical research protocol destination document — for a prospective or retrospective study, RCT, single-arm trial, cohort, case-control, or registry analysis. Trigger this AFTER a `grill-me` session, when the user is ready to capture the study design (PICO, population, endpoints, sample size, analysis plan, ethics, timeline). The protocol is a *destination* document focused on study design and feasibility — it is NOT the full IRB/ethics submission, NOT the full statistical analysis plan (link to a separate SAP via `write-analysis-plan` if needed), and NOT a manuscript. Use `write-prd-software` for software projects and `write-analysis-plan` for the statistical part of a study.
---

# Write Research Protocol

Capture a clinical research study as a protocol destination document. Scope is study design and feasibility, not the full IRB packet or statistical analysis plan.

## When this skill is the right one

- Designing a new study (prospective or retrospective).
- Writing a study concept for funding / ethics / institutional review.
- Drafting the protocol section that will feed into an IRB submission, manuscript Methods, or registry entry.

If the user is doing the *statistical analysis itself* on existing data, use `write-analysis-plan` instead. A retrospective study often needs both: the protocol describes the study, the SAP describes the analysis. They can reference each other.

## Pre-flight check

If grilling has not happened, recommend `grill-me` first. Research protocols are particularly sensitive to definitional drift (population, endpoint operationalization, censoring rules).

## Workflow

1. Locate the grilling transcript or alignment context.
2. Confirm which CONSORT/STROBE/PRISMA reporting checklist will apply at publication time, so the protocol pre-aligns with it.
3. Write the protocol using the template below.
4. Save to `PRDs/YYYY-MM-DD-<short-slug>-protocol.md`.
5. If a separate SAP will be needed, recommend running `write-analysis-plan` next. Otherwise hand off to `prd-to-issues` (e.g., for data extraction tasks, REDCap setup, retrospective chart review issues).

## Template

```markdown
# Protocol: <Study title>

**Date:** YYYY-MM-DD
**Principal investigator:** <name>
**Institution:** <institution>
**Status:** Concept | Draft | Submitted to IRB | Approved | In progress | Closed
**Reporting checklist target:** CONSORT | STROBE | PRISMA | other

## 1. Background and rationale

<3–6 sentences. The clinical gap, prior evidence, why this study is needed now.>

**Key references:** <3–5 most important citations, with year and journal>

## 2. Research question (PICO)

- **P (Population):** <patients with X who meet Y criteria, from setting Z>
- **I (Intervention / exposure):** <what is being given / what defines the exposed group>
- **C (Comparator):** <standard of care | placebo | unexposed cohort | none — single-arm>
- **O (Outcome):** <primary; secondary; safety>

**Hypothesis:** <directional, falsifiable statement>

## 3. Study design

- **Type:** RCT | non-randomized trial | prospective cohort | retrospective cohort | case-control | cross-sectional | registry analysis | systematic review
- **Allocation / sampling:** <if applicable>
- **Blinding:** <if applicable>
- **Setting:** <single-center / multi-center; outpatient / inpatient>
- **Period:** <enrollment start–end; follow-up duration>

## 4. Population

**Inclusion criteria:**
- ...

**Exclusion criteria:**
- ...

**Recruitment / case identification source:** <hospital tumor registry, EMR query, clinic referrals, etc.>

## 5. Endpoints

**Primary endpoint:**
- Definition (operational, with measurement instrument and time point):
- Rationale:

**Secondary endpoints:**
- ...

**Safety / tolerability endpoints:** (if interventional)
- ...

## 6. Sample size

- **Assumed effect size:** <e.g., HR 0.7, OR 1.5, mean difference 0.5 SD>
- **α / power:** typically 0.05 / 0.80
- **Calculation method / tool:** <e.g., `pwr` package, PASS, formula reference>
- **Resulting sample size:** <n per arm; total>
- **Feasibility check:** <can we actually enroll/identify this many in the time window?>

## 7. Procedures

<Brief description of what happens to each participant or what data is extracted for each retrospective subject. Avoid SOP-level detail — this protocol references the SOP, doesn't replace it.>

## 8. Variables to collect

| Domain | Variables |
|---|---|
| Demographics | age, sex, ethnicity, ... |
| Disease | diagnosis, stage, histology, biomarkers, ... |
| Treatment | regimen, dose, duration, ... |
| Outcome | endpoint variables from §5 |
| Safety | AE grade and attribution (if interventional) |

(For data extraction studies, this table feeds directly into `prd-to-issues` to generate REDCap setup / extraction sheet issues.)

## 9. Statistical analysis (high level)

<2–4 paragraphs, OR a one-line reference to a separate SAP.>

If a full SAP is needed:
> See companion SAP: `PRDs/YYYY-MM-DD-<slug>-SAP.md` (use `write-analysis-plan` to draft).

## 10. Ethics and regulatory

- **IRB / ethics committee:** <which one>
- **Informed consent:** required | waived (justify) | retrospective waiver
- **Data protection:** <de-identification scheme, storage, access>
- **Trial registration (if applicable):** ClinicalTrials.gov / ISRCTN / national registry
- **Conflicts of interest:** <declared>

## 11. Timeline and milestones

| Milestone | Target date |
|---|---|
| IRB submission | |
| First patient enrolled / data extraction start | |
| Primary endpoint analysis lock | |
| Manuscript draft | |
| Submission to journal | |

## 12. Deliverables

- Manuscript targeting <journal>
- Conference abstract for <ASCO / ESMO / WCLC / KALC / etc.>
- Internal report for <institution>
- Dataset and analysis code archived at <location>

## 13. Out of scope

- ...

## 14. Open questions

(Things grilling didn't resolve — these become HITL issues or trigger another grilling round.)
```

## Key rules

- **Don't bloat into IRB territory.** This is the protocol destination doc. The IRB submission is downstream.
- **Don't bloat into SAP territory.** If statistical analysis is non-trivial, link to a separate SAP via `write-analysis-plan`.
- **Pin the reporting checklist (CONSORT/STROBE/PRISMA) early.** It shapes what variables you must collect.
- **Sample size feasibility is non-negotiable.** A protocol with a sample size that can't be reached is fiction.

## Hand-off message

If a separate SAP is needed:
> Protocol saved to `PRDs/YYYY-MM-DD-<slug>-protocol.md`. The statistical analysis is non-trivial — recommend running `write-analysis-plan` next to draft a companion SAP. Then run `prd-to-issues` to generate the work backlog (data extraction, REDCap setup, etc.).

Otherwise:
> Protocol saved to `PRDs/YYYY-MM-DD-<slug>-protocol.md`. Run `prd-to-issues` to generate the work backlog.
