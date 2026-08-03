# /init — Session-Initialisierung (Pflicht vor jeder Aktion)

Dieser Command wird am Anfang jeder Agenten-Session ausgeführt.
Er erzwingt die Rollenzuweisung und verhindert direktes Arbeiten ohne Issue.

---

## Schritt 1 — Rolle bestimmen

Lies den Startauftrag. Die Rolle steht als erstes Wort:
`ARCHITECT` | `DEVELOPER` | `REVIEWER` | `CSO` | `RETRO`

Kein Startauftrag → frage explizit:
```
Welche Rolle soll ich übernehmen?
ARCHITECT — Epics / Inputs in Stories und Tasks zerlegen
DEVELOPER — Eine Story implementieren
REVIEWER   — PR auf Korrektheit und DoD prüfen
CSO        — PR auf Sicherheit und PII prüfen
RETRO      — Findings aggregieren, Glossar und Docs aktualisieren
PIPELINE   — Alle Rollen automatisch orchestrieren (/pipeline)
```

Keine Antwort → Session beenden. Kein Raten.

---

## Schritt 2 — Repository-Kontext laden

```bash
# Projektkonfiguration vorhanden?
test -f CLAUDE.md && echo "OK" || echo "FEHLER: CLAUDE.md fehlt"

# Glossar laden
cat docs/GLOSSARY.md
```

Fehlt `CLAUDE.md` → Abbruch mit Hinweis: "Kein Framework-Repository. CLAUDE.md anlegen oder in das richtige Verzeichnis wechseln."

---

## Schritt 3 — needs-human prüfen (Blocker)

```bash
gh issue list --label "needs-human" --json number,title,labels \
  --jq '.[] | "#\(.number) \(.title)"'
```

Falls offene `needs-human`-Issues existieren:
- Liste ausgeben
- Melden: "Es gibt offene Eskalationen die menschliche Entscheidung brauchen. Soll ich trotzdem mit der Queue fortfahren oder zuerst die Eskalationen anzeigen?"
- Nicht automatisch fortfahren.

---

## Schritt 4 — Queue-Status anzeigen

```bash
echo "=== QUEUE STATUS ==="
echo "--- type:input (Roheingaben, warten auf ARCHITECT) ---"
gh issue list --label "type:input" --label "status:triage" --json number,title \
  --jq '.[] | "  #\(.number) \(.title)"'

echo "--- type:epic + status:ready (bereit für ARCHITECT) ---"
gh issue list --label "type:epic" --label "status:ready" --json number,title \
  --jq '.[] | "  #\(.number) \(.title)"'

echo "--- type:story + status:ready (bereit für DEVELOPER) ---"
gh issue list --label "type:story" --label "status:ready" --json number,title \
  --jq '.[] | "  #\(.number) \(.title)"'

echo "--- status:needs-review (bereit für REVIEWER) ---"
gh pr list --label "status:needs-review" --json number,title \
  --jq '.[] | "  PR #\(.number) \(.title)"'

echo "--- status:security-review (bereit für CSO) ---"
gh pr list --label "status:security-review" --json number,title \
  --jq '.[] | "  PR #\(.number) \(.title)"'

echo "=== ENDE ==="
```

---

## Schritt 5 — Hardregel bestätigen

Bevor du mit der eigentlichen Arbeit beginnst, verinnerliche:

> **Vor jedem Code-Commit muss ein geclaimed Issue existieren.**
> `gh issue view <nr>` muss dich als Assignee zeigen.
> Kein Issue → kein Commit. Keine Ausnahme.

Dann starte die Arbeit für deine Rolle.

---

## Zweck dieses Commands

Ohne `/init` passiert folgendes:
1. Claude öffnet eine Session
2. User sagt "implementier die Embedding-Pipeline"
3. Claude fängt an zu coden — ohne Issue, ohne Branch, ohne Claim

Mit `/init`:
1. Rolle wird explizit gesetzt
2. Framework-Kontext wird geladen
3. Queue ist sichtbar — was ist als nächstes dran?
4. Die Hardregel ist aktiv verinnerlicht bevor die erste Datei angefasst wird
