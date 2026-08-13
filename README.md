# Agentic Dev Framework

**GitHub als einziger Orchestrator für KI-gestützte Softwareentwicklung.**

Fünf spezialisierte KI-Agenten arbeiten koordiniert über GitHub-Issues, Labels und Pull Requests — ohne Backend, ohne Daemon, ohne Konflikte. Vollständiger Audit-Trail. Modell-agnostisch: funktioniert mit Claude, GPT-4, Gemini und jedem anderen Modell mit Terminal-Zugang.

```
[type:input Issue]
     ↓
  ARCHITECT  — zerlegt Anforderungen in atomare Stories
     ↓
  DEVELOPER  — implementiert gegen einen Test-Contract (TDD)
     ↓
  REVIEWER   — prüft Architektur, ACs, Observability
     ↓
    CSO      — prüft Secrets, PII, Auth, Dependencies
     ↓
  [Mensch mergt] — einziger erlaubter Merger
     ↓
   RETRO     — aggregiert Findings, aktualisiert Glossar und Docs
```

---

## Inhaltsverzeichnis

1. [Was ist das und warum?](#1--was-ist-das-und-warum)
2. [Kernkonzept: GitHub als Orchestrator](#2--kernkonzept-github-als-orchestrator)
3. [Die fünf Agenten-Rollen](#3--die-fünf-agenten-rollen)
4. [Der vollständige Workflow](#4--der-vollständige-workflow)
5. [Schnellstart — Phase 0 Setup](#5--schnellstart--phase-0-setup)
6. [Tägliche Arbeit](#6--tägliche-arbeit)
7. [Issue-Typen und Templates](#7--issue-typen-und-templates)
8. [Label-Taxonomie](#8--label-taxonomie)
9. [CI-Setup](#9--ci-setup)
10. [Projektkonfiguration (CLAUDE.md)](#10--projektkonfiguration-claudemd)
11. [Protokoll und Handoffs](#11--protokoll-und-handoffs)
12. [Verzeichnisstruktur](#12--verzeichnisstruktur)
13. [FAQ](#13--faq)

---

## 1 — Was ist das und warum?

### Das Problem

KI-unterstützte Entwicklung bricht typischerweise auf dieselben drei Weisen zusammen:

1. **Kein Einstiegspunkt**: Die KI öffnet eine Session und beginnt sofort zu coden — ohne Issue, ohne Branch, ohne nachvollziehbaren Schritt.
2. **Kein Audit-Trail**: Nach einer Woche weiß niemand mehr, warum eine Architekturentscheidung so getroffen wurde.
3. **Inkonsistenz**: Unterschiedliche KI-Modelle, unterschiedliche Sessions, unterschiedliches Ergebnis.

### Die Lösung

Dieses Framework macht **GitHub zum Single Point of Truth**. Jeder Zustand — jede Anforderung, jede Aufgabe, jede Entscheidung, jeder Fortschritt — ist in GitHub sichtbar. Labels sind die State Machine. Kein Agent hält Zustand im Kopf. Jede Session kann kalt starten und den exakten Stand aus GitHub rekonstruieren.

### Für wen

- Entwickler-Teams (2–10 Personen) die mit KI-Agenten zusammenarbeiten
- Solo-Entwickler die mehrere Projekte parallel führen
- Teams die Transparenz und Rückverfolgbarkeit in KI-gestützter Entwicklung brauchen
- Funktioniert mit Claude Code, Cursor, GitHub Copilot, oder jedem LLM mit Terminal-Zugang

---

## 2 — Kernkonzept: GitHub als Orchestrator

```
GitHub Issues  = Task-Speicher     (was muss gebaut werden)
GitHub Labels  = State Machine     (in welchem Zustand ist alles)
PR-Kommentare  = Handoff-Bus       (wie übergeben Agenten die Arbeit)
Branch Prot.   = Hard Gates        (was ist technisch erzwungen)
```

**Die Grundregel:** Kein Code ohne Issue. Kein Issue ohne Label. Kein Merge ohne menschlichen Review.

### State Machine

```
[type:input]  →  ARCHITECT formalisiert  →  [type:epic]
                                                 ↓
status:backlog → status:ready → status:in-progress → status:needs-review
                                                           ↓
                                              status:changes-requested
                                                           ↓
                                                status:security-review
                                                           ↓
                                               status:security-blocked
                                                           ↓
                                                  status:approved
                                                           ↓
                                              [MENSCH: Merge] → status:done
```

`needs-human` überlagert jeden Zustand und stoppt alle Agenten sofort.

---

## 3 — Die fünf Agenten-Rollen

| Rolle | Aufgabe | Schreibrechte |
|---|---|---|
| **ARCHITECT** | Roheingaben (type:input) formalisieren, Epics in Stories und Tasks zerlegen. Einziger Agent mit Issue-Erstellungsrecht. | Issues |
| **DEVELOPER** | Genau eine Story pro Session implementieren. Startet mit Test-Contract (rote Tests zuerst), implementiert dagegen. | Code, Tests, Docs, PR |
| **REVIEWER** | PRs auf AC-Qualität, Architektur, Observability und Performance prüfen. Deterministisches prüft CI — der Reviewer urteilt. | Labels, Kommentare |
| **CSO** | Defensive Sicherheitsprüfung: Secrets, PII, AuthN/Z, Input-Validierung, DSGVO, Dependencies. Letzte automatische Instanz vor dem Merge. | Labels, Kommentare |
| **RETRO** | Nach N Merges: Findings aggregieren, Muster erkennen, ADRs schreiben, Glossar aktualisieren, Verbesserungs-PR erstellen. | `docs/` |

### Was jede Rolle niemals tut

- **ARCHITECT**: keinen Code schreiben, keine Issues anlegen ohne DoR-Gate
- **DEVELOPER**: nie direkt auf `main` pushen, nie mehr als eine Story pro PR
- **REVIEWER**: nie selbst Code schreiben, nie `gh pr review --approve`
- **CSO**: kein Pentesting, keinen Fix-Code schreiben
- **RETRO**: nichts außerhalb von `docs/` anfassen
- **Alle**: `.claude/`, `.github/`, `CLAUDE.md`, `docs/PROTOCOL.md` nie ändern

---

## 4 — Der vollständige Workflow

### Schritt-für-Schritt (ein kompletter Durchlauf)

**1. Mensch erstellt type:input Issue** (30 Sekunden)
```
[INPUT] PDF-Dokumente hochladen und für Abfragen bereitstellen

Was möchtest du?
PDFs hochladen, automatisch chunken, embedden, in Vektordatenbank laden.

Warum?
Das ist der Kern des Systems.
```

**2. ARCHITECT — Phase A: Input → Epic**
- Liest den rohen Input
- Formalisiert ihn zu einem strukturierten Epic (DoR-Gate: Problem lösungsfrei, Erfolgskriterium messbar, Scope explizit)
- Schließt das Input-Issue, erstellt das Epic

**3. ARCHITECT — Phase B: Epic → Stories**
- DoR-Gate: alle Felder prüfen
- Splitting-Algorithmus: Modul-Grenze → Größe → Deployment-Abhängigkeit
- **Preflight-Existenz-Check** (`scripts/preflight.sh`): jeder Story-Entwurf wird ohne KI
  gegen die Codebase geprüft. Existiert die Funktionalität schon (starkes Identifier-Signal),
  wird die Story nicht als Neubau angelegt, sondern verworfen oder als Refactor reframed.
  Verhindert redundante Stories. Liefert außerdem eine Modell-Empfehlung (Haiku/Sonnet/Opus).
- Kahn-Algorithmus: Abhängigkeitsgraph, Zyklusprüfung, topologische Sortierung
- Stories in korrekter Reihenfolge anlegen (`depends-on`-Felder zeigen auf existierende Nummern)
- Nur abhängigkeitsfreie Stories bekommen `status:ready`

**4. DEVELOPER — Story implementieren**
- CLAIM mit Verify (Race-Condition-Schutz)
- Worktree-Branch anlegen: `story/<nr>-<slug>`
- test-author Subagent: rote Acceptance-Tests schreiben, Rot-Beweis erbringen
- Implementierung gegen den Contract (grüne Tests = fertig)
- Gate lokal grün (lint, typecheck, coverage, glossar)
- PR erstellen, `closes #<story-nr>` in Body

**5. REVIEWER — PR prüfen**
- CI-Gates: alle required Checks grün? Sonst sofort zurück.
- 6 Prüfpunkte: AC-Qualität, Vollständigkeit, Architektur/Layer, Docs, Observability, Performance-Heuristiken
- Findings im Format: `- [severity][kategorie] pfad:zeile — Problem → Lösung`
- Verdikt: `status:security-review` (sauber) oder `status:changes-requested` (Findings)

**6. CSO — Sicherheitsprüfung**
- Secrets-Scan auf allen `+`-Zeilen im Diff
- PII-Pattern-Scan (aus `pii_patterns` in CLAUDE.md)
- AuthN/AuthZ-Tabelle für jeden neuen Endpoint
- Input-Validierung, DSGVO, pip-audit
- Verdikt: `status:approved` (PASS) oder `status:security-blocked` (Blocker)

**7. Mensch — Merge**
- Einziger der `gh pr merge` ausführen darf
- CODEOWNERS erzwingt: nie den eigenen PR mergen

**8. Automatisch nach Merge**
- `invalidate-verdict.yml` schützt zukünftige PRs
- Pipeline löst wartende Stories auf (`depends-on` erfüllt → `status:ready`)
- Nach N Merges: RETRO erstellt Verbesserungs-PR

---

## 5 — Schnellstart — Phase 0 Setup

**Dauer: ca. 2 Stunden (einmalig)**

### Repository anlegen

```bash
# Option A: Dieses Repo als Template
gh repo create mein-projekt --template etienne-mathis/agentic-dev-framework --private
cd mein-projekt

# Option B: Manuell (Inhalte dieses Repos in bestehendes Repo kopieren)
cp -r agentic-dev-framework/.claude ./
cp -r agentic-dev-framework/.github ./
cp -r agentic-dev-framework/docs ./
cp -r agentic-dev-framework/scripts ./
cp -r agentic-dev-framework/setup ./
cp agentic-dev-framework/CLAUDE.md ./
```

### Labels anlegen

```bash
bash setup/labels.sh
# → 23 Labels werden angelegt
```

### CI aktivieren

```bash
# ci-skeleton.yml umbenennen und befüllen
cp .github/workflows/ci-skeleton.yml .github/workflows/ci.yml
# Datei öffnen und anpassen:
# - Python-Version
# - uv sync / pip install Befehle
# - befehle.gate aus CLAUDE.md eintragen
```

### Branch Protection in GitHub Settings

Unter `Settings → Branches → Add rule` für `main`:
- [x] Require a pull request before merging
- [x] Require approvals: **1**
- [x] Dismiss stale reviews when new commits are pushed
- [x] Require status checks: `test` · `gates` · `audit` · `commitlint` · `protected-paths` · `test-contract`
- [x] Restrict pushes that create matching branches
- [x] Allow force pushes: **Nein**

### CODEOWNERS setzen

```bash
# .github/CODEOWNERS öffnen und eigenen Handle eintragen:
# * @dein-github-handle
# Bei mehreren Personen:
# * @person1 @person2
```

### CLAUDE.md konfigurieren

Den `## Projektkonfiguration`-Block in `CLAUDE.md` vollständig ausfüllen:

```yaml
projekt: mein-projekt
mensch: @dein-github-handle
default_branch: main
stack: python-fastapi    # python-fastapi | node | andere

befehle:
  test: uv run pytest
  lint: uv run ruff check .
  typecheck: uv run mypy src
  gate: >
    uv run ruff check . &&
    uv run mypy src &&
    uv run pytest --cov --cov-report=xml &&
    uv run diff-cover coverage.xml --compare-branch=origin/main --fail-under=90 &&
    bash scripts/glossar_gate.sh

layer_mapping:
  presentation: src/api/
  application:  src/application/
  domain:       src/domain/
  infrastructure: src/infrastructure/

module:
  - ingestion
  - embedding
  # usw.

glossar: docs/GLOSSARY.md
dsgvo_relevant: true

audit:
  block_ab: high    # critical | high | medium | low

limits:
  task_max_h: 8
  tasks_pro_story: 3
  review_zyklen_max: 2
  retro_intervall_merges: 5
  muster_schwelle: 3
```

### Glossar seeden

```bash
# docs/GLOSSARY.md öffnen
# 5–10 Kernbegriffe des Projekts eintragen
# Format: | Begriff | Definition | Verboten (Synonyme) |
# Beispiel:
# | Chunk | Atomare Texteinheit aus einem Document | fragment, piece, segment |
```

### Smoke-Test

```bash
# 1. Dummy-Input erstellen
gh issue create \
  --title "[INPUT] Smoke-Test: Hello World Endpoint" \
  --body "Was möchtest du? Einen GET /health Endpoint der {status: ok} zurückgibt." \
  --label "type:input,status:triage"

# 2. Claude Code starten und testen ob Pipeline anläuft:
# /init
# /pipeline

# 3. Ergebnis prüfen: Epic + Stories angelegt?
# 4. Dummy-Issues schliessen
gh issue list | grep -E "EPIC|STORY|TASK" | awk '{print $1}' | \
  xargs -I{} gh issue close {} --reason not_planned
```

---

## 6 — Tägliche Arbeit

### Deine drei Aufgaben — mehr nicht

```
1. type:input Issues erstellen    → 30 Sekunden pro Idee
2. status:approved PRs mergen     → du bist der einzige Merger
3. needs-human Eskalationen lösen → Entscheidung treffen, DECISION-Block posten
```

Alles andere macht die Pipeline.

### Die nicht verhandelbare Startregel

```
Jede Session beginnt mit /init — keine Ausnahme.
```

Nie mit "Implementier X" starten. Immer `/init` zuerst.

### Session-Typen

**Vollautomatisch** (Standard):
```
/init
/pipeline
```
Läuft durch bis die Queue leer ist oder `needs-human` stoppt.

**Gezielt** (eine bestimmte Arbeit beobachten):
```
/init
"Du bist DEVELOPER. Übernimm Story #7."
```

**Neue Anforderung**:
```
→ GitHub: New Issue → Template "Input (Rohanforderung)" → ausfüllen
→ /pipeline
```

### Modell-Routing

Zwei Betriebsarten, bewusst getrennt:

- **`/pipeline` (Claude-Code-Orchestrator)** — wählt pro Queue-Item automatisch das Modell
  aus der Preflight-Empfehlung (`preflight-modell:` in der Story bzw. Preflight-Nachlauf)
  und spawnt jede Rolle als eigenen Sub-Agenten im passenden Tier (Haiku/Sonnet/Opus).
  Die Rollen laufen mit **Hybrid-Isolation**: zwischen Rollen ist der Kontext inhärent
  getrennt (jeder Spawn startet kalt, liest den Zustand nur aus GitHub), sodass REVIEWER und
  CSO nie DEVELOPER-Kontext sehen; innerhalb der DEVELOPER-Phase teilen Implementierung und
  Sub-Delegation den Kontext (der `test-author` bleibt auf die Story-Nummer isoliert).
  Ist ein empfohlenes Modell nicht verfügbar, fällt der Orchestrator auf das nächstniedrigere
  Tier zurück.
- **Manuelle Sessions (getrennte Sessions)** — der generische, anbieterunabhängige Standard.
  Jede Rolle in einer eigenen Session, Modellwahl durch den Menschen. Funktioniert mit jedem
  LLM mit Terminal-Zugang. Der Orchestrator ist ein Komfort-Layer obendrauf, kein Ersatz.

### Eskalationen lösen (needs-human)

Wenn ein Agent stoppt und `needs-human` setzt:

```bash
# Eskalation lesen
gh issue list --label "needs-human"

# Entscheidung als DECISION-Block posten
gh issue comment <nr> --body "### DECISION
issue: #<nr>
escalation: <reason-slug>
choice: (a)
rationale: |
  Kurze Begründung (1–3 Sätze).
adr: no"

# Label entfernen damit die Pipeline weiterlaufen kann
gh issue edit <nr> --remove-label "needs-human"
```

### Für Teams (mehrere Personen)

```bash
# Person A:  /init → "Du bist ARCHITECT. Queue prüfen."
# Person B:  /init → "Du bist DEVELOPER. Story #4 übernehmen."
```

CLAIM-Mechanismus verhindert Kollisionen automatisch. CODEOWNERS stellt sicher: wer den Code schreibt, mergt nicht selbst.

---

## 7 — Issue-Typen und Templates

### type:input — Roheingabe (vom Menschen)

```
[INPUT] Kurze Beschreibung der Anforderung

Was möchtest du?
Freitext — ein Satz reicht. Kein technischer Aufwand nötig.

Warum? (optional)
Das eigentliche Problem dahinter.

Beispiel / Skizze (optional)
Screenshot, Pseudocode, Beispieldaten — alles willkommen.
```

→ Wird vom **ARCHITECT** in ein strukturiertes Epic formalisiert.

### type:epic — Strukturierte Anforderung (vom ARCHITECT)

Vom ARCHITECT erstellt aus einem type:input. Enthält:
- Problem & Outcome (lösungsfrei)
- Erfolgskriterium (messbar)
- Scope In/Out (explizit)
- Betroffene Module
- Definition of Ready (Gate für ARCHITECT)

### type:story — Implementierbare Story (vom ARCHITECT)

Vertikal geschnitten, INVEST-konform. Enthält:
- Story-Satz (Als X möchte ich Y, damit Z)
- Acceptance Criteria mit Given/When/Then
- `depends-on`-Feld
- INVEST-Check

### type:task — Technischer Subtask (vom ARCHITECT)

Enthält: Scope-Tabelle mit Layer und Pfaden, technische Vorgaben (Port/Adapter), Test-Mapping, Observability-Anforderung.

---

## 8 — Label-Taxonomie

### Status-Labels (genau eines pro Issue/PR)

| Label | Bedeutung |
|---|---|
| `status:triage` | Roheingabe, wartet auf ARCHITECT |
| `status:backlog` | Angelegt, wartet auf Freigabe (depends-on) |
| `status:ready` | Bereit für den nächsten Agenten |
| `status:in-progress` | Wird aktuell bearbeitet |
| `status:needs-review` | PR eingereicht, wartet auf REVIEWER |
| `status:changes-requested` | Findings vom REVIEWER → zurück an DEVELOPER |
| `status:security-review` | Beim CSO |
| `status:security-blocked` | CSO hat Blocker gefunden |
| `status:approved` | Bereit zum Mergen (durch Menschen) |
| `status:done` | Abgeschlossen |

### Typ-Labels

| Label | Bedeutung |
|---|---|
| `type:input` | Roheingabe vom Menschen |
| `type:epic` | Strukturiertes Feature |
| `type:story` | Implementierbare Story |
| `type:task` | Technischer Subtask |
| `type:retro` | Retrospektiv-PR |

### Steuerungs-Labels

| Label | Bedeutung |
|---|---|
| `needs-human` | Eskalation — alle Agenten stoppen |
| `source:retrospective` | Issue aus Retro-Ergebnis |
| `perf-kritisch` | Performance-Anforderung (aktiviert Lasttest im REVIEWER) |

### Human-Override-Labels (nur durch Menschen setzbar)

| Label | Bedeutung |
|---|---|
| `human-override:protected-paths` | Erlaubt Änderungen an Framework-Dateien |
| `human-override:test-contract` | Erlaubt Änderung des Acceptance-Contracts |
| `human-override:api-breaking` | Erlaubt API-Breaking-Change |

---

## 9 — CI-Setup

### Sofort aktive Workflows (kein Setup nötig)

Diese drei Workflows laufen automatisch auf jedem PR — ohne Konfiguration:

| Workflow | Was er tut |
|---|---|
| `invalidate-verdict` | Neuer Commit auf PR → Label zurück auf `status:needs-review` |
| `protected-paths` | Blockiert Änderungen an Framework-Dateien ohne Override-Label |
| `test-contract` | Stellt sicher dass Acceptance-Tests nach Contract-Commit unveränderlich bleiben |

### CI-Template einrichten (ca. 15 Minuten)

Das Framework liefert `setup/ci.yml.example` — ein vollständig kommentiertes Template mit vier Jobs:

| CI-Job | Prüft | Required Check |
|---|---|---|
| `test` | Vollständige Testsuite | Ja |
| `gates` | Lint, Typecheck, Coverage-Diff ≥90%, Glossar-Gate | Ja |
| `audit` | Dependency-Vulnerabilitäten (pip-audit / npm audit) | Ja |
| `commitlint` | Commit-Message-Format `type(scope): text (#nr)` | Ja |

**Erlaubte Commit-Typen:** `feat` · `fix` · `refactor` · `test` · `docs` · `chore`

**Aktivierung:**
```bash
# Template kopieren
cp setup/ci.yml.example .github/workflows/ci.yml

# Datei öffnen und befüllen:
# 1. <<<PYTHON_VERSION>>> oder <<<NODE_VERSION>>> ersetzen
# 2. <<<BEFEHLE_*>>> durch echte Befehle aus CLAUDE.md ersetzen
# 3. Nicht genutzten Stack (Python ODER Node) löschen
# 4. Committen

# Branch Protection aktivieren:
# Settings → Branches → main → Require status checks:
# test · gates · audit · commitlint
```

> **Warum liegt das Template in `setup/` und nicht in `.github/workflows/`?**
> GitHub führt automatisch alle `.yml`-Dateien in `.github/workflows/` aus.
> Ein Template mit Platzhaltern würde sofort fehlschlagen.
> Erst nach dem Befüllen und Umbenennen gehört es nach `.github/workflows/`.

---

## 10 — Projektkonfiguration (CLAUDE.md)

`CLAUDE.md` hat zwei Teile:

**Teil 1 — Generisches Protokoll** (nicht anfassen)
Alle Rollenregeln, Verbote, CLAIM-Mechanismus, HANDOFF-Schema.

**Teil 2 — Projektkonfiguration** (einziger Block den du anpasst)
```yaml
## Projektkonfiguration
projekt: <name>
mensch: @<github-handle>
stack: python-fastapi
befehle: ...
layer_mapping: ...
module: [...]
glossar: docs/GLOSSARY.md
dsgvo_relevant: true/false
audit:
  block_ab: high
limits: ...
```

Alle Agenten lesen diese Konfiguration beim Start. Kein Hardcoding in Agent-Prompts.

---

## 11 — Protokoll und Handoffs

### CLAIM (Race-Condition-Schutz)

Jeder Agent claimt ein Issue/PR bevor er arbeitet:

```bash
gh issue edit <nr> --add-label "status:in-progress"
gh issue edit <nr> --assignee @me
gh issue comment <nr> --body "CLAIM architect 2026-08-03T14:02:11Z"
# Zurücklesen — jüngster CLAIM muss von mir sein
gh issue view <nr> --json labels,comments,assignees
```

Wenn ein fremder CLAIM jünger ist: abbrechen, nächsten Kandidaten nehmen.

### HANDOFF (Agenten-Übergabe)

```
### HANDOFF
from: developer
to: reviewer
issue: #3
pr: #9
branch: story/3-mein-feature
cycle: 1
blockers: none
notes: |
  Erstsubmission. Contract: red@abc1234 → green@def5678.
```

### ESCALATION (Stopp + Menschliche Entscheidung)

```
### ESCALATION
from: architect
issue: #5
pr: none
reason: anforderung-mehrdeutig
detail: |
  AC-2 nennt "schnell" ohne Schwellwert. Was bedeutet das messbar?
options: |
  (a) <200ms p95 unter 100 concurrent requests
  (b) "schnell" aus den ACs entfernen — kein Performance-Requirement
recommendation: (a)
```

Vollständige Protokoll-Spezifikation: `docs/PROTOCOL.md`

---

## 12 — Verzeichnisstruktur

```
.
├── CLAUDE.md                         # Protokoll + Projektkonfiguration (hier anpassen)
├── docs/
│   ├── PROTOCOL.md                   # Kanonische Schemata — nicht ändern
│   ├── GLOSSARY.md                   # Ubiquitous Language des Projekts — seeden
│   ├── product-concept.adoc          # Doc-Kanon: Problem/ICP/Scope (ARCHITECT liest)
│   ├── architecture.adoc             # Doc-Kanon: Stil/Layer/Module/ADRs (ARCHITECT+DEVELOPER)
│   ├── conventions.adoc              # Doc-Kanon: Coding-Konventionen (DEVELOPER liest, REVIEWER prüft)
│   ├── current-state.adoc            # Doc-Kanon: Prosa-Stand (RETRO pflegt)
│   ├── adr/                          # Architecture Decision Records (vom RETRO)
│   └── retrospective/
│       └── TEMPLATE.md               # Retro-Vorlage
├── .claude/
│   ├── agents/
│   │   ├── architect.md              # ARCHITECT-Prompt
│   │   ├── developer.md              # DEVELOPER-Prompt
│   │   ├── reviewer.md               # REVIEWER-Prompt
│   │   ├── cso.md                    # CSO-Prompt
│   │   ├── retro.md                  # RETRO-Prompt
│   │   └── test-author.md            # TEST-AUTHOR-Subagent-Prompt
│   └── commands/
│       ├── init.md                   # /init — Session-Initialisierung (immer zuerst)
│       └── pipeline.md               # /pipeline — vollautomatischer Durchlauf
├── .github/
│   ├── ISSUE_TEMPLATE/
│   │   ├── input.md                  # type:input — Roheingabe (minimal)
│   │   ├── epic.md                   # type:epic
│   │   ├── user-story.md             # type:story
│   │   ├── dev-task.md               # type:task
│   │   └── security-review.md        # CSO-Checkliste
│   ├── PULL_REQUEST_TEMPLATE.md
│   ├── CODEOWNERS                    # Handle(s) eintragen
│   └── workflows/
│       ├── ci-skeleton.yml           # Template → umbenennen zu ci.yml und befüllen
│       ├── invalidate-verdict.yml    # Automatisch aktiv
│       ├── guard-protected-paths.yml # Automatisch aktiv
│       └── guard-test-contract.yml   # Automatisch aktiv
├── scripts/
│   └── glossar_gate.sh               # CI-Job: Synonym-Check gegen GLOSSARY.md
└── setup/
    ├── labels.sh                     # Einmalig ausführen: alle 23 Labels anlegen
    └── rollout-checklist.md          # Detaillierte Setup-Checkliste
```

---

## 13 — FAQ

**Welches KI-Modell brauche ich?**
Jedes Modell das Terminal-Zugang und die `gh` CLI nutzen kann. Getestet mit Claude Code. Funktioniert mit jedem Modell das Bash-Befehle ausführen kann.

**Funktioniert das mit einem Solo-Entwickler?**
Ja. Bei einem Entwickler: CODEOWNERS-Regel vereinfachen oder deaktivieren. Alles andere bleibt gleich.

**Was wenn ein Agent einen Fehler macht?**
`needs-human` setzen (oder der Agent tut es via ESCALATION). Pipeline stoppt. Mensch liest ESCALATION, postet DECISION-Block, entfernt `needs-human`. Pipeline läuft weiter.

**Wie passe ich die Agenten an?**
Alle Prompts liegen in `.claude/agents/`. Änderungen brauchen `human-override:protected-paths` (Label nur durch Menschen setzbar) — dieser Schutzmechanismus verhindert, dass Agenten ihre eigenen Regeln ändern.

**Wie füge ich projektspezifische Sicherheitsregeln hinzu?**
In der Projektkonfiguration (`## Projektkonfiguration` in `CLAUDE.md`): `pii_patterns` erweitern, `dsgvo_relevant: true` setzen, RAG-spezifische Verbote unter einem eigenen Schlüssel eintragen.

**Was ist der Unterschied zwischen type:input und type:epic?**
`type:input` = rohe Idee, kein Aufwand, 30 Sekunden. `type:epic` = strukturierte Anforderung mit DoR-Gate, vom ARCHITECT erstellt. Nie ein Epic von Hand schreiben — das ist ARCHITECTs Aufgabe.

**Kann ich das Framework für Non-Python-Projekte verwenden?**
Ja. In `CLAUDE.md` → `stack: node` setzen und `befehle` auf `npm test`, `npm run lint` etc. anpassen. Das CI-Skeleton enthält Kommentare für Node-Alternativen.

---

## Lizenz

MIT License — verwende und modifiziere frei.

---

## Contributing

Issues und PRs willkommen. Bitte das Framework selbst für Contributions nutzen — jede Änderung startet als `type:input` Issue.
