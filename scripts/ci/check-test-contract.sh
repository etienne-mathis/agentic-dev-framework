#!/usr/bin/env bash
###############################################################################
# scripts/ci/check-test-contract.sh — Acceptance-Contract-Immutabilität
#
# Extrahiert aus .github/workflows/guard-test-contract.yml (single source of
# truth). Reine Regel-Logik gegen das aktuelle git-Repo; das Umfeld-Glue
# (origin-Fetch, Label→OVERRIDE) bleibt im Workflow.
#
# Aufruf:
#   OVERRIDE=<true|false> scripts/ci/check-test-contract.sh <story-nr> <base-ref>
#     <base-ref> = auflösbare Basis (z. B. main oder origin/main)
#   Leere <story-nr> → Guard übersprungen (kein story-Branch).
#
# Regeln:
#   1. Contract-Verzeichnis tests/acceptance/story_<nr>/ muss existieren.
#   2. Der erste Commit, der DIR berührt, darf NUR tests/ anfassen.
#   3. Nach dem letzten 'add|revise acceptance contract'-Commit darf DIR nicht
#      mehr verändert worden sein (trennt bewusste Revision von stiller Änderung).
#   4. Revisionen erfordern OVERRIDE=true (Label human-override:test-contract).
#
# Exit: 0 = intakt, 1 = Verletzung.
###############################################################################
set -euo pipefail

NR="${1:-}"; BASE="${2:-}"
OVERRIDE="${OVERRIDE:-false}"

if [ -z "$NR" ]; then
  echo "Kein story/-Branch — Guard übersprungen."
  exit 0
fi
[ -z "$BASE" ] && { echo "FEHLER: <base-ref> fehlt." >&2; exit 2; }

DIR="tests/acceptance/story_${NR}"
RANGE="${BASE}...HEAD"

# Regel 1: Contract-Verzeichnis muss existieren.
if [ ! -d "$DIR" ]; then
  echo "::error::Acceptance-Contract fehlt: $DIR"
  echo "Der test-author-Subagent muss vor der Implementierung laufen."
  exit 1
fi

# Regel 2: Der erste Commit, der DIR berührt, darf NUR tests/ anfassen.
FIRST=$(git log --reverse --format='%H' $RANGE -- "$DIR" | head -1)
if [ -n "$FIRST" ]; then
  BAD=$(git show --name-only --format= "$FIRST" | grep -v '^tests/' | grep -v '^$' || true)
  if [ -n "$BAD" ]; then
    echo "::error::Contract-Commit ist nicht rein (nur tests/ erlaubt):"
    echo "$BAD"
    exit 1
  fi
fi

# Regel 3: Baseline = letzter 'add|revise acceptance contract'-Commit;
# danach darf DIR nicht mehr verändert worden sein.
BASE_COMMIT=$(git log --format='%H %s' $RANGE -- "$DIR" \
  | grep -E ' test(\(.+\))?: (add|revise) acceptance contract' \
  | head -1 | awk '{print $1}')

if [ -z "$BASE_COMMIT" ]; then
  echo "::error::Kein Contract-Commit nach Konvention gefunden."
  echo "Erwartet: 'test(<modul>): add acceptance contract for #${NR} [AC-1..AC-n]'"
  exit 1
fi

CHANGED=$(git diff "$BASE_COMMIT"..HEAD -- "$DIR")
if [ -n "$CHANGED" ]; then
  echo "::error::Contract wurde nach dem Baseline-Commit verändert."
  echo "Revisionen erfordern human-override:test-contract + revise-Commit."
  exit 1
fi

# Regel 4: Revisionen erfordern menschliches Override.
REVISED=$(git log --format='%s' $RANGE -- "$DIR" | grep -c 'revise acceptance contract' || true)
if [ "$REVISED" -gt 0 ] && [ "$OVERRIDE" != "true" ]; then
  echo "::error::Contract-Revision ohne Label 'human-override:test-contract'."
  echo "Label nur durch den Menschen setzbar."
  exit 1
fi

echo "OK — Acceptance-Contract intakt."
