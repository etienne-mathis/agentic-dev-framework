#!/usr/bin/env bash
# test_protected_paths.sh — geschützt/erlaubt/Override, inkl. P3-Ergänzungen.
suite "protected-paths (scripts/ci/check-protected-paths.sh)"

# Alle geschützten Klassen müssen blocken (OVERRIDE=false).
for p in \
  ".claude/agents/reviewer.md" \
  ".github/workflows/ci.yml" \
  "CLAUDE.md" \
  "docs/PROTOCOL.md" \
  "scripts/glossar_gate.sh" \
  "scripts/preflight.sh" \
  "scripts/preflight-calibrate.sh" \
  "scripts/preflight-dedup.sh" \
  "scripts/measure-run.sh" \
  "scripts/ci/commitlint.sh"
do
  RC=0; printf '%s\n' "$p" | OVERRIDE=false bash "$CI/check-protected-paths.sh" >/dev/null 2>&1 || RC=$?
  assert_eq 1 "$RC" "geschützt geblockt: $p"
done

# Freie Pfade sind erlaubt.
RC=0; printf 'src/app.py\ndocs/architecture.adoc\ntests/test_x.py\n' \
  | OVERRIDE=false bash "$CI/check-protected-paths.sh" >/dev/null 2>&1 || RC=$?
assert_eq 0 "$RC" "freie Pfade erlaubt → exit 0"

# Override erlaubt geschützten Pfad.
RC=0; printf 'CLAUDE.md\n' | OVERRIDE=true bash "$CI/check-protected-paths.sh" >/dev/null 2>&1 || RC=$?
assert_eq 0 "$RC" "human-override erlaubt geschützten Pfad"

# docs/GLOSSARY.md ist NICHT geschützt (nur PROTOCOL.md).
RC=0; printf 'docs/GLOSSARY.md\n' | OVERRIDE=false bash "$CI/check-protected-paths.sh" >/dev/null 2>&1 || RC=$?
assert_eq 0 "$RC" "docs/GLOSSARY.md nicht geschützt"

# Gemischter Diff (frei + geschützt) blockt insgesamt.
RC=0; printf 'src/app.py\nscripts/ci/read-block-ab.sh\n' \
  | OVERRIDE=false bash "$CI/check-protected-paths.sh" >/dev/null 2>&1 || RC=$?
assert_eq 1 "$RC" "ein geschützter Pfad im Diff blockt den gesamten PR"
