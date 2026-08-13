#!/usr/bin/env bash
# test_commitlint.sh — Konvention, Contract-Ausnahme (Bug 1), Merge-Skip (Bug 2).
suite "commitlint (scripts/ci/commitlint.sh)"

RC=0; OUT=$(printf 'feat(api): add users endpoint (#12)\n' | bash "$CI/commitlint.sh") || RC=$?
assert_eq 0 "$RC" "gültige type(scope): … (#N) → exit 0"

RC=0; OUT=$(printf 'fix: correct rounding (#7)\n' | bash "$CI/commitlint.sh") || RC=$?
assert_eq 0 "$RC" "gültige Message ohne scope → exit 0"

# Bug 1: commitlint ↔ test-contract-Format-Konflikt
RC=0; OUT=$(printf 'test(cart): add acceptance contract for #18 [AC-1..AC-3]\n' | bash "$CI/commitlint.sh") || RC=$?
assert_eq 0 "$RC" "Contract-Commit-Konvention zulässig (Regression Bug 1)"

RC=0; OUT=$(printf 'test(cart): revise acceptance contract for #18\n' | bash "$CI/commitlint.sh") || RC=$?
assert_eq 0 "$RC" "revise-Contract-Commit zulässig"

RC=0; OUT=$(printf 'random junk without convention\n' | bash "$CI/commitlint.sh" 2>&1) || RC=$?
assert_eq 1 "$RC" "ungültige Message → exit 1"
assert_contains "$OUT" "Ungültige Commit-Message" "meldet die ungültige Message"

RC=0; OUT=$(printf 'feat: add thing\n' | bash "$CI/commitlint.sh" 2>&1) || RC=$?
assert_eq 1 "$RC" "fehlende (#N) → exit 1"

# Bug 2: Merge-Commit muss übersprungen werden (--no-merges im Range-Modus).
D=$(mktemp -d)
git -C "$D" init -q -b main
git -C "$D" config user.email t@t; git -C "$D" config user.name t; git -C "$D" config commit.gpgsign false
echo a > "$D/a"; git -C "$D" add -A; git -C "$D" commit -qm "chore: init (#0)"; git -C "$D" tag base
git -C "$D" checkout -q -b feat/x
echo b > "$D/b"; git -C "$D" add -A; git -C "$D" commit -qm "feat: add b (#1)"
git -C "$D" checkout -q main
git -C "$D" merge --no-ff -q -m "Merge pull request #1 from feat/x" feat/x

RC=0; OUT=$(cd "$D" && bash "$CI/commitlint.sh" --range "base..HEAD" 2>&1) || RC=$?
assert_eq 0 "$RC" "Merge-Commit übersprungen → exit 0 (Regression Bug 2)"

# Kontrolle: das Merge-Subject IST an sich ungültig — nur --no-merges rettet.
MSUB=$(git -C "$D" log -1 --format=%s)
RC=0; OUT=$(bash "$CI/commitlint.sh" --message "$MSUB" 2>&1) || RC=$?
assert_eq 1 "$RC" "Merge-Subject an sich ungültig (beweist: nur --no-merges rettet)"
rm -rf "$D"
