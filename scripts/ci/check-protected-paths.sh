#!/usr/bin/env bash
###############################################################################
# scripts/ci/check-protected-paths.sh — Guard für geschützte Pfade
#
# Extrahiert aus .github/workflows/guard-protected-paths.yml (single source of
# truth). Liest die Liste geänderter Pfade von stdin (eine je Zeile) und blockt,
# wenn ein geschützter Pfad betroffen ist — außer OVERRIDE=true.
#
# Geschützt: Agent-Konfiguration (.claude/), CI (.github/), Framework-Protokoll
# (CLAUDE.md, docs/PROTOCOL.md) und Framework-Skripte (Gates dürfen nicht
# abgeschwächt werden), inkl. scripts/ci/ und scripts/measure-run.sh.
#
# Aufruf:
#   git diff --name-only base...HEAD | OVERRIDE=false scripts/ci/check-protected-paths.sh
#   printf '%s\n' src/a.py | scripts/ci/check-protected-paths.sh   # OVERRIDE default false
#
# Exit: 0 = erlaubt (nichts geschützt ODER Override), 1 = geblockt.
###############################################################################
set -euo pipefail

OVERRIDE="${OVERRIDE:-false}"

PROTECTED_RE='^(\.claude/|\.github/|CLAUDE\.md$|docs/PROTOCOL\.md$|scripts/(glossar_gate|preflight|preflight-calibrate|preflight-dedup|measure-run)\.sh$|scripts/ci/)'

CHANGED=$(cat)
BLOCKED=$(printf '%s\n' "$CHANGED" | grep -E "$PROTECTED_RE" || true)

if [ -z "$BLOCKED" ]; then
  echo "Keine geschützten Pfade betroffen."
  exit 0
fi

echo "Betroffene geschützte Pfade:"
echo "$BLOCKED"

if [ "$OVERRIDE" = "true" ]; then
  echo "human-override:protected-paths gesetzt — Änderungen erlaubt."
  echo "Überprüfe manuell, ob die Änderungen beabsichtigt sind."
  exit 0
fi

echo ""
echo "FEHLER: Änderungen an geschützten Pfaden erfordern das Label"
echo "'human-override:protected-paths' (nur durch den Menschen setzbar)."
exit 1
