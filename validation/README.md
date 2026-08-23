# validation/

Offline harness for `mlb_statcast.qmd`. Not part of the analysis — nothing here
is sourced by the notebook.

Baseball Savant is not reachable from every environment (CI, sandboxes, an
airplane). This directory makes it possible to check that the notebook runs
end-to-end anyway.

## Files

- `make_synthetic_statcast.R` — generates a pitch-level frame with Statcast's
  column names, units and missingness patterns. Quality is simulated with a
  deliberate quadratic in velocity and in vertical break, so the linearity tests
  have something real to find. **The numbers carry no baseball meaning.**
- `build_summary.R` — mirror of the notebook's aggregation chunk, producing a
  `data/pitcher_summary.csv` for the Stan probes.
- `run_chunks.R` — extracts every ```` ```{r} ```` chunk from the notebook in
  order and evaluates them in one environment.

## Running

```bash
Rscript make_synthetic_statcast.R
Rscript build_summary.R          # optional; only the probes need it
Rscript run_chunks.R ../mlb_statcast.qmd
```

`run_chunks.R` stubs three things: `library(baseballr)` is dropped (its only use is the scrape), the `scrape` chunk reads
`synthetic_statcast.csv` instead of calling Baseball Savant, and `CHAINS`/`ITER`/
`WARMUP` are shrunk so the two Stan fits finish in minutes. Set `FAST=0` to
sample at the notebook's real settings. Every other line runs as written.

Exit status is 0 when all chunks run, 1 on the first failure.

## Note on Stan

`rstan` needs Boost headers. On Debian/Ubuntu the `r-cran-bh` package is a stub
that relies on system Boost, and `rstan` then fails with
`Boost not found; call install.packages('BH')`. Point it at the system headers:

```bash
ln -sfn /usr/include /usr/lib/R/site-library/BH/include
```

`rstan::rstan_options(auto_write = TRUE)` caches compiled models and is worth
setting; each model otherwise recompiles from scratch (1–3 minutes).
