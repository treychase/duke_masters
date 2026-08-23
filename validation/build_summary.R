# R mirror of the notebook's aggregation chunk, used to produce a
# pitcher_summary.csv for the Stan probes without running the whole notebook.
suppressMessages({library(dplyr); library(readr); library(tidyr)})

SWING <- c("foul","foul_tip","hit_into_play","swinging_strike",
           "swinging_strike_blocked","missed_bunt","foul_bunt")
WHIFF <- c("swinging_strike","swinging_strike_blocked","missed_bunt")
DROP  <- c("Forkball","Pitch Out","Eephus","Knuckleball","Other",
           "Slow Curve","Unknown","NA")

d <- read_csv("synthetic_statcast.csv", show_col_types = FALSE) |>
  filter(!pitch_name %in% DROP) |>
  mutate(pfx_x = if_else(p_throws == "L", -pfx_x, pfx_x),
         release_pos_x = if_else(p_throws == "L", -release_pos_x, release_pos_x),
         is_swing = description %in% SWING,
         is_whiff = description %in% WHIFF)

s <- d |>
  group_by(pitch_name, player_name) |>
  summarise(
    avg_release_speed     = mean(release_speed, na.rm = TRUE),
    avg_release_pos_x     = mean(release_pos_x, na.rm = TRUE),
    avg_release_pos_z     = mean(release_pos_z, na.rm = TRUE),
    avg_release_spin_rate = mean(release_spin_rate, na.rm = TRUE),
    avg_release_extension = mean(release_extension, na.rm = TRUE),
    avg_arm_angle         = mean(arm_angle, na.rm = TRUE),
    avg_pfx_x             = mean(pfx_x, na.rm = TRUE),
    avg_pfx_z             = mean(pfx_z, na.rm = TRUE),
    n_swings = sum(is_swing), n_whiffs = sum(is_whiff),
    n_pitches = n(), run_value = sum(delta_run_exp, na.rm = TRUE),
    .groups = "drop"
  ) |>
  filter(n_pitches >= 20, n_swings >= 10) |>
  mutate(whiff_rate = n_whiffs / n_swings,
         rv_per_100 = 100 * run_value / n_pitches)

dir.create("data", showWarnings = FALSE)
write_csv(s, "data/pitcher_summary.csv")
cat(nrow(s), "rows\n")
