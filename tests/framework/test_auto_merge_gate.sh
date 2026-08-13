#!/usr/bin/env bash
# test_auto_merge_gate.sh — Gate-Politik + Autonomie-Reader (P3.2).
suite "auto-merge Gate (scripts/ci/auto-merge-gate.sh + read-autonomy.sh)"

gate() { # $1=labels(mehrzeilig) $2=autonomy $3=checks → setzt RC, OUT
  RC=0
  OUT=$(printf '%s\n' "$1" | bash "$CI/auto-merge-gate.sh" --autonomy "$2" --checks "$3" 2>&1) || RC=$?
}

# Happy path.
gate "status:approved
type:story" autonomous success
assert_eq 0 "$RC" "autonom + approved + Checks grün + keine Blocker → MERGE"
assert_contains "$OUT" "MERGE" "Grund MERGE ausgegeben"

# supervised (Default) → HOLD.
gate "status:approved" supervised success
assert_eq 10 "$RC" "supervised → HOLD (Mensch mergt)"

# fehlendes approved → HOLD.
gate "type:story" autonomous success
assert_eq 10 "$RC" "kein status:approved → HOLD"

# Blocker-Labels → HOLD.
gate "status:approved
needs-human" autonomous success
assert_eq 10 "$RC" "needs-human → HOLD"

gate "status:approved
human-override:test-contract" autonomous success
assert_eq 10 "$RC" "human-override:* → HOLD"

gate "status:approved
merge-hold" autonomous success
assert_eq 10 "$RC" "merge-hold → HOLD"

# Checks nicht grün → HOLD.
gate "status:approved" autonomous pending
assert_eq 10 "$RC" "Checks pending → HOLD"
gate "status:approved" autonomous failure
assert_eq 10 "$RC" "Checks failure → HOLD"

# read-autonomy.sh
T=$(mktemp -d)
printf 'autonomy: autonomous\n'                > "$T/a.md"
printf 'autonomy: supervised   # default\n'    > "$T/b.md"
printf 'kein autonomy-feld hier\n'             > "$T/c.md"
assert_eq "autonomous" "$(bash "$CI/read-autonomy.sh" "$T/a.md")" "read-autonomy: autonomous erkannt"
assert_eq "supervised" "$(bash "$CI/read-autonomy.sh" "$T/b.md")" "read-autonomy: supervised (Inline-Kommentar ignoriert)"
assert_eq "supervised" "$(bash "$CI/read-autonomy.sh" "$T/c.md")" "read-autonomy: fehlendes Feld → Default supervised"
assert_eq "supervised" "$(bash "$CI/read-autonomy.sh" "$T/nichtvorhanden.md")" "read-autonomy: fehlende Datei → supervised"
rm -rf "$T"
