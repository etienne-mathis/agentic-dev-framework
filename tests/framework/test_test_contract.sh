#!/usr/bin/env bash
# test_test_contract.sh — guard-test-contract Regel 1–4, stack-agnostisch (py + js).
# Deckt Problem 5 (Stack-Blindfleck) auf Guard-Ebene: identisches Verhalten je Stack.
suite "test-contract-Guard (scripts/ci/check-test-contract.sh) — Stack-Matrix"

# Baut ein synthetisches Story-Repo. $1=scenario  $2=ext(py|js)  → gibt Pfad aus.
build_contract_repo() {
  local scenario="$1" ext="$2" d cdir
  d=$(mktemp -d)
  git -C "$d" init -q -b main
  git -C "$d" config user.email t@t; git -C "$d" config user.name t; git -C "$d" config commit.gpgsign false
  echo base > "$d/README.md"; git -C "$d" add -A; git -C "$d" commit -qm "chore: init (#0)"
  git -C "$d" checkout -q -b story/18
  cdir="$d/tests/acceptance/story_18"
  case "$scenario" in
    missing) : ;;                                   # kein Contract-Verzeichnis
    mixed)                                           # Regel 2: unreiner Contract-Commit
      mkdir -p "$cdir"; echo t > "$cdir/contract.$ext"
      mkdir -p "$d/src"; echo c > "$d/src/impl.$ext"
      git -C "$d" add -A
      git -C "$d" commit -qm "test(cart): add acceptance contract for #18 [AC-1]" ;;
    clean)                                           # sauber: reiner Contract + Impl
      mkdir -p "$cdir"; echo t > "$cdir/contract.$ext"
      git -C "$d" add -A; git -C "$d" commit -qm "test(cart): add acceptance contract for #18 [AC-1]"
      mkdir -p "$d/src"; echo c > "$d/src/impl.$ext"
      git -C "$d" add -A; git -C "$d" commit -qm "feat(cart): implement (#18)" ;;
    silent)                                          # Regel 3: stille Nachänderung
      mkdir -p "$cdir"; echo t > "$cdir/contract.$ext"
      git -C "$d" add -A; git -C "$d" commit -qm "test(cart): add acceptance contract for #18 [AC-1]"
      echo sneaky >> "$cdir/contract.$ext"
      git -C "$d" add -A; git -C "$d" commit -qm "feat(cart): tweak (#18)" ;;
    revise)                                          # Regel 4: bewusste Revision
      mkdir -p "$cdir"; echo t > "$cdir/contract.$ext"
      git -C "$d" add -A; git -C "$d" commit -qm "test(cart): add acceptance contract for #18 [AC-1]"
      echo revised >> "$cdir/contract.$ext"
      git -C "$d" add -A; git -C "$d" commit -qm "test(cart): revise acceptance contract for #18" ;;
  esac
  echo "$d"
}

run_guard() { # $1=repo $2=override → setzt RC
  RC=0
  ( cd "$1" && OVERRIDE="$2" bash "$CI/check-test-contract.sh" 18 main ) >/dev/null 2>&1 || RC=$?
}

for ext in py js; do
  d=$(build_contract_repo clean "$ext");   run_guard "$d" false; assert_eq 0 "$RC" "[$ext] sauberer Contract → intakt";                 rm -rf "$d"
  d=$(build_contract_repo missing "$ext"); run_guard "$d" false; assert_eq 1 "$RC" "[$ext] fehlendes Contract-Verzeichnis → Regel 1";    rm -rf "$d"
  d=$(build_contract_repo mixed "$ext");   run_guard "$d" false; assert_eq 1 "$RC" "[$ext] vermischter Contract-Commit → Regel 2";       rm -rf "$d"
  d=$(build_contract_repo silent "$ext");  run_guard "$d" false; assert_eq 1 "$RC" "[$ext] stille Nachänderung → Regel 3";               rm -rf "$d"
  d=$(build_contract_repo revise "$ext")
  run_guard "$d" false; assert_eq 1 "$RC" "[$ext] revise ohne Override → Regel 4 blockt"
  run_guard "$d" true;  assert_eq 0 "$RC" "[$ext] revise mit Override → erlaubt"
  rm -rf "$d"
done

# Kein story/-Branch (leere Nummer) → Guard übersprungen (exit 0).
RC=0; ( OVERRIDE=false bash "$CI/check-test-contract.sh" "" main ) >/dev/null 2>&1 || RC=$?
assert_eq 0 "$RC" "leere Story-Nummer → Guard übersprungen"
