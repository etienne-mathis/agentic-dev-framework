# Head-to-Head-Report: Framework vs. Single-AI (P3.4)

> Status: **In Arbeit** — triviale Stufe (T1, T2) vollständig; mittlere Stufe (T3) qualitativ
> charakterisiert (Arm A cycle-heavy, nicht bis Merge gegrindet). T4–T7 offen. Tabellen aus
> `bash experiment/collect.sh`.

Datum des Laufs: 2026-08-14 · Repo: G13 · Framework-Stand: nach Phase 0–3 + Fast-Lane-Fix (gehärtet)
· Modell-Familie: Claude (Arm A gemischte Tiers via `preflight-modell`; Arm B = Haiku, spiegelt die
Implementierungs-Tier von Arm A, um den reinen Framework-Effekt zu isolieren)
· Task-Set: `experiment/task-set.md` (7 Tasks: 2 trivial, 3 mittel, 2 komplex)

## Methodik (kurz)

Neutraler Referee = unabhängig geschriebener Acceptance-Contract + CI-Gates, identisch für beide
Arme. Arm A = volle Pipeline (ARCHITECT → DEVELOPER inkl. test-author → REVIEWER → CSO → Merge);
Arm B = eine Single-AI-Session in einem **isolierten Worktree vom selben Vor-Merge-Commit** (sieht
den frozen Contract NICHT), danach derselbe frozen Contract + Lint als Schiedsrichter. Token-Messung
einheitlich über die gemeldeten `subagent_tokens` (Orchestrierungs-Modell; measure-run.sh per
Repo-Slug isoliert hier nicht). Fairness-Regeln siehe `README.md`.

## Ergebnisse

### Gesamt je Arm

| Arm | n | Tokens Σ | Tokens med | Wall med (s) | Zyklen Σ | Eingriffe Σ | Findings Σ | Escaped Σ | CI grün | Konv. ok |
|---|---|---|---|---|---|---|---|---|---|---|
| A (Framework) | 2 | 279758 | 139879 | 533 | 2 | 2 | 0 | 0 | 2/2 | 2/2 |
| B (Single-AI) | 2 | 36097 | 18048 | 20 | 0 | 0 | 0 | 0 | 2/2 | 2/2 |

### Je Komplexität × Arm

| Komplexität | Arm | n | Tokens Σ | Tokens med | Wall med (s) | Zyklen Σ | Eingriffe Σ | Findings Σ | Escaped Σ | CI grün | Konv. ok |
|---|---|---|---|---|---|---|---|---|---|---|---|
| trivial | A | 2 | 279758 | 139879 | 533 | 2 | 2 | 0 | 0 | 2/2 | 2/2 |
| trivial | B | 2 | 36097 | 18048 | 20 | 0 | 0 | 0 | 0 | 2/2 | 2/2 |

### Kern-Gegenüberstellung (triviale Stufe)

- Escaped defects: Arm A = 0 · Arm B = 0
- Menschliche Eingriffe: Arm A = 2 (je 1 Merge) · Arm B = 0
- Tokens gesamt: Arm A = 279.758 · Arm B = 36.097
- **Token-Verhältnis A/B = 7,75× (Framework teurer)** · Wall-Clock ~27× langsamer (533s vs. 20s)

## Auswertung (ehrliches Zwischenfazit — triviale Stufe)

- **Bei trivialen Tasks gewinnt Single-AI eindeutig.** 7,75× weniger Tokens, ~27× schneller,
  **identische Qualität**: beide Arme 0 escaped defects, beide bestehen frozen Contract + Lint.
  Der Framework-Overhead (4 Rollen, Contract, CI, Merge-Zeremonie) rechtfertigt sich hier **nicht**.
