#!/usr/bin/env Rscript
# Extract the ```{r} chunks from mlb_statcast.qmd in order and execute them
# against a synthetic Statcast frame.
#
# Three things are stubbed so this runs without Baseball Savant:
#   * `library(baseballr)` is dropped -- the only thing the notebook uses it for
#     is the scrape, which is itself stubbed below
#   * the `scrape` chunk is replaced by a read of synthetic_statcast.csv
#   * the `setup` chunk's sampler settings are shrunk so the Stan fits finish in
#     minutes instead of hours (skip with FAST=0)
# Every other line executes exactly as written in the notebook.

args <- commandArgs(trailingOnly = TRUE)
QMD  <- if (length(args)) args[1] else "../mlb_statcast.qmd"
FAST <- Sys.getenv("FAST", "1") == "1"

txt <- readLines(QMD, warn = FALSE)
starts <- grep("^```\\{r\\}", txt)
ends   <- grep("^```\\s*$", txt)

chunks <- lapply(starts, function(s) {
  e <- ends[ends > s][1]
  body <- txt[(s + 1):(e - 1)]
  lbl <- grep("^#\\|\\s*label:", body, value = TRUE)
  list(
    label = if (length(lbl)) sub("^#\\|\\s*label:\\s*", "", lbl[1]) else "?",
    code  = body[!grepl("^#\\|", body)]
  )
})
cat(sprintf("extracted %d R chunks\n", length(chunks)))

env <- new.env(parent = globalenv())
failures <- character(0)

for (i in seq_along(chunks)) {
  ch <- chunks[[i]]
  cat(sprintf("\n%s\n[%02d] %s  (%s)\n%s\n",
              strrep("=", 70), i - 1L, ch$label, format(Sys.time(), "%H:%M:%S"),
              strrep("=", 70)))
  flush(stdout())

  code <- ch$code
  if (ch$label == "setup") {
    code <- grep("^\\s*library\\(baseballr\\)", code, value = TRUE, invert = TRUE)
    cat(">> STUB: dropped library(baseballr); the scrape is stubbed too\n")
  }
  if (ch$label == "scrape") {
    code <- 'data <- readr::read_csv("synthetic_statcast.csv", show_col_types = FALSE); nrow(data)'
    cat(">> STUB: reading synthetic_statcast.csv instead of scraping\n")
  }

  res <- try(eval(parse(text = paste(code, collapse = "\n")), envir = env),
             silent = TRUE)
  if (inherits(res, "try-error")) {
    cat("FAILED:\n"); cat(as.character(res), "\n")
    failures <- c(failures, sprintf("[%02d] %s", i - 1L, ch$label))
    break
  } else if (!is.null(res) && ch$label != "scrape") {
    if (is.data.frame(res) || is.atomic(res)) try(print(res), silent = TRUE)
  }

  if (ch$label == "setup" && FAST) {
    assign("CHAINS", 2L, envir = env)
    assign("ITER",   600L, envir = env)
    assign("WARMUP", 400L, envir = env)
    cat(">> VALIDATION OVERRIDE: CHAINS=2 ITER=600 WARMUP=400\n")
  }
}

cat("\n", strrep("=", 70), "\n", sep = "")
cat("FAILURES:", if (length(failures)) paste(failures, collapse = ", ") else "none", "\n")
quit(status = if (length(failures)) 1L else 0L)
