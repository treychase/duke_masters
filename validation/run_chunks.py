"""Extract the ```{python} chunks from mlb_statcast.qmd in order and execute
them against a synthetic pitcher_summary.csv.

Only one thing is overridden: SAMPLE_KW is shrunk so the four MCMC fits finish
in minutes instead of hours. Every other line runs exactly as written in the
notebook.
"""
import re, sys, os, traceback
import matplotlib
matplotlib.use("Agg")

QMD = sys.argv[1] if len(sys.argv) > 1 else "../mlb_statcast.qmd"
FAST = os.environ.get("FAST", "1") == "1"

text = open(QMD).read()
chunks = re.findall(r"^```\{python\}\n(.*?)^```", text, re.S | re.M)
print(f"extracted {len(chunks)} python chunks", flush=True)

def label_of(src):
    m = re.search(r"#\|\s*label:\s*(\S+)", src)
    return m.group(1) if m else "?"

def strip_opts(src):
    return "\n".join(l for l in src.splitlines() if not l.strip().startswith("#|"))

g = {"__name__": "__main__"}
failures = []
for i, raw in enumerate(chunks):
    lbl = label_of(raw)
    code = strip_opts(raw)
    import time as _t
    print(f"\n{'='*70}\n[{i:02d}] {lbl}  ({_t.strftime('%H:%M:%S')})\n{'='*70}", flush=True)
    try:
        exec(compile(code, f"<chunk:{lbl}>", "exec"), g)
    except Exception:
        traceback.print_exc()
        failures.append((i, lbl))
        break
    if lbl == "py-setup" and FAST:
        g["SAMPLE_KW"].update(draws=200, tune=300, chains=2)
        print(">> VALIDATION OVERRIDE:", g["SAMPLE_KW"], flush=True)

print("\n" + "=" * 70)
print("FAILURES:", failures if failures else "none")
sys.exit(1 if failures else 0)
