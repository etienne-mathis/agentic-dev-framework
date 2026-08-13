# Head-to-Head-Report: Framework vs. Single-AI (P3.4)

> Status: **Template** — wird nach dem Doppel-Lauf mit echten Zahlen aus `results.tsv` gefüllt.
> Tabellen via `bash experiment/collect.sh` erzeugen und hier einsetzen.

Datum des Laufs: `<YYYY-MM-DD>` · Repo: G13 · Framework-Stand: nach Phase 0–3 (gehärtet)
· Modell-Familie: `<…>` · Task-Set: `experiment/task-set.md` (7 Tasks: 2 trivial, 3 mittel, 2 komplex)

## Methodik (kurz)

Neutraler Referee = unabhängig geschriebener Acceptance-Contract + CI-Gates, identisch für beide
Arme. Arm A = volle Pipeline; Arm B = eine Single-AI-Session, danach derselbe Contract + dieselben
Gates. Verbrauch real gemessen via `measure-run.sh` (keine Proxys). Fairness-Regeln siehe
`README.md`.

## Ergebnisse

<!-- Ausgabe von `bash experiment/collect.sh` hier einsetzen: -->

### Gesamt je Arm

_(collect.sh-Tabelle einsetzen)_

### Je Komplexität × Arm

_(collect.sh-Tabelle einsetzen)_

### Kern-Gegenüberstellung

_(collect.sh-Block einsetzen: escaped defects, Eingriffe, Tokens, Token-Verhältnis A/B)_

## Auswertung (ehrliches Fazit)

Nach dem Lauf ausfüllen — nur belegte Aussagen, keine Wunsch-Narrative:

- **Wo gewinnt das Framework?** (erwartete Hypothese: Defekt-Vermeidung / weniger escaped
  defects, Auditierbarkeit, Konventions-Konformität). Beleg: `<Zahlen>`.
- **Wo gewinnt Single-AI?** (erwartete Hypothese: Geschwindigkeit + Tokens bei trivialen Tasks).
  Beleg: `<Zahlen>`.
- **Break-even-Komplexität:** Ab welcher Komplexität rechtfertigt die Defekt-Vermeidung den
  Mehrverbrauch des Frameworks? `<trivial | mittel | komplex>`. Beleg: `<Zahlen>`.
- **Fast-Lane-Wirkung:** Hat `track:fast` den Overhead bei T1/T2 messbar gesenkt (Tokens/Wall
  gegen ein hypothetisches Vollprogramm)? `<Zahlen>`.
- **Überraschungen / Widerlegungen:** Was war anders als erwartet? Wurde die Effizienz-Behauptung
  belegt oder **widerlegt**? `<…>`.

## Threats to Validity

- Kleine Stichprobe (7 Tasks, ein Repo, ein Stack). Keine statistische Signifikanz, nur Indikation.
- Ein Operator, eine Modell-Familie, ein Zeitraum. Reihenfolge-/Lerneffekte teils gemischt, nicht eliminiert.
- Escaped defects hängen an der Qualität des Contracts (Referee-Güte). Contract-Lücken verzerren beide Arme gleich, aber nicht neutral gegenüber der Realität.
- Token-Kosten via lokale Session-jsonl gemessen; Cache-Read-Anteile sind modell-/kontextabhängig.

## Rohdaten

`experiment/results.tsv` (eine Zeile je Task × Arm). Aggregation reproduzierbar via
`bash experiment/collect.sh`.
