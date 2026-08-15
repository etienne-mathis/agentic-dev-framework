#!/usr/bin/env bash
# test_prompt_policy.sh — Source-Lock für die Produktionsreife-Prompt-Fixes aus dem
# Head-to-Head (Issues #13 Commit-Deadlock, #14 Cycle-Explosion). Die Verdrahtung
# lebt in Agent-Prompts (gh-abhängig, nicht live unit-testbar); diese Suite fixiert
# die Kern-Korrekturen gegen stille Reversion.
suite "Prompt-Policy-Fixes (#13/#14 Source-Lock)"

DEV=$(cat "$ROOT/.claude/agents/developer.md")
REV=$(cat "$ROOT/.claude/agents/reviewer.md")

# #13 — Developer-Self-Check vor Commit + Escape-Hatch.
assert_contains "$DEV" 'bash scripts/ci/commitlint.sh --message' \
  "developer validiert Commit-Message vor dem Commit (Self-Check, #13)"
assert_contains "$DEV" 'force-with-lease' \
  "developer darf eigenen story-Branch rewordten (Escape-Hatch, #13)"

# #14 — nur critical/high blockieren; Re-Review-Scope-Cap.
assert_contains "$REV" 'Nur `critical`/`high`-Findings sind **blockierend**' \
  "reviewer blockt nur bei critical/high (#14)"
assert_contains "$REV" 'kein Scope-Creep' \
  "reviewer verbietet neue medium/low-Nitpicks in späten Cycles (#14)"
