#!/usr/bin/env bash
# test_fastlane.sh — Source-Lock für die Fast-Lane-Fixes (P3.2, Issue #12).
# Die Fast-Lane-Verdrahtung läuft über Agent-Prompts (gh-abhängig, nicht live
# unit-testbar). Diese Suite fixiert die beiden strukturellen Korrekturen gegen
# stille Reversion — genau die Klasse Bug, die der Live-E2E aufdeckte.
suite "Fast-Lane-Fixes (P3.2 Source-Lock)"

REVIEWER="$ROOT/.claude/agents/reviewer.md"
ARCHITECT="$ROOT/.claude/agents/architect.md"

RV=$(cat "$REVIEWER")
AR=$(cat "$ARCHITECT")

# P3.2-B: REVIEWER liest track:fast von der STORY, nicht vom PR.
assert_contains     "$RV" 'FAST=$(gh issue view "$STORY_NR" --json labels' \
  "reviewer liest track:fast von der Story (STORY_NR)"
assert_not_contains "$RV" 'FAST=$(gh pr view <nr> --json labels' \
  "reviewer liest track:fast NICHT mehr vom PR"

# P3.2-A: ARCHITECT-Trigger ist qualitativ, nicht an den Roh-Score gekoppelt.
assert_not_contains "$AR" "Preflight-Score ≤ 2 (Tier Haiku), UND" \
  "architect-Fast-Lane-Trigger ist nicht mehr Score-≤-2-gegated"
assert_contains     "$AR" "eine einzige Produktions-/Implementierungsdatei" \
  "architect-Fast-Lane-Trigger nennt das qualitative Einzeldatei-Kriterium"
