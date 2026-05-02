# Coding standards

Default coding standards pushed into `auto-review`'s context every iteration.

**How this is used:** `auto-review/SKILL.md` reads this file in full at the start of every review pass and applies the rules to the diff under review. **Edit per project** — the rules below are sensible defaults for Minh's stack, but project-specific norms (a particular linter config, a domain-specific naming convention, a journal's reporting requirement) belong here too.

**Hash check:** the review verdict file records `sha1sum coding-standards.md` so unintentional drift between review batches is visible. If you change this file mid-batch, expect a different hash on subsequent reviews — that's a feature.

---

## TypeScript / JavaScript

- **`strict: true` in tsconfig.** No implicit any. No `// @ts-ignore` without an inline justification on the same line.
- **No top-level `any`.** Prefer `unknown` plus a narrowing function. `any` inside a single function body is tolerable if narrowed within 3 lines.
- **Named exports preferred** over default exports — they survive renaming and grep better.
- **Errors are values, not control flow.** Throw only for genuinely unrecoverable conditions. For expected failure modes, return a `Result`-style discriminated union or a tagged tuple.
- **Tests** colocate with source as `*.test.ts`, or live under `tests/` mirroring `src/`. Test names start with `it("does X")`, not `it("test X")`. One behaviour per test.
- **No `console.log` in committed code.** Use the project's logger.
- **No magic strings** for keys that appear in more than one file. Constants in a `constants.ts` per module.
- **No deeply nested ternaries.** If the expression spans three or more `?:`, refactor to an `if` chain or a lookup table.

## Python

- **Type hints required** on every public function (return type and all params).
- **`ruff check` and `ruff format`** must be clean. If the project has `mypy --strict`, that is also blocking.
- **Tests with `pytest`.** Fixtures over mock-everything. One assertion per test where reasonable; if a test asserts five unrelated things, it is testing too much.
- **No bare `except:`.** Catch specific exceptions, or `except Exception:` with a logged message.
- **Dataclasses or pydantic models** for structured data passed across module boundaries — not raw dicts.
- **No `from x import *`** in committed code.

## R scripts (`R/*.R` helper files)

These rules apply to standalone `.R` files (helper functions, cleaning scripts, analysis modules) that are sourced by or accompany `.Rmd` / `.qmd` files.

- **One file, one responsibility.** `R/clean.R` cleans; `R/table1.R` produces Table 1. A file that both cleans and produces output is doing too much — split it.
- **No `library()` calls inside helper files.** Dependencies are declared once, at the top of the `.Rmd` / `.qmd` setup chunk. Helper files use `::` notation (`dplyr::mutate()`), or document their requirements with a comment at the top of the file.
- **Functions over bare scripts.** Wrap processing logic in named functions rather than top-level statements. Top-level statements in sourced files cause side-effects that are invisible to the caller.
- **No hard-coded file paths.** Use `here::here()` or pass paths as function arguments. Hard-coded absolute paths break on any other machine.
- **`set.seed()` lives in the `.Rmd`, not in helper files.** Placing it in a helper makes reproducibility depend on source order.
- **No `print()` or `cat()` in committed helper files** unless the function's explicit purpose is reporting. Side-effect output in helpers pollutes knit logs and makes failures harder to trace.
- **Variable-test mapping must be preserved.** If a helper file contains the statistical test (e.g., `chisq.test()`, `t.test()`), the calling `.Rmd` chunk's Vietnamese prose block must still name which test applies to which variable. The helper is an implementation detail; the prose is the analyst's declaration of intent.

## R Markdown / Quarto (Minh's standing instruction)

These rules implement Minh's standing instruction. They are non-negotiable on `.Rmd` / `.qmd` files.

- **Vietnamese prose block after every data import / cleaning chunk.** Must summarise: how missing values were handled, which variables were recoded, and which were assigned labels / factor levels. Verified by `verify-rmd-prose.R`.
- **Vietnamese prose block before every analysis chunk** (table, figure, model output, statistical test). Must state filter conditions and the statistical test(s) used. **If multiple tests appear in the same output, the block must specify which test applies to which variable.** Verified by `verify-rmd-prose.R`.
- **Sanity-check chunks must be present and preserved.** If hidden from the rendered output, set `include = FALSE, eval = TRUE` — never `eval = FALSE`. They are the regression tests for the next analyst.
- **Knit must succeed from a fresh subprocess R session** (`Rscript -e "rmarkdown::render(...)"`), not just from the analyst's interactive session. The reviewer re-runs this; do not trust the cached HTML.
- **No hard-coded paths above the project root.** Use `here::here()` or relative paths from the project root.
- **`set.seed()` declared once near the top of the document** if any randomness is involved (resampling, MI, simulation, model fits with stochastic optimisers).
- **Variable-test mapping in §6 of the SAP must match the test actually used in the analysis chunk.** A finding here is `major` — divergence between SAP and code is the most common cause of statistical errors in clinical Rmd workflows.

## n8n workflows

- **Deterministic node naming.** Each node's name reflects its purpose (`Fetch open issues`, not `HTTP Request1`).
- **Error workflow attached** for any workflow with a Webhook or Schedule trigger.
- **No hardcoded secrets.** Use n8n credentials, never inline tokens or API keys in node parameters.
- **One trigger per workflow** unless the workflow's purpose is genuinely "either A or B causes the same downstream chain". Otherwise split.
- **Sticky notes** at the entry node summarising what the workflow does and what it depends on.

## Commits

- **Format:** `[#NNN] <title verbatim from the issue>` for the implementation commit. `chore: pick up #NNN` and `chore: close #NNN` for the bookkeeping commits. `chore: review #NNN` for the review commit.
- **Body of the implementation commit** must include a DoD checklist with ticked boxes — verbatim copies of the issue's DoD lines, with `[x]` for satisfied items.
- **One issue per implementation commit.** Two issues' worth of work in one commit is a major finding.
- **No merge commits in feature work.** Rebase to keep history linear; the loop re-runs from a clean tree.
- **No "WIP", "fix", or "address review" commits in the final history.** Squash before review.
