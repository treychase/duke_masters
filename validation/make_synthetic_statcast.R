# Generate a synthetic, Statcast-shaped pitch-level dataset.
#
# This exists ONLY so the modelling chunks in mlb_statcast.qmd can be executed
# and checked end-to-end in environments with no Baseball Savant access. Column
# names, units and missingness patterns mirror
# `baseballr::scrape_statcast_savant(player_type = "pitcher")`; the numbers are
# simulated and carry no baseball meaning.
suppressMessages({library(dplyr); library(readr)})
set.seed(20260823)

PITCH_TYPES <- tribble(
  ~pitch_name,        ~mv,  ~sv, ~mx,   ~mz,   ~ms,  ~mw,   ~wt,
  "4-Seam Fastball", 94.0, 2.1,  0.62,  1.40, 2300, 0.235, 0.300,
  "Sinker",          93.0, 2.0,  1.30,  0.75, 2150, 0.155, 0.140,
  "Cutter",          89.5, 2.0, -0.15,  0.75, 2400, 0.245, 0.070,
  "Slider",          85.0, 2.6, -0.75,  0.10, 2450, 0.355, 0.150,
  "Sweeper",         81.5, 2.4, -1.35,  0.05, 2600, 0.365, 0.070,
  "Curveball",       79.0, 2.7, -0.90, -0.65, 2600, 0.330, 0.070,
  "Knuckle Curve",   80.5, 2.5, -0.80, -0.50, 2650, 0.325, 0.030,
  "Slurve",          81.0, 2.5, -1.10, -0.30, 2550, 0.330, 0.010,
  "Split-Finger",    86.5, 2.2,  0.70,  0.10, 1500, 0.395, 0.030,
  "Changeup",        85.0, 2.3,  1.15,  0.35, 1800, 0.310, 0.110,
  "Forkball",        83.0, 2.0,  0.60,  0.05, 1300, 0.330, 0.005,
  "Eephus",          58.0, 4.0,  0.30, -1.20, 1400, 0.200, 0.002,
  "Knuckleball",     70.0, 3.0,  0.10,  0.10,  900, 0.260, 0.003,
  "Slow Curve",      68.0, 3.0, -0.70, -1.10, 2200, 0.280, 0.005
)

N_PITCHERS <- 300L
N_ROWS     <- 140000L

pit <- tibble(
  id          = seq_len(N_PITCHERS),
  pitcher     = 600000L + seq_len(N_PITCHERS),
  player_name = sprintf("Sim%03d, Pitcher", seq_len(N_PITCHERS)),
  p_throws    = sample(c("R", "L"), N_PITCHERS, TRUE, c(0.72, 0.28)),
  talent      = rnorm(N_PITCHERS, 0, 0.30),
  velo_shift  = rnorm(N_PITCHERS, 0, 1.7),
  ext_base    = rnorm(N_PITCHERS, 6.4, 0.32),
  arm_base    = pmin(pmax(rnorm(N_PITCHERS, 42, 13), 0), 90)
)

pidx <- sample.int(N_PITCHERS, N_ROWS, replace = TRUE)
tidx <- sample.int(nrow(PITCH_TYPES), N_ROWS, replace = TRUE,
                   prob = PITCH_TYPES$wt / sum(PITCH_TYPES$wt))

throws <- pit$p_throws[pidx]
sgn    <- if_else(throws == "R", 1, -1)   # arm-side -> raw pfx_x sign

mv <- PITCH_TYPES$mv[tidx]; sv <- PITCH_TYPES$sv[tidx]
mx <- PITCH_TYPES$mx[tidx]; mz <- PITCH_TYPES$mz[tidx]
ms <- PITCH_TYPES$ms[tidx]; mw <- PITCH_TYPES$mw[tidx]
talent <- pit$talent[pidx]

