suppressMessages({library(brms); library(dplyr); library(readr)})
options(mc.cores = 2)

d <- read_csv("data/pitcher_summary.csv", show_col_types = FALSE) |>
  filter(!is.na(avg_release_speed), !is.na(avg_release_spin_rate)) |>
  slice_head(n = 400) |>
  mutate(across(c(avg_release_speed, avg_release_spin_rate),
                ~ as.numeric(scale(.x))))

t0 <- Sys.time()
fit <- brm(
  n_whiffs | trials(n_swings) ~ avg_release_speed + avg_release_spin_rate +
    (1 + avg_release_speed | pitch_name),
  data = d, family = beta_binomial(),
  chains = 2, iter = 400, warmup = 250, seed = 1, refresh = 0,
  backend = "rstan"
)
cat("elapsed:", round(difftime(Sys.time(), t0, units = "secs")), "s\n")
print(summary(fit)$fixed)
cat("\n-- posterior_linpred dims --\n"); print(dim(posterior_linpred(fit)))
cat("-- posterior_epred dims --\n");   print(dim(posterior_epred(fit)))
cat("-- family pars --\n"); print(variables(fit)[1:12])
l <- loo(fit); print(l$estimates)
cat("max pareto k:", max(l$diagnostics$pareto_k), "\n")
