#!/usr/bin/env bash
###############################################################################
# scripts/ci/auto-merge-gate.sh — reine Gate-Logik für Auto-Merge (P3.2)
#
# Behebt Problem 1 (keine echte Autonomie) OHNE den USP (Kontrolle/Auditier-
# barkeit) aufzugeben: Auto-Merge ist eine bewusste Opt-in-Entscheidung pro
# Projekt (autonomy: autonomous). Diese Datei entscheidet NUR go/no-go; das
# eigentliche `gh pr merge` bleibt im Workflow (auto-merge.yml).
#
# Getrennte, testbare Logik (Selbsttest-Harness: test_auto_merge_gate.sh).
#
# Eingaben:
#   stdin           = PR-Labels, ein Name je Zeile
#   --autonomy VAL  = supervised | autonomous (aus read-autonomy.sh)
#   --checks VAL    = success | failure | pending | unknown (Required-Checks-Rollup)
#
# Merge NUR wenn ALLE gelten:
#   autonomy=autonomous · status:approved · KEIN needs-human ·
#   KEIN human-override:* · KEIN merge-hold · checks=success
#
# Exit: 0 = MERGE (Grund auf stdout), 10 = HOLD (Grund auf stdout).
###############################################################################
set -uo pipefail

AUTONOMY="supervised"; CHECKS="unknown"
while [ $# -gt 0 ]; do
  case "$1" in
    --autonomy) AUTONOMY="$2"; shift 2 ;;
    --checks)   CHECKS="$2"; shift 2 ;;
    -h|--help)  grep '^#' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *)          echo "Unbekanntes Argument: $1" >&2; exit 2 ;;
  esac
done

LABELS=$(cat)
has()        { printf '%s\n' "$LABELS" | grep -qx "$1"; }
has_prefix() { printf '%s\n' "$LABELS" | grep -q "^$1"; }
hold()       { echo "HOLD: $1"; exit 10; }

[ "$AUTONOMY" = "autonomous" ] || hold "autonomy != autonomous (supervised → Mensch mergt)"
has "status:approved"          || hold "kein status:approved"
has "needs-human"              && hold "needs-human gesetzt"
has_prefix "human-override:"   && hold "human-override:* gesetzt"
has "merge-hold"               && hold "merge-hold gesetzt"
[ "$CHECKS" = "success" ]      || hold "Required Checks nicht grün (state=$CHECKS)"

echo "MERGE: autonom + approved + alle Checks grün + kein Blocker-Label"
exit 0
