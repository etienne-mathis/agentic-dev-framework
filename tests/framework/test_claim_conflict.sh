#!/usr/bin/env bash
# test_claim_conflict.sh — Label-Race-Detektion (P3.3).
suite "claim-conflict Detektion (scripts/ci/detect-claim-conflict.sh)"

row() { printf '%s\t%s\t%s\n' "$1" "$2" "$3"; }         # TSV-Zeile: ts, author, firstline
det() { RC=0; OUT=$(printf '%s' "$1" | bash "$CI/detect-claim-conflict.sh" --window 180 2>&1) || RC=$?; }

# 1) Zwei CLAIMs in kurzem Fenster OHNE HANDOFF → CONFLICT.
IN=$(row "2026-08-13T10:00:00Z" alice "CLAIM developer 2026-08-13T10:00:00Z"
     row "2026-08-13T10:00:30Z" bob   "CLAIM developer 2026-08-13T10:00:30Z")
det "$IN"
assert_eq 10 "$RC" "zwei CLAIMs in 30s ohne HANDOFF → CONFLICT"
assert_contains "$OUT" "CONFLICT" "meldet CONFLICT im Klartext"

# 2) Legitime Sequenz reviewer → cso mit HANDOFF dazwischen → OK.
IN=$(row "2026-08-13T10:00:00Z" alice "CLAIM reviewer 2026-08-13T10:00:00Z"
     row "2026-08-13T10:00:20Z" alice "### HANDOFF"
     row "2026-08-13T10:00:40Z" alice "CLAIM cso 2026-08-13T10:00:40Z")
det "$IN"
assert_eq 0 "$RC" "reviewer→cso mit HANDOFF dazwischen → OK (kein Race)"

# 3) Zwei CLAIMs weit auseinander (> Fenster) → OK.
IN=$(row "2026-08-13T10:00:00Z" alice "CLAIM developer 2026-08-13T10:00:00Z"
     row "2026-08-13T10:10:00Z" alice "CLAIM developer 2026-08-13T10:10:00Z")
det "$IN"
assert_eq 0 "$RC" "zwei CLAIMs 600s auseinander (> Fenster) → OK"

# 4) Einzelner CLAIM → OK.
det "$(row "2026-08-13T10:00:00Z" alice "CLAIM developer 2026-08-13T10:00:00Z")"
assert_eq 0 "$RC" "einzelner CLAIM → OK"

# 5) Nur Nicht-CLAIM-Kommentare → OK (werden ignoriert).
IN=$(row "2026-08-13T10:00:00Z" alice "Irgendein Kommentar"
     row "2026-08-13T10:00:05Z" bob   "Noch einer")
det "$IN"
assert_eq 0 "$RC" "keine CLAIMs → OK"

# 6) Drei CLAIMs: HANDOFF nur vor dem zweiten; der dritte racet mit dem zweiten → CONFLICT.
IN=$(row "2026-08-13T10:00:00Z" alice "CLAIM reviewer 2026-08-13T10:00:00Z"
     row "2026-08-13T10:00:20Z" alice "### HANDOFF"
     row "2026-08-13T10:00:40Z" alice "CLAIM cso 2026-08-13T10:00:40Z"
     row "2026-08-13T10:00:50Z" bob   "CLAIM cso 2026-08-13T10:00:50Z")
det "$IN"
assert_eq 10 "$RC" "dritter CLAIM racet mit cso ohne HANDOFF → CONFLICT"