- **Der Referee war für triviale Tasks nicht diskriminierend.** Weil eine 4-Zeilen-Funktion kaum
  Fehlerfläche hat, produzierte der Single-AI identischen Code (`Math.round(x*(1+satz))`). Die
  Framework-Stärke (Defekt-Vermeidung) konnte auf dieser Stufe nichts fangen, weil es nichts zu
  fangen gab. Das ist die erwartete, ehrliche Nullaussage — der interessante Test kommt bei
  mittel/komplex, wo escaped defects realistisch werden.
- **Fast-Lane-Wirkung sichtbar, aber nicht ausreichend:** T2 (Fast-Lane) kostete 115.879 Tk vs. T1
  (volles Programm) 163.879 Tk — die reduzierte Reviewer-Tiefe senkte den Arm-A-Verbrauch um ~29 %.
  Trotzdem bleibt Arm A auch mit Fast-Lane ~6,7× teurer als Single-AI. Fast-Lane mildert den
  Overhead, eliminiert ihn bei Trivialem nicht.
- **Break-even-Komplexität:** auf Basis der trivialen Stufe **nicht erreicht** — Framework lohnt hier
  nicht. Offen, ob mittel/komplex den Break-even zeigen (Hypothese: ja, sobald escaped defects auftreten).

> **Noch offen (mittel + komplex).** Die eigentliche Kernfrage — ab welcher Komplexität die
> Defekt-Vermeidung des Frameworks den Mehrverbrauch rechtfertigt — ist erst mit T3–T7 beantwortbar.
> Erwartung: Bei mittleren/komplexen Tasks produziert der Single-AI escaped defects (Idempotenz,
> Nebenläufigkeit, Cent-Rundung an Grenzfällen), die der frozen Contract + REVIEWER/CSO in Arm A
> fangen. Erst dann kippt die Kosten/Nutzen-Rechnung. Bis dahin gilt: **die Effizienz-Behauptung
> ist für triviale Tasks widerlegt** (Single-AI schlägt das Framework klar).

### Entscheidung (aus der trivialen Stufe abgeleitet, 2026-08-14)

**Für triviale Tasks: Zeremonie weg, Schiedsrichter behalten.** Ableitung aus dem 7,75×-Ergebnis bei
identischer Qualität — aber präzisiert, nicht „einfach Single-AI ohne Netz":

- Kandidat für eine **„Solo-Lane"** unterhalb der Fast-Lane: Tasks, die die qualitativen
  Trivialitäts-Kriterien erfüllen (einzelne Impl-Datei / keine Dep / kein Schema / kein Auth-PII),
  werden von **einer Single-AI** implementiert — **aber weiterhin durch das Acceptance-Contract + die
  CI-Gates validiert**. Das Teure (4-Rollen-Zeremonie, Merge-Zyklen) entfällt; das Wertvolle (der
  Referee als Defekt-Netz) bleibt und kostet fast nichts.
