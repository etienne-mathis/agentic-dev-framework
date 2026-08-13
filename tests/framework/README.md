# Framework-Selbsttest-Harness (P3.1)

Plain-bash, zero-infra (kein bats). Testet die extrahierte Guard-/CI-Logik und die
Preflight-Skripte gegen synthetische Fixtures — damit sich das Framework selbst testet,
bevor es Projekten vertraut wird. Behebt strukturell Problem 4 (ungetestete CI) und
Problem 5 (Stack-Blindfleck).

## Ausführen

```bash
tests/framework/run.sh            # alle Suites
tests/framework/run.sh contract   # nur Suites mit "contract" im Namen
```

Exit 0 = alle grün, 1 = mindestens ein Fehlschlag. Läuft in CI via
`.github/workflows/framework-selftest.yml` (Required Check auf main).

## Aufbau

- `run.sh` — Runner: sourct `assert.sh`, dann alle `test_*.sh`, druckt Summary.
- `assert.sh` — Assert-Helfer (`assert_eq`, `assert_contains`, `assert_true/false`, …).
- `test_commitlint.sh` — Konvention + Contract-Ausnahme (Bug 1) + Merge-Skip (Bug 2).
- `test_block_ab.sh` — `block_ab`-Extraktion inkl. Inline-Kommentar/Newline (Bug 3).
- `test_protected_paths.sh` — geschützte Pfade, Override, freie Pfade.
- `test_test_contract.sh` — guard-test-contract Regel 1–4, **stack-agnostisch (py + js)**.
- `test_preflight.sh` — Kern-Exit-Codes von `preflight.sh` / `preflight-dedup.sh` (offline).
- `test_golden.sh` — Stack-Matrix-Konformität der golden projects.
- `golden/python/`, `golden/node/` — kleinste lauffähige Referenzprojekte je Stack.

## Getestete Quelle (single source of truth)

Die Kern-Guard-/CI-Logik liegt in `scripts/ci/*.sh` und wird sowohl von den GitHub-
Workflows als auch von diesem Harness aufgerufen — kein Copy-Paste-Drift zwischen
`ci.yml.example`/Guards und den Tests.

## Fixtures

git-basierte Szenarien (Contract-Guard, Merge-Commit) werden zur Laufzeit in temporären
Repos erzeugt (kein Einchecken von binären git-Objekten). Statische Eingaben (CLAUDE.md-
Varianten, Commit-Messages, Pfadlisten) werden inline im jeweiligen `test_*.sh` gebaut.
Die golden projects unter `golden/` sind die dauerhaften Stack-Fixtures.

## Regressions-Beweis

Jeder der drei historischen E2E-Bugs ist als Assertion kodiert. Reintroduktion eines Bugs
(z. B. `--no-merges` entfernen oder die Contract-Ausnahme streichen) lässt die betreffende
Suite ROT werden — verifiziert am 2026-08-13.
