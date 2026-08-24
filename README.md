# duke_masters

A hierarchical Bayesian **Stuff+** model for MLB pitches, built from Statcast
pitch-level data. All R.

`mlb_statcast.qmd` is the analysis: it scrapes Statcast with `baseballr`,
reduces to a pitcher × pitch-type table, fits the models with `brms` on Stan,
and validates the resulting metric against cumulative run value.

## Pipeline

| Stage | What happens |
|---|---|
| Scrape | `baseballr::scrape_statcast_savant()` in weekly windows |
| Clean | Dedupe on the true pitch key; mirror horizontal quantities for LHP |
| Aggregate | Whiffs / swings and **cumulative run value** per pitcher × pitch type |
| Screen | Missing-data report, within-pitch-type VIF pruning |
| Model 1 | Hierarchical beta-binomial, linear in mechanics, uncorrelated varying slopes by pitch type |
| Diagnose | R-hat, ESS, divergences, tree depth, E-BFMI, PPC |
| Test | Binned residuals + weighted curvature tests + RESET for the linearity assumption |
| Model 2 | Same hierarchy with penalized `s()` smooths on the terms that fail |
| Stuff+ | Draw-wise z-score against each pitch type's own posterior, on a 100 ± 10 scale |
| Select | Grouped 5-fold CV $R^2$ / MSE against cumulative run value |

## Outputs

- `data/pitcher_summary.csv` — the modelling table
- `data/stuff_plus.csv` — Stuff+ with posterior SD and 94% HDI per pitcher × pitch type
- `data/model_selection.csv` — the $R^2$ / MSE comparison table

## Requirements

```r
install.packages(c("baseballr", "tidyverse", "brms", "posterior",
                   "bayesplot", "loo", "extraDistr"))
```

`brms` compiles models through Stan, so a working C++ toolchain is needed; see
`?rstan::stan_model` or the CmdStanR setup guide. Each model takes 1–3 minutes
to compile before sampling starts — `rstan::rstan_options(auto_write = TRUE)`
caches the compiled binaries between runs.

Both fits are saved under `fits/` via brms's `file=` argument, so re-rendering
reloads them instead of refitting. `file_refit = "on_change"` watches the
formula, data, prior and family — **not** the sampler settings, so delete
`fits/` after changing `CHAINS`/`ITER`/`WARMUP`.

If a fit ever fails, note that `brm()` does not raise: rstan warns and returns a
fit with no draws, which then surfaces later as
`Error: The model does not contain posterior draws.` The notebook checks for
this right after each fit, reports it there, and deletes the saved fit so the
next run refits rather than reloading the broken one.

## validation/

Offline test harness, not part of the analysis. It generates a synthetic,
Statcast-shaped dataset and runs the notebook's R chunks against it, so the
modelling code can be checked end-to-end without Baseball Savant access. See
`validation/README.md`.
