#!/usr/bin/env Rscript
# verify-rmd-prose.R
#
# Verify Minh's Vietnamese prose annotation rule on .Rmd / .qmd files.
#
# Rule (mirrors write-analysis-plan §9 and tdd-red-green-refactor §B):
#   - For each non-setup R chunk whose label suggests data import / cleaning
#     (matches `import|load|read|clean|prepare|recode|derive|wrangle|tidy`),
#     there MUST be a Vietnamese-prose paragraph within the next 10 lines.
#   - For each non-setup R chunk whose label suggests an analysis output
#     (matches `table|tbl|fig|plot|surv|km|cox|test|model|reg|stat|chi|ttest|aov|kruskal`),
#     there MUST be a Vietnamese-prose paragraph within the previous 10 lines.
#   - "Vietnamese prose" = a non-chunk, non-heading line containing at least
#     one Vietnamese-specific diacritic AND at least 5 words.
#
# Usage:
#   Rscript verify-rmd-prose.R <file.Rmd> [<file2.Rmd> ...]
#
# Exit codes:
#   0 = all files OK
#   1 = at least one violation
#   2 = usage error / file not found

suppressWarnings(suppressMessages({
  # Force UTF-8 so Vietnamese characters compare correctly across locales.
  Sys.setlocale("LC_CTYPE", "C.UTF-8")
}))

args <- commandArgs(trailingOnly = TRUE)
if (length(args) == 0L) {
  cat("Usage: Rscript verify-rmd-prose.R <file.Rmd> [<file2.Rmd> ...]\n")
  quit(status = 2L)
}

# Vietnamese diacritic detection. We look for any character that is
# distinctively Vietnamese: the Vietnamese-specific letters (đ, ă, â, ê, ô,
# ơ, ư) plus the precomposed tone-marked vowels in Latin Extended Additional.
# False positives from English text are essentially zero.
vn_chars <- paste0(
  "đĐăâêôơưĂÂĐÊÔƠƯ",
  "áàảãạắằẳẵặấầẩẫậéèẻẽẹếềểễệíìỉĩịóòỏõọốồổỗộớờởỡợúùủũụứừửữựýỳỷỹỵ",
  "ÁÀẢÃẠẮẰẲẴẶẤẦẨẪẬÉÈẺẼẸẾỀỂỄỆÍÌỈĨỊÓÒỎÕỌỐỒỔỖỘỚỜỞỠỢÚÙỦŨỤỨỪỬỮỰÝỲỶỸỴ"
)
vn_pattern <- paste0("[", vn_chars, "]")

is_prose_line <- function(line) {
  if (!nzchar(trimws(line))) return(FALSE)
  if (grepl("^\\s*```", line, perl = TRUE)) return(FALSE)
  if (grepl("^\\s*#{1,6}\\s", line, perl = TRUE)) return(FALSE)  # markdown heading
  if (grepl("^\\s*[-*+]\\s", line, perl = TRUE) &&
      nchar(trimws(line)) < 40) return(FALSE)  # short bullet, treat as label not prose
  if (!grepl(vn_pattern, line, perl = TRUE)) return(FALSE)
  word_count <- length(strsplit(trimws(line), "\\s+", perl = TRUE)[[1]])
  word_count >= 5L
}

import_clean_re <- "(^|[^a-z0-9])(import|load|read|clean|prepare|recode|derive|wrangle|tidy)([^a-z0-9]|$)"
analysis_re     <- "(^|[^a-z0-9])(table|tbl|fig|plot|surv|km|cox|test|model|reg|stat|chi|ttest|aov|kruskal)([^a-z0-9]|$)"

# Fallback: detect chunk category from body when label does not match.
# Reduces false-negative PASS when analyst uses non-standard chunk labels
# (e.g. "chunk-01", "bảng-1", unnamed chunks).
import_clean_body_re <- paste0(
  "readxl::|read_excel|read_csv|read\\.csv|readRDS|read_rds",
  "|haven::|read_sav|read_dta|read_sas",
  "|janitor::|clean_names",
  "|mutate\\(|recode\\(|factor\\(|case_when\\(",
  "|rename\\(|select\\(.*=|relocate\\("
)
analysis_body_re <- paste0(
  "gtsummary::|tbl_summary|tbl_regression|tbl_uvregression",
  "|survfit\\(|coxph\\(|Surv\\(",
  "|ggplot\\(|geom_",
  "|chisq\\.test\\(|fisher\\.test\\(|t\\.test\\(|wilcox\\.test\\(",
  "|kruskal\\.test\\(|anova\\(|lm\\(|glm\\(",
  "|knitr::kable|kable\\(|flextable\\("
)

