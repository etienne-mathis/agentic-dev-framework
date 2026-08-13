#!/usr/bin/env bash
###############################################################################
# experiment/collect.sh — aggregiert experiment/results.tsv (P3.4)
#
# Rechnet aus den Rohzeilen je Arm (A=Framework, B=Single-AI) und je Komplexität
# die Kennzahlen für experiment/REPORT.md aus. Rein lesend, deterministisch.
#
# Aufruf: experiment/collect.sh [results.tsv]   (Default experiment/results.tsv)
#
# Spalten der results.tsv (tab-getrennt, '#'-Zeilen = Header/Kommentar):
#   task_id arm komplexitaet in_tokens out_tokens cache_read wall_clock_s
#   zyklen menschl_eingriffe findings escaped_defects ci_gruen coverage_pct
#   konvention_ok notiz
###############################################################################
set -uo pipefail

FILE="${1:-experiment/results.tsv}"
[ -f "$FILE" ] || { echo "FEHLER: $FILE nicht gefunden." >&2; exit 1; }

FILE="$FILE" python3 - <<'PYEOF'
import os, statistics as st

path = os.environ["FILE"]
rows = []
with open(path, encoding="utf-8") as fh:
    for line in fh:
        line = line.rstrip("\n")
        if not line or line.startswith("#"):
            continue
        c = line.split("\t")
        if len(c) < 14:
            continue
        rows.append({
            "task": c[0], "arm": c[1], "kplx": c[2],
            "in": int(c[3] or 0), "out": int(c[4] or 0), "cache": int(c[5] or 0),
            "wall": int(c[6] or 0), "zyklen": int(c[7] or 0), "eingriffe": int(c[8] or 0),
            "findings": int(c[9] or 0), "escaped": int(c[10] or 0),
            "ci": (c[11] or "").strip().lower(), "cov": c[12].strip(),
            "konv": (c[13] or "").strip().lower(),
        })

if not rows:
    print("Keine Datenzeilen in results.tsv — der Doppel-Lauf ist noch nicht erfasst.")
    raise SystemExit(0)

def med(xs): return int(st.median(xs)) if xs else 0
def summ(sel):
    r = [x for x in rows if sel(x)]
    if not r: return None
    covs = [float(x["cov"]) for x in r if x["cov"] not in ("", "-", "n/a")]
    return {
        "n": len(r),
        "tok_sum": sum(x["in"] + x["out"] for x in r),
        "tok_med": med([x["in"] + x["out"] for x in r]),
        "wall_med": med([x["wall"] for x in r]),
        "zyklen": sum(x["zyklen"] for x in r),
        "eingriffe": sum(x["eingriffe"] for x in r),
        "findings": sum(x["findings"] for x in r),
        "escaped": sum(x["escaped"] for x in r),
        "ci_ok": sum(1 for x in r if x["ci"] in ("ja", "true", "1", "gruen", "grün")),
        "cov_avg": round(sum(covs) / len(covs), 1) if covs else "-",
        "konv_ok": sum(1 for x in r if x["konv"] in ("ja", "true", "1", "ok")),
    }

def row(label, s):
    if not s:
        print(f"| {label} | – | – | – | – | – | – | – | – | – | – |"); return
    print(f"| {label} | {s['n']} | {s['tok_sum']} | {s['tok_med']} | {s['wall_med']} | "
          f"{s['zyklen']} | {s['eingriffe']} | {s['findings']} | {s['escaped']} | "
          f"{s['ci_ok']}/{s['n']} | {s['konv_ok']}/{s['n']} |")

print("### Gesamt je Arm\n")
print("| Arm | n | Tokens Σ | Tokens med | Wall med (s) | Zyklen Σ | Eingriffe Σ | "
      "Findings Σ | Escaped Σ | CI grün | Konv. ok |")
print("|---|---|---|---|---|---|---|---|---|---|---|")
row("A (Framework)", summ(lambda x: x["arm"].upper() == "A"))
row("B (Single-AI)", summ(lambda x: x["arm"].upper() == "B"))

print("\n### Je Komplexität × Arm\n")
print("| Komplexität | Arm | n | Tokens Σ | Tokens med | Wall med (s) | Zyklen Σ | "
      "Eingriffe Σ | Findings Σ | Escaped Σ | CI grün | Konv. ok |")
print("|---|---|---|---|---|---|---|---|---|---|---|---|")
for k in ("trivial", "mittel", "komplex"):
    for arm in ("A", "B"):
        s = summ(lambda x, k=k, arm=arm: x["kplx"].lower() == k and x["arm"].upper() == arm)
        if s:
            print(f"| {k} | {arm} | {s['n']} | {s['tok_sum']} | {s['tok_med']} | {s['wall_med']} | "
                  f"{s['zyklen']} | {s['eingriffe']} | {s['findings']} | {s['escaped']} | "
                  f"{s['ci_ok']}/{s['n']} | {s['konv_ok']}/{s['n']} |")

# Kernaussage: escaped defects (Qualität) und Tokens (Kosten) gegenüberstellen.
a = summ(lambda x: x["arm"].upper() == "A")
b = summ(lambda x: x["arm"].upper() == "B")
if a and b:
    print("\n### Kern-Gegenüberstellung\n")
    print(f"- Escaped defects: Arm A = {a['escaped']} · Arm B = {b['escaped']}")
    print(f"- Menschliche Eingriffe: Arm A = {a['eingriffe']} · Arm B = {b['eingriffe']}")
    print(f"- Tokens gesamt: Arm A = {a['tok_sum']} · Arm B = {b['tok_sum']}")
    if b["tok_sum"]:
        ratio = round(a["tok_sum"] / b["tok_sum"], 2)
        print(f"- Token-Verhältnis A/B = {ratio}× "
              f"({'Framework teurer' if ratio > 1 else 'Framework günstiger'})")
PYEOF
