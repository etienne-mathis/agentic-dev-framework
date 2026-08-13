#!/usr/bin/env bash
###############################################################################
# tests/framework/assert.sh — minimale assert-Helfer (zero-infra, kein bats)
#
# Wird vom Runner (run.sh) in dieselbe Shell gesourct; die Zähler akkumulieren
# über alle test_*.sh hinweg. Jede Assertion erhöht TESTS_RUN, bei Fehlschlag
# zusätzlich TESTS_FAILED.
###############################################################################

TESTS_RUN=0
TESTS_FAILED=0
CUR_SUITE=""

suite() {
  CUR_SUITE="$1"
  printf '\n── %s ──────────────────────────────────────────────\n' "$1"
}

_pass() {
  TESTS_RUN=$((TESTS_RUN + 1))
  printf '  [PASS] %s\n' "$1"
}

_fail() {
  TESTS_RUN=$((TESTS_RUN + 1))
  TESTS_FAILED=$((TESTS_FAILED + 1))
  printf '  [FAIL] %s\n' "$1"
  [ -n "${2:-}" ] && printf '         %s\n' "$2"
}

# assert_eq <expected> <actual> <beschreibung>
assert_eq() {
  if [ "$1" = "$2" ]; then _pass "$3"; else _fail "$3" "erwartet='$1' ist='$2'"; fi
}

# assert_contains <haystack> <needle> <beschreibung>
assert_contains() {
  if printf '%s' "$1" | grep -qF -- "$2"; then _pass "$3"
  else _fail "$3" "Text nicht gefunden: '$2'"; fi
}

# assert_not_contains <haystack> <needle> <beschreibung>
assert_not_contains() {
  if printf '%s' "$1" | grep -qF -- "$2"; then _fail "$3" "unerwartet gefunden: '$2'"
  else _pass "$3"; fi
}

# assert_true <beschreibung> -- <cmd...>   (Exit 0 erwartet)
assert_true() {
  local msg="$1"; shift; [ "$1" = "--" ] && shift
  if "$@" >/dev/null 2>&1; then _pass "$msg"; else _fail "$msg" "Kommando schlug fehl: $*"; fi
}

# assert_false <beschreibung> -- <cmd...>  (Exit != 0 erwartet)
assert_false() {
  local msg="$1"; shift; [ "$1" = "--" ] && shift
  if "$@" >/dev/null 2>&1; then _fail "$msg" "Kommando war unerwartet erfolgreich: $*"; else _pass "$msg"; fi
}

assert_summary() {
  printf '\n══════════════════════════════════════════════════════════\n'
  printf ' Ergebnis: %s Assertions, %s Fehlschläge\n' "$TESTS_RUN" "$TESTS_FAILED"
  printf '══════════════════════════════════════════════════════════\n'
  [ "$TESTS_FAILED" -eq 0 ]
}