body_matches <- function(body_lines, pattern) {
  any(grepl(pattern, body_lines, perl = TRUE, ignore.case = FALSE))
}

extract_label <- function(header) {
  # Match either ```{r label, opts} or ```{r, opts} or ```{r}
  m <- regmatches(header, regexec("^```\\{r\\b\\s*([^,}\\s]*)", header, perl = TRUE))[[1]]
  if (length(m) >= 2L) trimws(m[2]) else ""
}

find_chunk_bounds <- function(lines) {
  starts <- grep("^```\\{r\\b", lines, perl = TRUE)
  if (length(starts) == 0L) return(list(starts = integer(0), ends = integer(0)))
  ends <- integer(length(starts))
  n <- length(lines)
  for (i in seq_along(starts)) {
    s <- starts[i]
    e <- s + 1L
    while (e <= n && !grepl("^```\\s*$", lines[e], perl = TRUE)) e <- e + 1L
    ends[i] <- min(e, n)
  }
  list(starts = starts, ends = ends)
}

check_file <- function(path) {
  if (!file.exists(path)) {
    cat(sprintf("[verify-rmd-prose] FILE NOT FOUND: %s\n", path))
    return(FALSE)
  }
  lines <- readLines(path, warn = FALSE, encoding = "UTF-8")
  n <- length(lines)
  bounds <- find_chunk_bounds(lines)
  starts <- bounds$starts
  ends <- bounds$ends

  if (length(starts) == 0L) {
    cat(sprintf("[verify-rmd-prose] OK %s (no R chunks)\n", path))
    return(TRUE)
  }

  violations <- character(0)
  checked <- 0L

  for (i in seq_along(starts)) {
    s <- starts[i]; e <- ends[i]
    label <- extract_label(lines[s])
    if (nzchar(label) && grepl("^setup", label, ignore.case = TRUE, perl = TRUE)) next
    label_for_msg <- if (nzchar(label)) label else "<unnamed>"

    is_ic <- grepl(import_clean_re, label, perl = TRUE, ignore.case = TRUE)
    is_an <- grepl(analysis_re,     label, perl = TRUE, ignore.case = TRUE)

    # Fallback: if label gives no signal, inspect the chunk body.
    if (!is_ic && !is_an && e > s) {
      body <- lines[(s + 1L):max(s + 1L, e - 1L)]
      if (body_matches(body, import_clean_body_re)) is_ic <- TRUE
      if (body_matches(body, analysis_body_re))     is_an <- TRUE
    }

    if (!is_ic && !is_an) next  # Other chunks not regulated by the standing instruction.

    checked <- checked + 1L

    if (is_ic) {
      window <- if (e + 1L <= n) lines[(e + 1L):min(e + 10L, n)] else character(0)
      if (!any(vapply(window, is_prose_line, logical(1L)))) {
        violations <- c(violations, sprintf(
          "  L%d chunk `%s` (import/clean): missing Vietnamese prose in next 10 lines",
          s, label_for_msg))
      }
    }
    if (is_an) {
      window <- if (s - 1L >= 1L) lines[max(1L, s - 10L):(s - 1L)] else character(0)
      if (!any(vapply(window, is_prose_line, logical(1L)))) {
        violations <- c(violations, sprintf(
          "  L%d chunk `%s` (analysis): missing Vietnamese prose in previous 10 lines",
          s, label_for_msg))
      }
    }
  }

  if (length(violations) == 0L) {
    cat(sprintf("[verify-rmd-prose] OK %s (%d regulated chunks checked)\n", path, checked))
    TRUE
  } else {
    cat(sprintf("[verify-rmd-prose] FAIL %s\n", path))
    cat(paste(violations, collapse = "\n"), "\n", sep = "")
    FALSE
  }
}

results <- vapply(args, check_file, logical(1L))
if (all(results)) quit(status = 0L) else quit(status = 1L)
