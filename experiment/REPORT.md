# Head-to-Head-Report: Framework vs. Single-AI (P3.4)

> Status: **Kern-Aussage erreicht.** Triviale Stufe (T1, T2) + komplexe Stufe (T7) als Paare gemessen;
> mittlere Stufe (T3) qualitativ charakterisiert. T4/T5/T6 bewusst nicht gefahren (Kosten/Nutzen — die
> Aussage ist über triviale+komplexe Paare + T3-Charakterisierung robust genug). Aggregation via
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

Erfasst: **triviale Stufe** T1, T2 (beide Arme) + **komplexe Stufe** T7 (beide Arme). Mittlere Stufe
(T3) qualitativ charakterisiert (Arm A cycle-heavy, nicht als Paar gemessen). Aggregation via `collect.sh`.

### Gesamt je Arm

| Arm | n | Tokens Σ | Tokens med | Wall med (s) | Zyklen Σ | Eingriffe Σ | Findings Σ | Escaped Σ | CI grün | Konv. ok |
|---|---|---|---|---|---|---|---|---|---|---|
| A (Framework) | 3 | 495120 | 163879 | 550 | 3 | 4 | 4 | 0 | 3/3 | 3/3 |
| B (Single-AI) | 3 | 66097 | 18920 | 27 | 0 | 0 | 0 | 0 | 3/3 | 3/3 |

### Je Komplexität × Arm

| Komplexität | Arm | n | Tokens Σ | Tokens med | Wall med (s) | Zyklen Σ | Eingriffe Σ | Findings Σ | Escaped Σ | CI grün | Konv. ok |
|---|---|---|---|---|---|---|---|---|---|---|---|
| trivial | A | 2 | 279758 | 139879 | 533 | 2 | 2 | 0 | 0 | 2/2 | 2/2 |
| trivial | B | 2 | 36097 | 18048 | 20 | 0 | 0 | 0 | 0 | 2/2 | 2/2 |
| komplex | A | 1 | 215362 | 215362 | 5045 | 1 | 2 | 4 | 0 | 1/1 | 1/1 |
| komplex | B | 1 | 30000* | 30000* | 30 | 0 | 0 | 0 | 0 | 1/1 | 1/1 |

\* Arm-B-Tokens bei T7 durch Session-Limit ungemessen — geschätzt (~30s/3 tool-uses, Impl vollständig+korrekt).
Das exakte Token-Verhältnis der komplexen Stufe ist damit unsicher; die **Qualitäts-Aussage (escaped=0
beide)** ist es nicht.

### Kern-Gegenüberstellung (gesamt)

- Escaped defects: Arm A = 0 · Arm B = 0 (über ALLE gemessenen Paare)
- Menschliche Eingriffe: Arm A = 4 · Arm B = 0
- Tokens gesamt: Arm A = 495.120 · Arm B ≈ 66.097
- **Token-Verhältnis A/B ≈ 7,5× (Framework teurer)** · Wall-Clock ~20–160× langsamer je Task

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

## Komplexe Stufe (T7, Lagerbestand-Reservierung / Überverkauf) — der entscheidende Test

Hypothese vor dem Lauf: Bei komplexen Tasks (Nebenläufigkeit, Invarianten) produziert der Single-AI
escaped defects, die das Framework fängt → hier rechtfertigt sich der Overhead. **Ergebnis: widerlegt
für ein fähiges Modell.**