- Begründung: Die reale Gefahr ist **Fehl-Triage** (ein „trivial" eingestufter Task ist es doch nicht).
  Contract + CI fangen genau diesen Fall ab — ohne sie wäre die Solo-Lane eine blinde Wette. Der
  ARCHITECT hat mit den Fast-Lane-Kriterien bereits ein passendes Triage-Gate.
- Abgrenzung zur Fast-Lane: Fast-Lane reduziert nur die REVIEWER-Tiefe, läuft aber weiter durch alle
  Rollen. Die Solo-Lane ist radikaler (kein Multi-Rollen-Durchlauf, kein Merge-Ritual).
- **Umsetzung bewusst zurückgestellt** bis nach der mittel/komplex-Stufe: Falls sich zeigt, dass der
  Referee ohne die Rollen (REVIEWER/CSO) reale Defekte durchlässt, ändert das den Zuschnitt der
  Solo-Lane. Erst mit den vollständigen Daten wird die Lane spezifiziert und implementiert.

## Mittlere Stufe (T3, Warenkorb-Persistenz) — qualitativer Zwischenbefund

T3 wurde durch Arm A gefahren, aber bewusst **nicht bis zum Merge gegrindet** — der Verlauf selbst ist
der Befund. Arm A verbrauchte für einen einzigen mittleren Task: ARCHITECT + DEVELOPER (v1) + REVIEWER
(c1) + DEVELOPER (v2) + REVIEWER (c2) + … (bei Cycle 3 gestoppt), plus mehrere Operator-Eingriffe.

**Wo das Framework gewinnt (belegt):**
- **CI fing eine echte Regression:** eine hinzugefügte `vitest.config.js` verdrängte die `vite.config.js`
  und brach den `@`-Alias → alle bestehenden Tests rot. Lokal „grün", in CI rot. Single-AI hätte das
  (ohne CI-Gate) verschifft.
- **REVIEWER fing reale Defekte jenseits des Contracts:** (c1) der Corrupt-State-Fallback wurde vom
  Acceptance-Test gar nicht am echten Init-Pfad geprüft; Test-Isolation fehlte. Der frozen Contract
  allein (Arm-B-Netz) hätte das durchgewunken — der Contract testete den Fallback nur scheinbar.

**Wo das Framework verliert / fragil ist (belegt):**
- **Cycle-Explosion:** Der REVIEWER findet in jedem Cycle progressiv kleinere Issues (high → medium →
  low) und treibt so immer neue Runden. Bei Cycle 3 sank die Severity auf „low unused var" / „medium
  Test-Konsistenz" — jeder Cycle kostet einen Developer- + Reviewer-Spawn. Das ist die „wiederkehrende
  Cycles / Human-Bottleneck"-Schwäche in Reinform.
- **Operative Fragilität mit schwachem Modell (Haiku):** Der DEVELOPER produzierte **dreimal**
  commitlint-ungültige Commit-Messages (2× Großbuchstaben-Scope `useCart`, 1× fehlende `(#34)`-Referenz).
  Jeder Fehler ist ein **harter Deadlock** (Fix erfordert History-Rewrite, für Agenten verboten) → nur per
  Operator lösbar. Framework-Issue #13.
- **Label-Objekt-Verwirrung:** `human-override:test-contract` musste auf **Story UND PR** gesetzt werden
  (der contract-Guard prüft die PR-Labels) — dieselbe Story-vs-PR-Klasse wie der Fast-Lane-Bug P3.2-B.

**Fazit mittlere Stufe (vorläufig):** Das Framework fängt bei mittlerer Komplexität reale Defekte, die
Single-AI (nur Contract+CI) durchließe — der Contract allein ist ein **schwächeres Netz** als Contract +
REVIEWER/CSO. ABER: der Preis ist hoch und teils irrational (Cycle-Explosion auf Low-Severity-Nitpicks,
wiederkehrende Commit-Deadlocks mit schwachem Modell). Für einen produktionskritischen Kontext kann die
Gründlichkeit den Preis wert sein; für alltägliche mittlere Tasks droht das Framework in Nebensächlichkeiten
zu ersticken. **Konkreter Verbesserungsbedarf:** (a) Cycle-Cap / Severity-Schwelle (Low-Findings dürfen den
Merge nicht blocken), (b) Commit-Deadlock beheben (#13), (c) stärkeres Modell-Tier für mittlere Tasks statt
Haiku (der Preflight unterschätzt In-Place-Modifikationen und empfahl fälschlich Haiku).

## Threats to Validity

- Kleine Stichprobe (7 Tasks, ein Repo, ein Stack). Keine statistische Signifikanz, nur Indikation.
- Ein Operator, eine Modell-Familie, ein Zeitraum. Reihenfolge-/Lerneffekte teils gemischt, nicht eliminiert.
- Escaped defects hängen an der Qualität des Contracts (Referee-Güte). Contract-Lücken verzerren beide Arme gleich, aber nicht neutral gegenüber der Realität.
- Token-Kosten via lokale Session-jsonl gemessen; Cache-Read-Anteile sind modell-/kontextabhängig.

## Rohdaten

`experiment/results.tsv` (eine Zeile je Task × Arm). Aggregation reproduzierbar via
`bash experiment/collect.sh`.
