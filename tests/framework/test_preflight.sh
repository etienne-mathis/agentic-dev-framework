#!/usr/bin/env bash
# test_preflight.sh — Kern-Exit-Codes der Preflight-Skripte gegen Fixtures.
# Nur offline-deterministische Pfade (kein gh/Netz): --help, Draft-Modus, Budget-Gate.
suite "preflight-Skripte (Kern-Exit-Codes)"

WORK=$(mktemp -d)   # neutrales cwd, damit keine .preflight/-Artefakte im Repo landen
DRAFT="$WORK/draft.md"
printf 'Kleine Story: Rundungsfehler in der Summenfunktion korrigieren.\n' > "$DRAFT"

# --help → exit 0 und Selbstbeschreibung.
RC=0; OUT=$(bash "$SCRIPTS/preflight.sh" --help) || RC=$?
assert_eq 0 "$RC" "preflight.sh --help → exit 0"
assert_contains "$OUT" "Estimator" "preflight.sh --help beschreibt sich selbst"

# Draft-Modus gegen das python golden project → Modell-Empfehlung, kein NO-GO.
RC=0; OUT=$(cd "$WORK" && bash "$SCRIPTS/preflight.sh" \
  --body-file "$DRAFT" --title "Rundungsfehler korrigieren" \
  --source-dir "$GOLDEN/python") || RC=$?
assert_true  "Draft-Modus ohne Budget → kein NO-GO (exit 0/10)" -- test "$RC" -ne 20
assert_contains "$OUT" "Modell" "Draft-Modus gibt eine Modell-Empfehlung aus"

# Draft-Modus gegen das node golden project → ebenfalls verwertbar (Stack-Matrix).
RC=0; OUT=$(cd "$WORK" && bash "$SCRIPTS/preflight.sh" \
  --body-file "$DRAFT" --title "Rundungsfehler korrigieren" \
  --source-dir "$GOLDEN/node") || RC=$?
assert_true  "Draft-Modus (node) → kein NO-GO (exit 0/10)" -- test "$RC" -ne 20
assert_contains "$OUT" "Modell" "Draft-Modus (node) gibt Modell-Empfehlung aus"

# Winziges Budget erzwingt NO-GO (exit 20) — Budget-Gate greift.
RC=0; OUT=$(cd "$WORK" && bash "$SCRIPTS/preflight.sh" \
  --body-file "$DRAFT" --title "Rundungsfehler korrigieren" \
  --source-dir "$GOLDEN/python" --budget 1) || RC=$?
assert_eq 20 "$RC" "Budget=1 → NO-GO (exit 20)"

# ── AC-Parser: dt. Header + Fettschrift-ACs (Regression P3.2-A) ──────────────
# Vor dem Fix zählte der Parser nur engl. "Acceptance Criteria" + Aufzählungs-ACs;
# ein deutscher Story-Body mit "**AC-1:**"-Fettschrift ergab AC:0.
ACBODY="$WORK/ac.md"
printf '## Akzeptanzkriterien\n\n**AC-1:** a\n**AC-2:** b\n**AC-3:** c\n**AC-4:** d\n**AC-5:** e\n\n## Tasks\n\n- `src/utils/x.js` anlegen\n' > "$ACBODY"
RC=0; OUT=$(cd "$WORK" && bash "$SCRIPTS/preflight.sh" \
  --body-file "$ACBODY" --title "MwSt-Helper" --source-dir "$GOLDEN/node") || RC=$?
assert_contains "$OUT" "AC:5" "AC-Parser zählt dt. Header + Fettschrift-ACs (5)"

# ── MODULES: Test-/Docs-Verzeichnisse sind keine Module (Regression P3.2-A) ───
# Vor dem Fix hob schon die zwingende Test-/Contract-Datei (tests/…) den Modul-
# Zähler und damit den Score fälschlich an.
MODBODY="$WORK/mod.md"
printf '## Scope\n\n- `src/utils/x.js`\n- `tests/acceptance/story_1/x.test.js`\n- `docs/architecture.adoc`\n\n## Tasks\n\n- `src/utils/x.js` anlegen\n' > "$MODBODY"
RC=0; OUT=$(cd "$WORK" && bash "$SCRIPTS/preflight.sh" \
  --body-file "$MODBODY" --title "MwSt-Helper" --source-dir "$GOLDEN/node") || RC=$?
assert_contains "$OUT" "Module:1" "MODULES schließt tests/ und docs/ aus (nur src → 1)"

# preflight-dedup ohne Entwurf → sauberer Skip (exit 0, kein Netz).
RC=0; OUT=$(bash "$SCRIPTS/preflight-dedup.sh" 2>&1) || RC=$?
assert_eq 0 "$RC" "preflight-dedup ohne --title/--body-file → Skip (exit 0)"
assert_contains "$OUT" "übersprungen" "preflight-dedup meldet den Skip"

rm -rf "$WORK"
