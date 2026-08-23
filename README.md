# duke_masters

A hierarchical Bayesian **Stuff+** model for MLB pitches, built from Statcast
pitch-level data.

`mlb_statcast.qmd` is the analysis. It scrapes Statcast in R, reduces to a
pitcher × pitch-type table, then fits the models in Python via `bambi`/PyMC and
validates the resulting metric against cumulative run value.

## Pipeline

| Stage | Language | What happens |
|---|---|---|
| Scrape | R | `baseballr::scrape_statcast_savant()` in weekly windows |
| Clean | R | Dedupe on the true pitch key; mirror horizontal quantities for LHP |
| Aggregate | R | Whiffs / swings and **cumulative run value** per pitcher × pitch type |
| Screen | Python | Missing-data report, within-pitch-type VIF pruning |
| Model 1 | Python | Hierarchical beta-binomial, linear in mechanics, varying slopes by pitch type |
| Diagnose | Python | R-hat, ESS, divergences, tree depth, E-BFMI, PPC |
| Test | Python | Binned residuals + weighted curvature tests for the linearity assumption |
| Model 2 | Python | Same hierarchy with B-spline bases on the terms that fail |
| Stuff+ | Python | Draw-wise z-score against each pitch type's own posterior, on a 100 ± 10 scale |
| Select | Python | Grouped 5-fold CV $R^2$ / MSE against cumulative run value |

## Outputs

- `data/pitcher_summary.csv` — the modelling table written by the R half
- `data/stuff_plus.csv` — Stuff+ with posterior SD and 94% HDI per pitcher × pitch type
- `data/model_selection.csv` — the $R^2$ / MSE comparison table

## Requirements

R: `baseballr`, `tidyverse`.

Python (see `requirements.txt`): `bambi`, `pymc`, `arviz`, `pandas`, `numpy`,
`scipy`, `statsmodels`, `scikit-learn`, `matplotlib`. `nutpie` is optional and
substantially faster; the notebook detects it and falls back to the default PyMC
sampler when it is absent.

Quarto runs the Python chunks through `reticulate`, so install into the
interpreter reticulate resolves to (`reticulate::py_config()` will tell you which).

## validation/

Offline test harness, not part of the analysis. `run_chunks.py` extracts the
notebook's Python chunks in order and executes them against a synthetic,
Statcast-shaped dataset, so the modelling code can be checked end-to-end in an
environment with no Baseball Savant access. The only thing it overrides is the
sampler draw count. See `validation/README.md`.
