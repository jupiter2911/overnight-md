---
name: tdd-red-green-refactor
description: Use this skill IMMEDIATELY when implementing any issue under `ralph-implement` — it covers both code mode (TS / Python / n8n) and analysis mode (R Markdown / Quarto). The skill ENFORCES test-first: in code mode the failing test must be written, run, and confirmed red BEFORE any implementation; in analysis mode sanity-check chunks (N, missingness, ranges, raw-vs-derived cross-tabs, manual audit of 3–5 cases) must be written and pass BEFORE the analysis chunk is written. Refuses common LLM cheats — writing implementation first then back-filling tests, or writing the analysis chunk before sanity checks. Includes a hard self-verification step before commit (fresh feedback loop in code mode; fresh `rmarkdown::render()` from a subprocess R session + `verify-rmd-prose.R` exit 0 in analysis mode). Pulled by `ralph-implement`; do not invoke directly from interactive Claude sessions.
---

# TDD: Red → Green → Refactor (with Analysis Mode)

Two modes. Pick one based on file extensions in the issue's `Modules touched`.

## Mode detection

- Any `.Rmd` or `.qmd` → **analysis mode** (jump to §B).
- Everything else (including `.ts`, `.tsx`, `.py`, n8n workflow JSON, shell) → **code mode** (§A).
- Mixed: run analysis mode for the `.Rmd` / `.qmd` files first, then code mode for the rest. Commit only when both halves are green.

---

## §A. Code mode (TS / Python / n8n)

### A1. Red — write the failing test first

1. Read the DoD lines that are observably testable. Pick the one that most directly observes the outcome of this issue.
2. Write the test in the appropriate test file. Make it concrete — assert real values, not just `truthy`. Avoid mocking the thing you're trying to test.
3. **Run it.** Capture the output.
4. **Confirm it is red for the right reason** — the failure should be the *intended* failure (function returns wrong value, function does not exist), not a typo, missing import, or unrelated crash.
5. Quote the failing output (truncated to the relevant lines) in your reasoning before moving on. **This is the anti-cheat checkpoint** — without a real red, what comes next is not TDD, it is rationalisation.

If the test passes immediately, the test is not strong enough. Strengthen it before proceeding.

### A2. Green — minimum implementation

1. Implement the smallest change that turns the test green.
2. Run the test. Confirm green.
3. Run the full feedback loop (test + typecheck + lint, or whichever the project uses). Must be all green.

Do NOT refactor here. Do NOT add unrelated improvements. "While I'm at it" is forbidden — it belongs in another issue.

### A3. Refactor — only if green

If the implementation is ugly:

1. Make a small refactor.
2. Re-run the full feedback loop after each refactor. Must stay green.
3. Stop refactoring as soon as the code is acceptable. Perfectionism here burns the smart zone.

### A4. Self-verify (mandatory before commit)

1. Run the full feedback loop one more time **from a clean state** — close any dev servers, do not rely on a watcher's incremental state. Typical incantations:
   - JS / TS: `npm test --silent && npm run typecheck && npm run lint`
   - Python: `pytest && ruff check && mypy`
   - n8n: import the workflow JSON in a clean container (`docker run --rm n8nio/n8n import:workflow ...`), trigger the entry node, assert the expected output.
2. If any of those commands isn't defined in the project, fall back to the closest equivalent and document the choice in the commit body.
3. If green, proceed to commit.
4. If red, you broke something between Green and now. Find what, fix, repeat. Do not commit a red feedback loop.

### A5. Anti-patterns to refuse

- **Writing implementation first, then writing the test.** Refuse and restart at Red.
- **Writing a test that "tests the implementation"** (asserts on internal calls instead of observable behaviour). Refuse and rewrite from the user / caller's perspective.
- **Skipping the failing-output quote.** Refuse — that is the cheat checkpoint.
- **Bundling unrelated refactors.** Refuse.
- **Commenting out a failing test "for now".** Refuse — either fix it or block the issue.
- **Adding a `// TODO: re-enable` and moving on.** Refuse; it never gets re-enabled.

---

## §B. Analysis mode (R Markdown / Quarto)

The "test" in analysis mode is a **sanity-check chunk**: a short R chunk that prints values an analyst can eyeball, or that fails loudly when assumptions break. Sanity-check chunks come BEFORE the analysis chunk they protect — same Red-first principle.

### B1. Plan the sanity checks

For the analysis output this issue introduces, list the checks before writing them:

- **N after filter:** print `nrow(df_filtered)`. State the expected value or range in the prose block above.
- **Missing data:** print `colSums(is.na(df_filtered[, vars_used]))`. State the threshold for raising a flag (e.g., > 5%).
- **Range / frequency for each derived variable:** `summary()` for continuous; `table(..., useNA = "always")` for categorical.
- **Raw-vs-derived cross-tab:** for every derived variable in §4 of the SAP, cross-tab against its source. Example: `table(df$age_group, cut(df$age, c(0, 65, Inf), right = FALSE))` should be a 2×2 diagonal.
- **Manual audit:** print 3–5 random rows showing both raw and derived columns side-by-side.

