#!/usr/bin/env bash
###############################################################################
# tests/framework/run.sh — Selbsttest-Harness des Frameworks (P3.1)
#
# Testet die extrahierte Guard-/CI-Logik (scripts/ci/*.sh) und die Kern-
# Preflight-Skripte gegen synthetische Fixtures — inklusive der drei
# historischen E2E-Bugs als Regressions-Beweis. Deckt beide Stacks ab
# (python UND node) über die golden projects unter tests/framework/golden/.
#
# Zero-Infra: reines bash, kein bats, keine externen Abhängigkeiten außer
# git, sed, awk, grep, python3 (alle im CI ohnehin vorhanden).
#
# Aufruf:
#   tests/framework/run.sh            # alle Suites
#   tests/framework/run.sh contract   # nur test_*contract*.sh
#
# Exit: 0 = alle grün, 1 = mindestens ein Fehlschlag.
###############################################################################
set -uo pipefail   # bewusst KEIN -e: die assert-Helfer behandeln Fehlschläge selbst.

HERE=$(cd "$(dirname "$0")" && pwd)
ROOT=$(cd "$HERE/../.." && pwd)
export ROOT
export CI="$ROOT/scripts/ci"
export SCRIPTS="$ROOT/scripts"
export FIX="$HERE/fixtures"
export GOLDEN="$HERE/golden"

# shellcheck source=tests/framework/assert.sh
source "$HERE/assert.sh"

printf '╔══════════════════════════════════════════════════════════╗\n'
printf '║  Framework-Selbsttest-Harness                            ║\n'
printf '║  Repo: %-50s║\n' "$ROOT"
printf '╚══════════════════════════════════════════════════════════╝\n'

FILTER="${1:-}"
for t in "$HERE"/test_*.sh; do
  [ -e "$t" ] || continue
  name=$(basename "$t")
  if [ -n "$FILTER" ]; then
    case "$name" in *"$FILTER"*) ;; *) continue ;; esac
  fi
  # shellcheck disable=SC1090
  source "$t"
done

assert_summary
