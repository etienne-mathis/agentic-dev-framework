#!/usr/bin/env bash
# test_block_ab.sh — Inline-Kommentar (Bug 3), Default, medium→moderate, kein Newline.
suite "block_ab-Extraktion (scripts/ci/read-block-ab.sh)"

T=$(mktemp -d)

# Bug 3: der Inline-Kommentar darf NICHT mitgelesen werden.
printf 'audit:\n  block_ab: high   # critical | high | medium | low\n' > "$T/c1.md"
assert_eq "high" "$(bash "$CI/read-block-ab.sh" "$T/c1.md")" \
  "Inline-Kommentar ignoriert (Regression Bug 3)"

# Bug 3 (Kern): Ausgabe ohne trailing Newline — mehrzeilig zerstörte GITHUB_OUTPUT.
N=$(bash "$CI/read-block-ab.sh" "$T/c1.md" | wc -l | tr -d ' ')
assert_eq "0" "$N" "Ausgabe ist einzeilig ohne trailing Newline (kein mehrzeiliger Output)"

# Fehlender Wert → Default high.
printf 'audit:\n  etwas_anderes: x\n' > "$T/c2.md"
assert_eq "high" "$(bash "$CI/read-block-ab.sh" "$T/c2.md")" "fehlender Wert → Default high"

# medium bleibt medium (pip-audit-Skala).
printf '  block_ab: medium  # comment\n' > "$T/c3.md"
assert_eq "medium" "$(bash "$CI/read-block-ab.sh" "$T/c3.md")" "medium bleibt medium (pip-audit)"

# medium → moderate für npm audit.
assert_eq "moderate" "$(bash "$CI/read-block-ab.sh" --npm "$T/c3.md")" "medium→moderate für npm audit"

# high mit --npm bleibt high (nur medium wird gemappt).
assert_eq "high" "$(bash "$CI/read-block-ab.sh" --npm "$T/c1.md")" "high bleibt high auch mit --npm"

rm -rf "$T"
