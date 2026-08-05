# Agenten-Protokoll — kanonische Schemata

```
protocol_version: 2
```

<!-- Geschützter Pfad (Guard: protected-paths). Änderungen nur durch den Menschen. -->

Dieses Dokument ist die einzige Quelle für alle maschinenlesbaren Formate:
Kommentar-Blöcke, geparste Body-Felder, Findings-Zeilen, Session-Signale.

Autoritätsregel: Das Label führt. Kommentar-Blöcke transportieren Kontext und
Audit-Trail — bei Widerspruch gilt das Label. Ein fehlender oder ungültiger Block
stoppt die Pipeline nicht, ist aber ein Retro-Finding.

---

## 0 — Parsing-Konventionen

- Ein Block ist ein GitHub-Kommentar, dessen ERSTE Zeile exakt `### <TYP>` ist
  (Typen: HANDOFF, ESCALATION, DECISION). Kein Text vor oder nach dem Block im selben Kommentar.
- Felder: `key: value`, ein Feld pro Zeile, Reihenfolge wie im Schema.
  Parser matchen per Key; unbekannte Felder werden ignoriert (Vorwärtskompatibilität).
- Mehrzeilige Werte: `key: |`, Folgezeilen mit 2 Leerzeichen eingerückt (YAML-Blockstil).
- Enum-Werte exakt wie gelistet, lowercase. Issue-/PR-Referenzen immer mit `#`.
- Pro Objekt gilt der jeweils JÜNGSTE Block eines Typs.
- Zeilen mit Präfix `AUTO:` stammen ausschließlich aus GitHub-Workflows.
  Agenten posten sie nie und behandeln sie als informativ (Label führt).

---

## 1 — CLAIM (einzeilig)

```
CLAIM <rolle> <UTC-ISO-8601>
```

- `rolle` ∈ `architect` | `developer` | `reviewer` | `cso`
- Beispiel: `CLAIM developer 2026-07-06T14:03:22Z`

| Rolle | Ort | Label-Wechsel beim Claim |
|---|---|---|
| architect | Epic | `status:ready` → `status:in-progress` |
| developer | Story | `status:ready` → `status:in-progress` |
| reviewer | PR | keiner (nur Kommentar; Label erst beim Verdikt) |
| cso | PR | keiner (nur Kommentar; Label erst beim Verdikt) |

**Verify-Regel:** Nach dem Claim Objekt zurücklesen. Ist ein fremder CLAIM jünger,
bricht der Verlierer ab und nimmt den nächsten Kandidaten. Er setzt kein Label
zurück — der Zielzustand ist durch den Gewinner bereits korrekt.

`retro` claimt nicht. Guard stattdessen: existiert ein offener `type:retro`-PR → Abbruch.

---

## 2 — HANDOFF

```
### HANDOFF
from: <rolle>
to: <rolle|human>
issue: #<nr>
pr: #<nr> | none
branch: <branchname> | none
cycle: <int>
blockers: none | <text>
notes: |
  <freitext>
```

**Pflichtfelder:** `from`, `to`, `issue`, `pr`, `branch`, `blockers`.
`cycle` ist Pflicht, sobald `pr ≠ none`; sonst weglassen. `notes` optional.

`cycle` erhöht AUSSCHLIESSLICH der Developer bei jeder Submission auf
`status:needs-review` (Erst-Submission = 1). Alle anderen Rollen übernehmen den
Wert unverändert. Der Reviewer prüft `cycle ≥ limits.review_zyklen_max` → ESCALATION.

`blockers` = bekannte Einschränkungen, die die nächste Rolle kennen muss, aber
keinen Stopp rechtfertigen. Rechtfertigt etwas einen Stopp → ESCALATION, kein HANDOFF.

Ort: am PR, sobald `pr ≠ none`; sonst am referenzierten Issue (architect: am Epic).

**Gültige Übergänge und das Label, das der Absender VOR dem HANDOFF setzt:**

| from | to | Absender setzt | Ort |
|---|---|---|---|
| architect | developer | Stories: `status:ready` bzw. `status:backlog`; Epic: `status:in-progress` | Epic |
| developer | reviewer | `status:needs-review` (Story UND PR) | PR |
| reviewer | developer | `status:changes-requested` | PR |
| reviewer | cso | `status:security-review` | PR |
| cso | developer | `status:security-blocked` | PR |
| cso | human | `status:approved` | PR |
| retro | human | `needs-human` (am `type:retro`-PR) | Retro-PR |

Jede andere `from/to`-Kombination ist ungültig.

**Beispiel:**

```
### HANDOFF
from: developer
to: reviewer
issue: #42
pr: #57
branch: story/42-login-endpoint
cycle: 2
blockers: none
notes: |
  Re-Submission nach changes-requested. Finding [layer] src/api/login.py:31
  behoben: Redis-Zugriff in SessionAdapter (Infrastructure) verschoben.
  contract: red@a1b2c3d → green@e4f5a6b
```