velo <- rnorm(N_ROWS, mv + pit$velo_shift[pidx], sv)
ext  <- rnorm(N_ROWS, pit$ext_base[pidx], 0.18)
arm  <- pmin(pmax(rnorm(N_ROWS, pit$arm_base[pidx], 4.0), -10), 95)
spin <- pmin(pmax(rnorm(N_ROWS, ms + 60 * talent, 180), 300), 3600)

pfx_x_arm <- rnorm(N_ROWS, mx, 0.30)      # arm-side convention
pfx_z     <- rnorm(N_ROWS, mz, 0.30)
rel_x_arm <- rnorm(N_ROWS, 1.9 - 0.014 * arm, 0.35)
rel_z     <- rnorm(N_ROWS, 4.4 + 0.012 * arm, 0.35)

# Latent pitch quality: deliberately NON-linear in velocity and vertical break,
# so the linearity tests have something real to find.
z_velo <- (velo - mv) / sv
quality <- 0.30 * z_velo + 0.22 * (spin - ms) / 200 + 0.18 * (ext - 6.4) / 0.3 +
  0.20 * abs(pfx_x_arm - mx) + talent +
  0.14 * z_velo^2 - 0.16 * (pfx_z - mz)^2

p_swing <- pmin(pmax(plogis(0.05 + 0.25 * z_velo) * 0.94, 0.05), 0.95)
swing   <- runif(N_ROWS) < p_swing
whiff   <- swing & (runif(N_ROWS) < plogis(qlogis(mw) + 0.85 * quality))

desc <- if_else(
  whiff, "swinging_strike",
  if_else(swing,
          sample(c("foul", "hit_into_play", "foul_tip"), N_ROWS, TRUE, c(.55, .40, .05)),
          sample(c("ball", "called_strike", "blocked_ball"), N_ROWS, TRUE, c(.55, .40, .05)))
)

dre <- rnorm(N_ROWS, -0.010 * quality, 0.115)
dre <- if_else(desc == "hit_into_play", dre + rnorm(N_ROWS, 0.10, 0.45), dre)

game_pk <- rep_len(seq_len(ceiling(N_ROWS / 300)), N_ROWS)
at_bat  <- rep_len(seq_len(80), N_ROWS)

out <- tibble(
  game_pk, at_bat_number = at_bat,
  pitch_number = ave(seq_len(N_ROWS), paste(game_pk, at_bat), FUN = seq_along),
  player_name = pit$player_name[pidx], pitcher = pit$pitcher[pidx],
  p_throws = throws, stand = sample(c("R", "L"), N_ROWS, TRUE, c(.55, .45)),
  pitch_name = PITCH_TYPES$pitch_name[tidx],
  release_speed = round(velo, 1),
  release_pos_x = round(sgn * rel_x_arm, 2),
  release_pos_z = round(rel_z, 2),
  release_spin_rate = round(spin),
  release_extension = round(ext, 2),
  spin_axis = sample.int(360, N_ROWS, TRUE) - 1L,
  arm_angle = round(arm, 1),
  pfx_x = round(sgn * pfx_x_arm, 2),
  pfx_z = round(pfx_z, 2),
  plate_x = round(rnorm(N_ROWS, 0, 0.85), 2),
  plate_z = round(rnorm(N_ROWS, 2.4, 0.75), 2),
  description = desc,
  delta_run_exp = round(dre, 4)
)

# Statcast missingness: spin and arm_angle are absent for a slice of rows, and a
# few pitchers lack arm_angle entirely -- the latter is what makes a whole group
# average to NaN and produces incomplete rows downstream.
out$release_spin_rate[runif(N_ROWS) < 0.02] <- NA
out$arm_angle[runif(N_ROWS) < 0.03] <- NA
out$release_extension[runif(N_ROWS) < 0.005] <- NA
dead <- sample(pit$player_name, 5)
out$arm_angle[out$player_name %in% dead] <- NA

write_csv(out, "synthetic_statcast.csv")
cat(nrow(out), "rows written\n")
print(count(out, pitch_name, sort = TRUE))
