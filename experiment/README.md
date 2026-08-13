# Head-to-Head-Experiment (P3.4) — Runbook

Zweite Kern-Anforderung der Härtung: mit echten Daten belegen (oder widerlegen), dass die
Framework-Pipeline besser/effizienter ist als klassische Single-AI-Entwicklung.

**Neutraler Schiedsrichter für BEIDE Arme:** die vom `test-author` unabhängig geschriebenen
Acceptance-Contracts **plus** die CI-Gates. Identische Story-Specs (`task-set.md`), identische
Bewertung. Kein Arm bewertet sich selbst.

Repo: **G13** (privat). Misst das **gehärtete** Framework (nach Phase 0–3), nicht das alte.

---

## Vorbereitung

1. G13 auf den aktuellen Framework-Stand bringen (Agent-Prompts, `scripts/`, Workflows,
   `CLAUDE.md`-Konfig). Labels via `setup/labels.sh` (inkl. `track:fast`, `merge-hold`).
2. Aus `task-set.md` die 7 Story-Specs bereitstellen (der ARCHITECT erzeugt daraus Issues + ACs).
3. Für JEDE Story schreibt der `test-author` den Acceptance-Contract **einmal**. Dieser Contract
   ist ab jetzt eingefroren (guard-test-contract) und dient beiden Armen als Referee.
4. `.preflight/actuals.tsv` auf G13 leeren/sichern (measure-run.sh schreibt dorthin).

## Arm A — Framework (volle Pipeline)

Pro Story die volle Pipeline (`/pipeline`): ARCHITECT → DEVELOPER (inkl. test-author) →
REVIEWER → CSO → Merge. Jede Rolle als frischer Sub-Agent im empfohlenen Tier.

- `measure-run.sh` protokolliert je Rolle (Schritt 2b) den echten Verbrauch nach
  `.preflight/actuals.tsv` (Feld `issue` = Story-Nummer → aggregierbar).
- Nach Abschluss je Task die Summe über alle Rollen-Spawns bilden:
  ```bash
  awk -F'\t' -v i=<story-nr> '$1==i{in+=$4;out+=$5;cr+=$6;s+=$7}
    END{printf "in=%s out=%s cache=%s wall=%s\n",in,out,cr,s}' .preflight/actuals.tsv
  ```
- Zyklen = höchster `cycle:`-Wert am PR. Findings = vom REVIEWER gemeldete Findings.
  Menschliche Eingriffe = manuelle Merges/Overrides/Entscheidungen.

## Arm B — Single-AI

Eine einzelne Claude-Session, Auftrag: „bau das gemäß Story + ACs" — **ohne** Rollen, ohne
Guards, ohne Pipeline. Danach denselben Acceptance-Contract + dieselben CI-Gates gegen das
Ergebnis laufen lassen.

- Verbrauch: `measure-run.sh --issue <task> --rolle single-ai --from <start> --to <ende>
  --source-dir .` über das eine Session-Fenster.
- `escaped_defects` = Contract-/Gate-Fehler, die NACH dem „fertig" des Single-AI auftreten
  (das ist der eigentliche Qualitätsmesswert: was hätte das Framework gefangen?).
- Menschliche Eingriffe = manuelle Korrekturen, bis die Gates grün sind (oder Abbruch).

## Fairness-Regeln

- Identische Story + identische ACs für beide Arme. Der Contract wird **einmal** geschrieben
  (im Arm A), Arm B bekommt ihn als Bewertungsmaßstab, darf ihn aber nicht ändern.
- Gleicher Ausgangs-Codebase-Stand je Task (Arm B auf einem sauberen Branch vom selben Commit).
- Gleiche Modell-Familie. Reihenfolge der Tasks zwischen den Armen mischen, um Lern-/
  Reihenfolgeeffekte zu neutralisieren.

## Metriken erfassen

Je Task **zwei** Zeilen (Arm A und Arm B) in `results.tsv` eintragen (Schema siehe Kopf der
Datei). Dann aggregieren:

```bash
bash experiment/collect.sh          # liest experiment/results.tsv → Markdown-Tabellen
```

Die Ausgabe von `collect.sh` in `REPORT.md` übernehmen und das Fazit schreiben.

## Auswertung

`REPORT.md` füllen: Tabellen + ehrliches Fazit — wo gewinnt das Framework
(Defekt-Vermeidung, Auditierbarkeit), wo Single-AI (Geschwindigkeit/Kosten bei Trivialem),
und **ab welcher Task-Komplexität** sich der Framework-Overhead rechnet.

---

## Status

Infrastruktur steht (Task-Set, results-Schema, collect.sh, REPORT-Template). Der eigentliche
Doppel-Lauf über die 7 Tasks ist eine interaktive Orchestrierung über mehrere Sessions und
wird getrennt ausgeführt (wie der P1-E2E). Ergebnisse landen in `results.tsv` → `REPORT.md`.
