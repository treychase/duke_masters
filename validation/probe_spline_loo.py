"""Why does the spline model's PSIS-LOO break down, and what fixes it?

On the synthetic data M2 reports p_loo = 14302 against n = 2021, with the
Pareto shape parameter above 0.7 for 98.2% of observations (max k = 7.08). M1,
on the identical log-likelihood code path, is clean (0% bad, max k = 0.53), so
the cause is specific to the spline terms rather than to how the log-likelihood
is computed.

Near-universal k > 0.7 rules out the usual "a few influential observations"
explanation. This script separates the three candidate causes by refitting M2
four ways and reporting the k diagnostic for each:

  df=4, sigma=1.5     the notebook's current settings, as a control
  df=3, sigma=1.5     is the basis simply too flexible?
  df=4, sigma=0.5     is the prior on the spline coefficients too wide?
  df=4, 1000 draws    or is it an artefact of the short validation chain?

Whichever of these restores the diagnostic is the remedy the notebook should
recommend. Run from validation/ after build_summary.py.
"""
import re, numpy as np, pandas as pd, bambi as bmb, arviz as az, pymc as pm

df = pd.read_csv("data/pitcher_summary.csv")
MECH=["avg_release_speed","avg_release_pos_x","avg_release_spin_rate",
      "avg_release_extension","avg_pfx_x","avg_pfx_z"]
df=df.dropna(subset=MECH).reset_index(drop=True)
keep=df.pitch_name.value_counts()[lambda s:s>=25].index
df=df[df.pitch_name.isin(keep)].reset_index(drop=True)
for v in MECH: df[v]=(df[v]-df[v].mean())/df[v].std()
df["pitch_name"]=pd.Categorical(df["pitch_name"])
df["successes"]=df.n_whiffs.astype(int); df["trials"]=df.n_swings.astype(int)
FLAGGED=["avg_release_speed","avg_release_pos_x","avg_release_extension"]

def run(tag, spline_df, sigma, draws=200, tune=300):
    terms=[f"bs({v}, df={spline_df})" if v in FLAGGED else v for v in MECH]
    f=("p(successes, trials) ~ "+" + ".join(terms)
       +" + (1 + "+" + ".join(MECH)+" | pitch_name)")
    pr={t: bmb.Prior("Normal",mu=0,sigma=sigma) for t in terms if t.startswith("bs(")}
    pr["Intercept"]=bmb.Prior("Normal",mu=0,sigma=2.5)
    pr["1|pitch_name"]=bmb.Prior("Normal",mu=0,sigma=bmb.Prior("HalfNormal",sigma=2.5))
    m=bmb.Model(f,df,family="beta_binomial",priors=pr)
    m.set_alias({t:"s_"+re.match(r"bs\((\w+),",t).group(1) for t in terms if t.startswith("bs(")})
    m.build()
    idata=m.fit(draws=draws,tune=tune,chains=2,inference_method="nutpie",
                omit_offsets=False,progressbar=False,random_seed=42,target_accept=0.95)
    with m.backend.model: pm.compute_log_likelihood(idata,extend_inferencedata=True,progressbar=False)
    loo=az.loo(idata,pointwise=True); k=np.asarray(loo.pareto_k); n=k.size
    print(f"{tag:<28} elpd={float(loo.elpd_loo):>10.1f} p_loo={float(loo.p_loo):>9.1f} "
          f"k>0.7={100*(k>0.7).mean():5.1f}%  maxk={k.max():5.2f}", flush=True)

run("df=4 sigma=1.5 (current)", 4, 1.5)
run("df=3 sigma=1.5", 3, 1.5)
run("df=4 sigma=0.5", 4, 0.5)
run("df=4 sigma=1.5 draws=1000", 4, 1.5, draws=1000, tune=1000)