### B2. Vietnamese prose block BEFORE the sanity chunk

Required by Minh's standing instruction. The block must state, in Vietnamese:

- Which dataset / filter is being used.
- What is being sanity-checked.
- What the expected result is — so the eyeball test has a reference.

Example:

> Khối kiểm tra dưới đây chạy trên `df_clean` đã lọc theo tiêu chuẩn nhận vào (n kỳ vọng ≈ 230). Mục tiêu: xác nhận biến phái sinh `age_group` (≥65 vs <65) khớp 1–1 với biến gốc `age`, và tỉ lệ thiếu của các biến dùng cho Bảng 1 đều dưới 5%. Nếu cross-tab không nằm trên đường chéo hoặc tỉ lệ thiếu vượt ngưỡng, dừng lại và rà soát chunk làm sạch trước khi chạy phân tích.

### B3. Write and run the sanity chunk

Chunk options at this stage: `eval = TRUE, include = TRUE, echo = TRUE`.

Run it — knit the file via `Rscript -e "rmarkdown::render('path/to/file.Rmd')"` from a fresh subprocess, not from your interactive R session.

Read the output. If anything looks wrong — N off, % missing high, cross-tab off-diagonal, audit row contains an obvious data-entry artefact — STOP. The cleaning chunk is wrong, not the analysis. Fix the cleaning chunk, re-knit, iterate until the sanity chunk output looks right.

### B4. Vietnamese prose block BEFORE the analysis chunk

Required by Minh's standing instruction §9. The block must state, in Vietnamese:

- Filter conditions on the dataset.
- The statistical test(s) used.
- **If multiple tests appear in the same output, which test applies to which variable.**

Example for a multi-test Table 1:

> Bảng 1 dưới đây so sánh đặc điểm nền giữa hai nhóm điều trị, áp dụng trên `df_clean` (n=230). Test thống kê dùng cho từng biến: t-test cho `age` và `bmi` (liên tục, phân phối chuẩn theo Shapiro); Mann-Whitney cho `psa` và `tumor_size` (liên tục, không chuẩn); Chi bình phương cho `sex` và `stage` (phân loại, các ô đều ≥5); Fisher exact cho `rare_mutation_subtype` (phân loại, có ô <5).

### B5. Write the analysis chunk (Green)

The smallest chunk that produces the required table or figure. No flourishes yet. Use the package the SAP specifies (`gtsummary`, `survival`, `ggplot2`, etc.) — do not introduce a new one without an issue authorising it.

Run it. Eyeball the output against the expectations stated in the prose block (group sizes, plausibility of p-values, completeness of rows).

### B6. Refactor — only if green

Tighten code. Move repeated logic into helper functions in `R/`. Re-knit fresh after each change. Do NOT delete the sanity chunk — it is your regression test for the next analyst. Set `include = FALSE` if it should not appear in the rendered output, but keep `eval = TRUE` so it still executes.

### B7. Self-verify (mandatory before commit)

Three steps, all must pass:

1. **Fresh knit.** Render the `.Rmd` from a subprocess R session — not the interactive one you've been working in:
   ```bash
   Rscript -e "rmarkdown::render('path/to/file.Rmd', quiet = TRUE)"
   ```
   The render must complete with exit 0.

2. **Vietnamese prose check.**
   ```bash
   Rscript .claude/skills/tdd-red-green-refactor/verify-rmd-prose.R path/to/file.Rmd
   ```
   Must exit 0. Read the output even when it's PASS — it tells you which chunks were checked, useful when the file grows and a chunk is silently skipped because the label doesn't match the regex.

3. **Spot-check.** Open the rendered HTML / PDF and look at the new output. Any obvious oddity — empty table, all-NA column, p-value of exactly 1, group sizes that don't sum to N — is grounds to abort the commit and re-investigate.

If all three pass, proceed to commit. Otherwise, fix and repeat.

### B8. Anti-patterns to refuse

- **Writing the analysis chunk before the sanity chunks.** Refuse and restart at B1.
- **Removing sanity chunks "to clean up the file" before commit.** Keep them with `include = FALSE` (still evaluated) — they're regression tests for the next analyst.
- **Skipping the fresh-knit step "because it works in my session".** Refuse. The interactive session is corrupted by hours of trial and error; only the fresh subprocess knit counts.
- **Skipping `verify-rmd-prose.R` "because I added the prose".** Refuse — automated verification is the point. The prose block can be in the wrong location and still look right at a glance.
- **Prose blocks in English.** Refuse — the standing instruction says Vietnamese.
- **A single prose block covering multiple analysis chunks "to avoid repetition".** Refuse — one prose block per chunk, each restating the test-variable mapping for that chunk's output.
- **Citing the SAP §9 in the prose block instead of restating the test-variable mapping.** Refuse — the prose block must be self-contained, so a reader of the rendered report does not need the SAP open.

---

## Hand-off message

> Implementation green and self-verified. Hand back to `ralph-implement` for commit and status update. Once all issues are done, the next phase is `auto-review` (Phase 3), which runs in a fresh context with coding standards pushed in.
