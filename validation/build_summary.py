"""Python mirror of the R aggregation chunk, used to produce a
pitcher_summary.csv for validating the modeling code offline."""
import numpy as np, pandas as pd

SWING = {"foul","foul_tip","hit_into_play","swinging_strike",
         "swinging_strike_blocked","missed_bunt","foul_bunt"}
WHIFF = {"swinging_strike","swinging_strike_blocked","missed_bunt"}
DROP_PITCHES = {"Forkball","Pitch Out","Eephus","Knuckleball","Other",
                "Slow Curve","Unknown","NA"}

def build(df):
    df = df[~df["pitch_name"].isin(DROP_PITCHES)].copy()
    lhp = df["p_throws"].eq("L")
    df.loc[lhp, "pfx_x"] = -df.loc[lhp, "pfx_x"]
    df.loc[lhp, "release_pos_x"] = -df.loc[lhp, "release_pos_x"]
    df["is_swing"] = df["description"].isin(SWING)
    df["is_whiff"] = df["description"].isin(WHIFF)
    g = df.groupby(["pitch_name","player_name"], observed=True)
    out = g.agg(
        avg_release_speed=("release_speed","mean"),
        avg_release_pos_x=("release_pos_x","mean"),
        avg_release_pos_z=("release_pos_z","mean"),
        avg_release_spin_rate=("release_spin_rate","mean"),
        avg_release_extension=("release_extension","mean"),
        avg_arm_angle=("arm_angle","mean"),
        avg_pfx_x=("pfx_x","mean"),
        avg_pfx_z=("pfx_z","mean"),
        n_swings=("is_swing","sum"),
        n_whiffs=("is_whiff","sum"),
        run_value=("delta_run_exp","sum"),
        n_pitches=("description","size"),
    ).reset_index()
    out = out[(out.n_pitches>=20)&(out.n_swings>=10)].copy()
    out["whiff_rate"] = out.n_whiffs/out.n_swings
    out["rv_per_100"] = 100*out.run_value/out.n_pitches
    return out

if __name__ == "__main__":
    s = build(pd.read_csv("synthetic_statcast.csv"))
    s.to_csv("pitcher_summary.csv", index=False)
    print(s.shape)
    print("rows with any NA mechanic:",
          s[[c for c in s.columns if c.startswith('avg_')]].isna().any(axis=1).sum())
    print(s[["whiff_rate","run_value","rv_per_100"]].describe().round(3))