- **Arm A (Framework, Sonnet):** ARCHITECT → DEVELOPER (1 Durchlauf, **0 Review-Cycles**) → REVIEWER
  (APPROVE, 2 medium + 2 low, alle non-blocking → Follow-up #42) → CSO (PASS) → Merge. Der REVIEWER
  prüfte die Nebenläufigkeit fundiert (await-Punkte, Double-Free, Timeout-Race) und fand **kein**
  critical/high-Problem. ~215k Tokens.
- **Arm B (Single-AI, Sonnet):** race-sichere Implementierung eigenständig korrekt gelöst — synchroner
  kritischer Abschnitt (kein `await` zwischen Bestandsprüfung und Abzug), idempotentes `release`,
  no-op-Timeout nach manueller Freigabe. **4/4 Verhaltens-ACs grün, Lint sauber, 0 escaped defects.** ~30s.

**Kernaussage:** Beide Arme lieferten korrekten, race-sicheren Code. Das Framework fing nichts, weil das
fähige Modell nichts falsch machte. Der 0-Review-Cycle-Verlauf (dank #14-Fix) war sauber, aber der
~7×-Overhead kaufte hier **Audit-Trail + Konsistenz, nicht Defekt-Vermeidung**.

**Der #14-Fix wirkt (Kontrast zu T3):** Bei T7 blockierten die 2 medium + 2 low Findings den Merge NICHT
(→ Follow-up-Issue), 0 Cycles. Bei T3 (vor dem Fix) trieben genau solche Findings 3 Cycles. Die
Cycle-Explosion ist behoben.

## Gesamtfazit (revidiert, ehrlich)

Die ursprüngliche Effizienz-These („Pipeline besser/effizienter als Single-AI") ist über die gemessenen
Paare **nicht belegt** — im Gegenteil: Single-AI erreichte **identische Qualität (0 escaped defects) bei
~7,5× weniger Tokens** über triviale UND komplexe Tasks.

Der eigentliche Erkenntnisgewinn ist eine **Neuformulierung der Framework-Nische**:

- **Der Framework-Nutzen ist eine Funktion der Modell-Schwäche relativ zur Aufgabe, nicht der
  Task-Komplexität allein.** Wo Defekte auftraten (T3, mittlere Stufe, **Haiku**), fing das Framework sie
  (CI-Regression, ac3-Scheinabdeckung). Wo ein fähiges Modell (**Sonnet**) sauber lieferte (T7, komplex),
  fing das Framework nichts — es gab nichts zu fangen.
- **Konsequenz für das Produkt:** Das Framework rechtfertigt seinen Overhead nicht über „schwere Tasks",
  sondern über **(a) schwache/billige Modelle, (b) Audit-/Compliance-Pflicht (nachvollziehbare Rollen,
  Verdikte, Guards), (c) mehrdeutige Anforderungen** (wo ARCHITECT/REVIEWER echten Wert schaffen). Für
  fähige Modelle auf gut spezifizierten Tasks ist **Single-AI + starker Referee (Contract + CI)** — die
  „Solo-Lane" — effizienter, unabhängig von der Komplexität.
- **Revidierte Solo-Lane-Empfehlung:** Nicht nur für triviale Tasks. Default = Single-AI + Contract/CI;
  Eskalation in die volle Pipeline nur bei (a)/(b)/(c) oben. Das dreht die Standardannahme um.

Wichtige Einschränkungen dieser Aussage siehe Threats to Validity — insbesondere n=1 je Komplexität,
ungemessene T7-B-Tokens und die Modell-Abhängigkeit (die selbst der zentrale Befund ist).

## Threats to Validity

- **n=1 je Komplexität** (trivial n=2, komplex n=1, mittel als Paar gar nicht gemessen). Keine
  statistische Signifikanz — Indikation, kein Beweis.
- **Modell-Confound (zugleich der zentrale Befund):** Arm A und Arm B liefen bei T7 auf Sonnet, T3-Arm-A
  auf Haiku. Die Beobachtung „Defekte bei Haiku (T3), keine bei Sonnet (T7)" vermischt Komplexität und
  Modell-Tier. Genau diese Vermischung deutet aber auf die Modell-Abhängigkeit hin — sie sauber zu
  trennen bräuchte ein 2×2-Design (Haiku/Sonnet × mittel/komplex).
- **T7-B-Tokens ungemessen** (Session-Limit) → das Token-Verhältnis der komplexen Stufe ist geschätzt.
  Die Qualitäts-Aussage (escaped=0) beruht auf empirischen Verhaltens-Tests, nicht auf der Schätzung.
- **Referee-Asymmetrie:** Arm B wurde bei T7 gegen **Verhaltens-ACs** (nicht den Arm-A-frozen-Contract)
  bewertet, weil Arm B eine andere, ebenso valide API wählte. Das ist fairer (misst Verhalten statt
  Signatur), aber weicht vom „identischen Contract"-Ideal ab.
- Escaped defects hängen an der Güte des Referees. T3 zeigte: ein Contract kann eine Abdeckung nur
  vortäuschen (ac3) — dann ist das Arm-B-Netz schwächer als es scheint (der REVIEWER fing es in Arm A).
- Ein Operator, ein Repo, ein Stack, ein Zeitraum. Mehrere Arm-A-Läufe brauchten Operator-Rettung
  (Deadlocks, Contract-Restore) — diese Fragilität ist teils G13-spezifisch (ci.yml-Drift), teils
  Framework-Gap (inzwischen #12/#13/#14 behoben).

## Rohdaten

`experiment/results.tsv` (eine Zeile je Task × Arm). Aggregation reproduzierbar via
`bash experiment/collect.sh`.
