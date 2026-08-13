#!/usr/bin/env bash
###############################################################################
# scripts/ci/read-block-ab.sh — audit-Schwellwert aus CLAUDE.md lesen
#
# Extrahiert aus setup/ci.yml.example (audit-Job). Behebt strukturell E2E-Bug 3:
# der Wert wurde mehrzeilig / mit Inline-Kommentar extrahiert und zerstörte
# GITHUB_OUTPUT. Fix: genau EIN Wert direkt nach 'block_ab:', Kommentar
# (# critical | high | medium | low) wird verworfen; leer → Default 'high'.
#
# Aufruf:
#   scripts/ci/read-block-ab.sh [--npm] [PfadZuCLAUDE.md]
#     --npm   npm audit kennt kein 'medium' → auf 'moderate' mappen.
#   Ohne Pfad wird ./CLAUDE.md verwendet.
#
# Gibt genau einen Wert auf stdout aus (kein Newline-Rauschen).
###############################################################################
set -euo pipefail

NPM=0; FILE="CLAUDE.md"
while [ $# -gt 0 ]; do
  case "$1" in
    --npm)     NPM=1; shift ;;
    -h|--help) grep '^#' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *)         FILE="$1"; shift ;;
  esac
done

[ -f "$FILE" ] || { echo "FEHLER: Datei nicht gefunden: $FILE" >&2; exit 2; }

# Nur den Wert direkt nach 'block_ab:' — Kommentar darf nicht mitgelesen werden.
BLOCK_AB=$(sed -n 's/^[[:space:]]*block_ab:[[:space:]]*\([a-z]*\).*/\1/p' "$FILE" | head -1)
[ -z "$BLOCK_AB" ] && BLOCK_AB=high

# npm audit nutzt 'moderate' statt 'medium'.
if [ "$NPM" -eq 1 ] && [ "$BLOCK_AB" = "medium" ]; then
  BLOCK_AB=moderate
fi

printf '%s' "$BLOCK_AB"
