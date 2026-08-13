#!/usr/bin/env bash
# test_golden.sh — Stack-Matrix-Konformität: beide golden projects sind vollständig
# und die stack-agnostischen CI-Skripte greifen auf beiden identisch.
suite "golden projects (Stack-Matrix python + node)"

for stack in python node; do
  g="$GOLDEN/$stack"
  assert_true  "[$stack] golden project vorhanden"                 -- test -d "$g"
  assert_true  "[$stack] CLAUDE.md vorhanden"                      -- test -f "$g/CLAUDE.md"
  assert_contains "$(cat "$g/CLAUDE.md")" "stack:" "[$stack] CLAUDE.md deklariert stack:"
  assert_true  "[$stack] hat src/"                                 -- test -d "$g/src"
  assert_true  "[$stack] hat tests/acceptance/story_1/"            -- test -d "$g/tests/acceptance/story_1"
  # Genau eine Acceptance-Test-Datei in der stack-typischen Endung.
  case "$stack" in
    python) pat="*.py" ;;
    node)   pat="*.test.js" ;;
  esac
  cnt=$(find "$g/tests/acceptance/story_1" -name "$pat" | wc -l | tr -d ' ')
  assert_true  "[$stack] Acceptance-Test in Konvention $pat vorhanden" -- test "$cnt" -ge 1
  # block_ab liest sauber aus dem golden CLAUDE.md.
  v=$(bash "$CI/read-block-ab.sh" "$g/CLAUDE.md")
  assert_true  "[$stack] block_ab lesbar ($v)"                     -- test -n "$v"
done

# node golden nutzt medium → npm-Mapping moderate.
assert_eq "moderate" "$(bash "$CI/read-block-ab.sh" --npm "$GOLDEN/node/CLAUDE.md")" \
  "[node] block_ab medium → moderate (npm audit)"
# python golden bleibt high.
assert_eq "high" "$(bash "$CI/read-block-ab.sh" "$GOLDEN/python/CLAUDE.md")" \
  "[python] block_ab high"
