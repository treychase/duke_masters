# validation/

Offline harness for the Python half of `mlb_statcast.qmd`. Not part of the
analysis — nothing here is imported by the notebook.

Baseball Savant is not reachable from every environment (CI, sandboxes, an
airplane). This directory makes it possible to check that the modelling code
runs end-to-end anyway.

## Files

- `make_synthetic_statcast.py` — generates a pitch-level frame with Statcast's
  column names, units, and missingness patterns. The response is simulated with
  a deliberate quadratic in velocity and in vertical break so the linearity
  tests have something real to find. **The numbers carry no baseball meaning.**
- `build_summary.py` — Python mirror of the notebook's R aggregation chunk,
  producing a `pitcher_summary.csv` of the same shape.
- `run_chunks.py` — extracts every ```` ```{python} ```` chunk from the notebook
  in order and executes them in one namespace.
- `run_r_chunks.R` — extracts the notebook's R cleaning/aggregation chunks,
  runs them on the same synthetic frame, and asserts the result matches
  `build_summary.py` row for row. This is what checks the dedupe key, the
  left-hander mirroring, the swing/whiff classification and the run-value
  summation. (The generator does not emit `game_pk` / `at_bat_number` /
  `pitch_number`, so the harness synthesizes them.)

## Running

```bash
python make_synthetic_statcast.py
python build_summary.py
mkdir -p data && cp pitcher_summary.csv data/
python run_chunks.py ../mlb_statcast.qmd

# R half (needs dplyr, tidyr, readr, purrr)
Rscript run_r_chunks.R
```

`run_chunks.py` overrides exactly one thing — `SAMPLE_KW` is shrunk to
`draws=200, tune=300, chains=2` so the two MCMC fits finish in minutes. Set
`FAST=0` to run at the notebook's real settings. Every other line executes as
written.

Exit status is 0 when all chunks run, 1 on the first failure.
