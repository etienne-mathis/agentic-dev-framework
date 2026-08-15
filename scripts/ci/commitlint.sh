#!/usr/bin/env bash
###############################################################################
# scripts/ci/commitlint.sh — Commit-Message-Konvention (single source of truth)
#
# Extrahiert aus setup/ci.yml.example, damit Workflow UND Selbsttest-Harness
# dieselbe Logik ausführen (kein Copy-Paste-Drift). Behebt strukturell die
# E2E-Bugs (P3.1):
#   - Bug 1: Contract-Commits folgen einer eigenen Konvention und sind zulässig.
#   - Bug 2: Merge-Commits werden übersprungen (--no-merges).
#
# Konvention:  type(scope): kurze beschreibung (#issue-nr)
#   type ∈ feat | fix | refactor | test | docs | chore
# Contract-Ausnahme (erzwungen vom test-contract-Guard, test-author.md):
#   test(<modul>): (add|revise) acceptance contract for #<nr> [AC-…]
#
# Modi:
#   scripts/ci/commitlint.sh --range <base>..<head>   # nutzt git log --no-merges
#   git log … | scripts/ci/commitlint.sh              # liest Messages von stdin
#   scripts/ci/commitlint.sh --message "feat: … (#1)"  # einzelne Message
#
# Exit: 0 = alle gültig, 1 = mindestens eine ungültig.
###############################################################################
set -euo pipefail

# Scope case-insensitiv ([A-Za-z0-9_-]): akzeptiert z. B. `useCart` neben `usecart`.
# Grund (Live-Befund T3, Issue #13): ein lowercase-only-Scope-Pattern verwandelte
# jeden Großbuchstaben-Scope in einen harten Deadlock (Fix nur per History-Rewrite,
# der Agenten verboten ist). Die Konvention „lowercase bevorzugt" bleibt eine
# Empfehlung im Prompt, blockt aber nicht mehr den Merge.
PATTERN='^(feat|fix|refactor|test|docs|chore)(\([A-Za-z0-9_-]+\))?: .{1,100} \(#[0-9]+\)$'
# Acceptance-Contract-Commits folgen einer eigenen, vom test-contract-Guard
# erzwungenen Konvention und sind hier ausdrücklich zulässig:
CONTRACT='^test(\([A-Za-z0-9_-]+\))?: (add|revise) acceptance contract for #[0-9]+( \[AC-.*\])?$'

MODE="stdin"; RANGE=""; SINGLE=""
while [ $# -gt 0 ]; do
  case "$1" in
    --range)   MODE="range"; RANGE="$2"; shift 2 ;;
    --message) MODE="single"; SINGLE="$2"; shift 2 ;;
    -h|--help) grep '^#' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *)         echo "Unbekanntes Argument: $1" >&2; exit 2 ;;
  esac
done

emit_messages() {
  case "$MODE" in
    range)  git log "$RANGE" --no-merges --format="%s" ;;
    single) printf '%s\n' "$SINGLE" ;;
    stdin)  cat ;;
  esac
}

FAILED=0
while IFS= read -r MSG; do
  [ -z "$MSG" ] && continue
  if echo "$MSG" | grep -qE "$PATTERN"; then continue; fi
  if echo "$MSG" | grep -qE "$CONTRACT"; then continue; fi
  echo "::error::Ungültige Commit-Message: '$MSG'" >&2
  echo "  Erwartet: type(scope): kurze beschreibung (#issue-nr)" >&2
  echo "  Typen:    feat | fix | refactor | test | docs | chore" >&2
  FAILED=1
done < <(emit_messages)

[ "$FAILED" -eq 1 ] && exit 1 || { echo "commitlint: all messages valid."; exit 0; }
