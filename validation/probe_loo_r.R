suppressMessages({library(brms); library(dplyr); library(readr); library(loo)})
options(mc.cores = 2); rstan::rstan_options(auto_write = TRUE)

d <- read_csv("data/pitcher_summary.csv", show_col_types = FALSE) |>
  filter(!is.na(avg_release_speed), !is.na(avg_release_spin_rate)) |>
  slice_head(n = 400) |>
  mutate(across(c(avg_release_speed, avg_release_spin_rate), ~ as.numeric(scale(.x))))

fit <- brm(n_whiffs | trials(n_swings) ~ avg_release_speed + avg_release_spin_rate +
             (1 + avg_release_speed || pitch_name),
           data = d, family = beta_binomial(),
           chains = 2, iter = 400, warmup = 250, seed = 1, refresh = 0)
saveRDS(fit, "probe_fit.rds")

cat("\n=== route A: loo(fit) ===\n")
print(try(loo(fit), silent = TRUE)[1])
cat("\n=== route B: loo(fit, cores = 1) ===\n")
rA <- try(loo(fit, cores = 1), silent = TRUE)
cat(if (inherits(rA,"try-error")) paste("FAIL:", rA) else "OK\n")

cat("\n=== route C: manual log_lik + relative_eff ===\n")
rC <- try({
  ll <- log_lik(fit)
  cat("log_lik dims:", dim(ll), " class:", class(ll), "\n")
  nchain <- nchains(fit); nd <- nrow(ll) / nchain
  cid <- rep(seq_len(nchain), each = nd)
  reff <- loo::relative_eff(exp(ll), chain_id = cid, cores = 1)
  loo::loo(ll, r_eff = reff, cores = 1)
}, silent = TRUE)
if (inherits(rC, "try-error")) cat("FAIL:", rC, "\n") else {
  print(rC$estimates)
  cat("max pareto k:", max(rC$diagnostics$pareto_k), "\n")
}