---

## 3 — ESCALATION

```
### ESCALATION
from: <rolle>
issue: #<nr>
pr: #<nr> | none
reason: <slug>
detail: |
  <was genau, mit Belegen (Datei:Zeile, AC-ID, Issue#)>
options: |
  (a) <option>
  (b) <option>
recommendation: (a) | (b) | none
```

`reason` ist ein Slug aus genau dieser Tabelle (Freitext gehört in `detail`) —
nur so kann die Retro nach `reason` aggregieren:

| reason-Slug | typische Rolle |
|---|---|
| `anforderung-mehrdeutig` | architect |
| `architektur-entscheidung` | architect |
| `scope-wachstum` | architect |
| `zyklische-abhaengigkeit` | architect |
| `epic-dor-verletzt` | architect |
| `epic-bereits-implementiert` | architect |
| `ac-nicht-umsetzbar` | developer |
| `breaking-change` | developer |
| `aufwand-ueberschritten` | developer |
| `destruktive-migration` | developer |
| `neue-dependency` | developer |
| `pipeline-stalled` | developer |
| `review-zyklen-max` | reviewer |
| `dsgvo-flag-widerspruch` | cso |
| `dsgvo-rechtsfrage` | cso |
| `cve-ohne-patch` | cso |
| `risikoakzeptanz-noetig` | cso |
| `sonstiges` (detail zwingend) | alle |

**Begleitaktionen (zwingend, in dieser Reihenfolge):**
Block posten (am PR, falls vorhanden, sonst am Issue) →
Label `needs-human` auf Issue UND PR (falls beide existieren; das `status:`-Label bleibt stehen) →
Assignee auf den Menschen aus der Projektkonfiguration →
Session mit Signal-Zeile `ESCALATED` beenden (§5).

---

## 3b — DECISION (postet ausschließlich der Mensch)

Beim Auflösen einer `needs-human`-Eskalation postet der Mensch diesen Block
am Issue oder PR, bevor er das Label entfernt:

```
### DECISION
issue: #<nr>
escalation: <reason-slug>
choice: (a) | (b) | custom
rationale: |
  <1–3 Sätze>
adr: yes | no
```

- `adr: yes` → der RETRO-Agent erstellt daraus einen ADR in `docs/adr/`
- `adr: no` → Entscheidung ist nur im Issue-Thread dokumentiert
- `choice: custom` erfordert vollständiges `rationale`

**Beispiel:**

```
### DECISION
issue: #42
escalation: neue-dependency
choice: (b)
rationale: |
  PyJWT ist bereits als transitive Dependency vorhanden (via authlib).
  Direkter Import spart eine neue Top-Level-Dependency.
adr: no
```

---

## 4 — Geparste Body-Felder und Findings-Zeilen

**Issue-/PR-Bodies** (je genau eine Zeile, Regex verbindlich):

- `depends-on` (user-story.md):
  `^depends-on: (none|#[0-9]+(, #[0-9]+)*)$`
- `closes`-Referenz (PR-Body, case-insensitive, von `invalidate-verdict` geparst):
  `closes #<nr>`
- Glossar-Kandidat (user-story.md, eine Zeile pro Begriff):
  `- <Begriff> — <Ein-Satz-Definition>` oder `- none`

**Findings-Zeile** (Reviewer- und CSO-Kommentare, von der Retro geparst):

```
- [<severity>][<kategorie>] <ort> — <problem> → <geforderte änderung>
```

- `severity` ∈ `critical` | `high` | `medium` | `low`
- `kategorie` ∈ `layer` | `glossar` | `test-luecke` | `ac-abdeckung` | `commit-konvention` |
  `secrets` | `auth` | `input-validierung` | `dsgvo` | `dependency` |
  `observability` | `performance` | `sonstiges`
- `ort`: empfohlen `pfad:zeile`; bei Dependencies `paketname==version` zulässig
- Regex: `^- \[(critical|high|medium|low)\]\[[a-z-]+\] .+ — .+ → .+$`

---

## 5 — Session-Signale (letzte Zeile der letzten Agenten-Nachricht)

Jede Rolle beendet ihre Session mit genau EINER dieser Zeilen. Der
`/pipeline`-Orchestrator parst sie für seine Schleifenentscheidung; in Modell B
liest sie der Mensch im Terminal.

```
DONE <rolle> issue:#<nr> pr:#<nr>|none → status:<label>
ESCALATED <rolle> issue:#<nr> reason:<slug>
QUEUE EMPTY <rolle>
PIPELINE STALLED — mögliche Abhängigkeits-Blockade: #<nr>[, #<nr>…]
```

**Beispiele:**
- `DONE reviewer issue:#42 pr:#57 → status:security-review`
- `ESCALATED architect issue:#40 reason:epic-dor-verletzt`
- `QUEUE EMPTY developer`
- `PIPELINE STALLED — mögliche Abhängigkeits-Blockade: #38, #41`
