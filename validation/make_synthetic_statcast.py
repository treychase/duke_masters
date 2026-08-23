"""
Generate a synthetic, Statcast-shaped pitch-level dataset.

This exists ONLY so the Python modeling chunks in mlb_statcast.qmd can be
executed and checked end-to-end in environments with no Baseball Savant
access. Column names, dtypes, units and missingness patterns mirror
`baseballr::scrape_statcast_savant(player_type = "pitcher")`; the numbers
are simulated and carry no baseball meaning.
"""

import numpy as np
import pandas as pd

RNG = np.random.default_rng(20260823)

# (pitch_name, mean velo, velo sd, mean pfx_x arm-side ft, mean pfx_z ft, mean spin)
PITCH_TYPES = [
    ("4-Seam Fastball", 94.0, 2.1, 0.62, 1.40, 2300, 0.235),
    ("Sinker",          93.0, 2.0, 1.30, 0.75, 2150, 0.155),
    ("Cutter",          89.5, 2.0, -0.15, 0.75, 2400, 0.245),
    ("Slider",          85.0, 2.6, -0.75, 0.10, 2450, 0.355),
    ("Sweeper",         81.5, 2.4, -1.35, 0.05, 2600, 0.365),
    ("Curveball",       79.0, 2.7, -0.90, -0.65, 2600, 0.330),
    ("Knuckle Curve",   80.5, 2.5, -0.80, -0.50, 2650, 0.325),
    ("Slurve",          81.0, 2.5, -1.10, -0.30, 2550, 0.330),
    ("Split-Finger",    86.5, 2.2, 0.70, 0.10, 1500, 0.395),
    ("Changeup",        85.0, 2.3, 1.15, 0.35, 1800, 0.310),
    ("Forkball",        83.0, 2.0, 0.60, 0.05, 1300, 0.330),
    ("Eephus",          58.0, 4.0, 0.30, -1.20, 1400, 0.200),
    ("Knuckleball",     70.0, 3.0, 0.10, 0.10,  900, 0.260),
    ("Slow Curve",      68.0, 3.0, -0.70, -1.10, 2200, 0.280),
]

N_PITCHERS = 300


def _pitcher_frame():
    ids = np.arange(1, N_PITCHERS + 1)
    return pd.DataFrame({
        "pitcher": 600000 + ids,
        "player_name": [f"Sim{i:03d}, Pitcher" for i in ids],
        "p_throws": RNG.choice(["R", "L"], N_PITCHERS, p=[0.72, 0.28]),
        # latent per-pitcher talent, shifts both whiff propensity and run value
        "talent": RNG.normal(0, 0.30, N_PITCHERS),
        "velo_shift": RNG.normal(0, 1.7, N_PITCHERS),
        "ext_base": RNG.normal(6.4, 0.32, N_PITCHERS),
        "arm_base": RNG.normal(42, 13, N_PITCHERS).clip(0, 90),
    })


