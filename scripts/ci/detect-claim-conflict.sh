#!/usr/bin/env bash
###############################################################################
# scripts/ci/detect-claim-conflict.sh — Label-Race-Detektion (P3.3, Problem 6)
#
# GitHub-Labels sind kein atomarer Lock. Statt Overengineering (verteilter Lock
# bricht Zero-Infra) formalisieren wir die real vorhandene Sequenzialität und
# machen Verletzungen SICHTBAR: zwei CLAIMs auf DEMSELBEN Objekt innerhalb eines
# kurzen Fensters OHNE dazwischenliegenden HANDOFF sind ein Race → needs-human.
# Detektion statt Verhinderung — ehrlich und ausreichend für Single-Operator.
#
# Ein legitimer sequenzieller Handoff (reviewer → cso) ist durch einen
# `### HANDOFF`-Block getrennt und wird NICHT als Konflikt gewertet.
#
# Eingabe (stdin): alle Kommentare des Objekts, ein Kommentar je Zeile, TSV:
#   <created_at-ISO> \t <author-login> \t <erste-Kommentarzeile>
# Reihenfolge egal (wird intern nach Zeit sortiert).
#
# Optionen:
#   --window <sekunden>   Konfliktfenster (Default 180)
#
# Exit: 0 = OK (kein Race), 10 = CONFLICT (Detail auf stdout).
###############################################################################
set -uo pipefail

WINDOW=180
while [ $# -gt 0 ]; do
  case "$1" in
    --window)  WINDOW="$2"; shift 2 ;;
    -h|--help) grep '^#' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *)         echo "Unbekanntes Argument: $1" >&2; exit 2 ;;
  esac
done

# stdin (Kommentar-TSV) einlesen und via Env übergeben — der Heredoc unten belegt
# stdin als Python-PROGRAMM, daher kann sys.stdin nicht die Daten tragen.
INPUT_TSV=$(cat)

WINDOW="$WINDOW" INPUT_TSV="$INPUT_TSV" python3 - <<'PYEOF'
import sys, os, re
from datetime import datetime, timezone

window = int(os.environ.get("WINDOW", "180"))

def epoch(s):
    s = s.strip().replace("Z", "+00:00")
    try:
        dt = datetime.fromisoformat(s)
    except ValueError:
        return None
    if dt.tzinfo is None:
        dt = dt.replace(tzinfo=timezone.utc)
    return dt.timestamp()

claim_re = re.compile(r'^CLAIM\s+(architect|developer|reviewer|cso)\b')
claims = []      # (ts, role, author)
separators = []  # ts von HANDOFF/DECISION/AUTO — legitimer Übergabepunkt

for line in os.environ.get("INPUT_TSV", "").splitlines():
    if not line:
        continue
    parts = line.split("\t")
    if len(parts) < 3:
        # created_at + author vorhanden, aber leere erste Zeile → ignorieren
        continue
    ts_s, author, first = parts[0], parts[1], parts[2]
    ts = epoch(ts_s)
    if ts is None:
        continue
    m = claim_re.match(first)
    if m:
        claims.append((ts, m.group(1), author))
    elif first.startswith("### HANDOFF") or first.startswith("### DECISION") or first.startswith("AUTO:"):
        separators.append(ts)

claims.sort(key=lambda c: c[0])
conflicts = []
for i in range(len(claims) - 1):
    t1, r1, a1 = claims[i]
    t2, r2, a2 = claims[i + 1]
    if (t2 - t1) <= window:
        # Liegt ein legitimer Übergabepunkt dazwischen? Dann kein Konflikt.
        if any(t1 < s <= t2 for s in separators):
            continue
        conflicts.append((r1, a1, r2, a2, int(t2 - t1)))

if conflicts:
    print("CONFLICT: konkurrierende CLAIMs ohne dazwischenliegenden HANDOFF erkannt:")
    for r1, a1, r2, a2, dt in conflicts:
        print(f"  CLAIM {r1} (@{a1}) und CLAIM {r2} (@{a2}) innerhalb {dt}s")
    sys.exit(10)

print("OK — keine konkurrierenden CLAIMs im Fenster.")
sys.exit(0)
PYEOF
