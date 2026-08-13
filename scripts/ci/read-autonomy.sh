#!/usr/bin/env bash
###############################################################################
# scripts/ci/read-autonomy.sh — Autonomie-Modus aus CLAUDE.md lesen (P3.2)
#
# Liest genau den Wert nach 'autonomy:' aus der Projektkonfiguration. Ignoriert
# Inline-Kommentare. Default (und einziger sicherer Fallback): supervised.
# Nur der exakte Wert 'autonomous' aktiviert Auto-Merge — alles andere → supervised.
#
# Aufruf: scripts/ci/read-autonomy.sh [PfadZuCLAUDE.md]   (Default ./CLAUDE.md)
# Gibt genau einen Wert aus: supervised | autonomous
###############################################################################
set -euo pipefail

FILE="${1:-CLAUDE.md}"
[ -f "$FILE" ] || { printf 'supervised'; exit 0; }

VAL=$(sed -n 's/^[[:space:]]*autonomy:[[:space:]]*\([a-z]*\).*/\1/p' "$FILE" | head -1)
if [ "$VAL" = "autonomous" ]; then
  printf 'autonomous'
else
  printf 'supervised'
fi