def simulate(n_pitch_rows=140_000):
    pit = _pitcher_frame()
    pidx = RNG.integers(0, N_PITCHERS, n_pitch_rows)
    tidx = RNG.integers(0, len(PITCH_TYPES), n_pitch_rows)
    # make arsenal realistic: fastballs far more common than Eephus
    weights = np.array([0.30, 0.14, 0.07, 0.15, 0.07, 0.07, 0.03,
                        0.01, 0.03, 0.11, 0.005, 0.002, 0.003, 0.005])
    tidx = RNG.choice(len(PITCH_TYPES), n_pitch_rows, p=weights / weights.sum())

    names = np.array([p[0] for p in PITCH_TYPES])
    mv = np.array([p[1] for p in PITCH_TYPES])
    sv = np.array([p[2] for p in PITCH_TYPES])
    mx = np.array([p[3] for p in PITCH_TYPES])
    mz = np.array([p[4] for p in PITCH_TYPES])
    ms = np.array([p[5] for p in PITCH_TYPES])
    mw = np.array([p[6] for p in PITCH_TYPES])

    throws = pit["p_throws"].to_numpy()[pidx]
    sign = np.where(throws == "R", 1.0, -1.0)   # arm-side -> raw pfx_x sign

    velo = RNG.normal(mv[tidx] + pit["velo_shift"].to_numpy()[pidx], sv[tidx])
    ext = RNG.normal(pit["ext_base"].to_numpy()[pidx], 0.18)
    arm = RNG.normal(pit["arm_base"].to_numpy()[pidx], 4.0).clip(-10, 95)
    spin = RNG.normal(ms[tidx] + 60 * pit["talent"].to_numpy()[pidx], 180).clip(300, 3600)

    pfx_x_arm = RNG.normal(mx[tidx], 0.30)      # arm-side convention
    pfx_z = RNG.normal(mz[tidx], 0.30)
    rel_x_arm = RNG.normal(1.9 - 0.014 * arm, 0.35)
    rel_z = RNG.normal(4.4 + 0.012 * arm, 0.35)

    # ---- latent pitch quality: deliberately NON-linear in velo and pfx_z ----
    z_velo = (velo - mv[tidx]) / sv[tidx]
    lin = (
        0.30 * z_velo
        + 0.22 * (spin - ms[tidx]) / 200
        + 0.18 * (ext - 6.4) / 0.3
        + 0.20 * np.abs(pfx_x_arm - mx[tidx])
        + pit["talent"].to_numpy()[pidx]
    )
    nonlin = 0.14 * z_velo**2 - 0.16 * (pfx_z - mz[tidx]) ** 2
    quality = lin + nonlin

    p_swing = 1 / (1 + np.exp(-(0.05 + 0.25 * z_velo)))
    p_swing = np.clip(p_swing * 0.94, 0.05, 0.95)
    swing = RNG.random(n_pitch_rows) < p_swing

    logit_whiff = np.log(mw[tidx] / (1 - mw[tidx])) + 0.85 * quality
    whiff = swing & (RNG.random(n_pitch_rows) < 1 / (1 + np.exp(-logit_whiff)))

    desc = np.where(
        whiff, "swinging_strike",
        np.where(swing,
                 RNG.choice(["foul", "hit_into_play", "foul_tip"], n_pitch_rows, p=[0.55, 0.40, 0.05]),
                 RNG.choice(["ball", "called_strike", "blocked_ball"], n_pitch_rows, p=[0.55, 0.40, 0.05])),
    )

    # run value: better stuff -> more negative delta_run_exp for the pitcher
    delta_run_exp = RNG.normal(-0.010 * quality, 0.115)
    delta_run_exp = np.where(desc == "hit_into_play",
                             delta_run_exp + RNG.normal(0.10, 0.45, n_pitch_rows),
                             delta_run_exp)

    df = pd.DataFrame({
        "player_name": pit["player_name"].to_numpy()[pidx],
        "pitcher": pit["pitcher"].to_numpy()[pidx],
        "p_throws": throws,
        "stand": RNG.choice(["R", "L"], n_pitch_rows, p=[0.55, 0.45]),
        "pitch_name": names[tidx],
        "release_speed": velo.round(1),
        "release_pos_x": (sign * rel_x_arm).round(2),
        "release_pos_z": rel_z.round(2),
        "release_spin_rate": spin.round(0),
        "release_extension": ext.round(2),
        "spin_axis": RNG.integers(0, 360, n_pitch_rows),
        "arm_angle": arm.round(1),
        "pfx_x": (sign * pfx_x_arm).round(2),
        "pfx_z": pfx_z.round(2),
        "plate_x": RNG.normal(0, 0.85, n_pitch_rows).round(2),
        "plate_z": RNG.normal(2.4, 0.75, n_pitch_rows).round(2),
        "description": desc,
        "delta_run_exp": delta_run_exp.round(4),
    })

    # Statcast missingness: arm_angle and spin are absent for a slice of rows,
    # and a handful of pitchers are missing arm_angle entirely -- this is what
    # produced the "'data' contains 5 incomplete rows" failure.
    df.loc[RNG.random(len(df)) < 0.02, "release_spin_rate"] = np.nan
    df.loc[RNG.random(len(df)) < 0.03, "arm_angle"] = np.nan
    dead = RNG.choice(pit["player_name"], 5, replace=False)
    df.loc[df["player_name"].isin(dead), "arm_angle"] = np.nan
    df.loc[RNG.random(len(df)) < 0.005, "release_extension"] = np.nan
    return df


if __name__ == "__main__":
    out = simulate()
    out.to_csv("synthetic_statcast.csv", index=False)
    print(out.shape)
    print(out["pitch_name"].value_counts())
