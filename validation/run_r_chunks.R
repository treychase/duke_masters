# Execute the notebook's R cleaning/aggregation chunks against the synthetic
# pitch-level frame, then compare with the Python mirror in build_summary.py.
suppressMessages({library(dplyr); library(tidyr); library(readr); library(purrr)})

set.seed(1)
data <- read_csv("synthetic_statcast.csv", show_col_types = FALSE)

# Statcast keys the notebook dedupes on; the generator does not emit them.
n <- nrow(data)
data$game_pk        <- rep(seq_len(ceiling(n / 300)), length.out = n)
data$at_bat_number  <- rep(seq_len(80), length.out = n)
data$pitch_number   <- ave(seq_len(n), paste(data$game_pk, data$at_bat_number), FUN = seq_along)

DATA_DIR <- "r_out"; dir.create(DATA_DIR, showWarnings = FALSE)
SUMMARY_PATH <- file.path(DATA_DIR, "pitcher_summary.csv")

source("r_chunks_extracted.R", echo = FALSE)

cat("\n--- R pitcher_summary ---\n")
cat("rows:", nrow(pitcher_summary), "\n")
print(summary(pitcher_summary$whiff_rate))
print(summary(pitcher_summary$run_value))

py <- read_csv("pitcher_summary.csv", show_col_types = FALSE)
cmp <- inner_join(
  pitcher_summary |> select(pitch_name, player_name, r_wr = whiff_rate,
                            r_rv = run_value, r_n = n_pitches, r_speed = avg_release_speed,
                            r_pfx_x = avg_pfx_x),
  py |> select(pitch_name, player_name, p_wr = whiff_rate, p_rv = run_value,
               p_n = n_pitches, p_speed = avg_release_speed, p_pfx_x = avg_pfx_x),
  by = c("pitch_name", "player_name")
)
cat("\n--- cross-check vs Python mirror ---\n")
cat("matched rows:", nrow(cmp), "of", nrow(pitcher_summary), "(R) /", nrow(py), "(py)\n")
cat("max |whiff_rate diff| :", max(abs(cmp$r_wr - cmp$p_wr)), "\n")
cat("max |run_value diff|  :", max(abs(cmp$r_rv - cmp$p_rv)), "\n")
cat("max |n_pitches diff|  :", max(abs(cmp$r_n - cmp$p_n)), "\n")
cat("max |avg_speed diff|  :", max(abs(cmp$r_speed - cmp$p_speed)), "\n")
cat("max |avg_pfx_x diff|  :", max(abs(cmp$r_pfx_x - cmp$p_pfx_x)), "\n")
