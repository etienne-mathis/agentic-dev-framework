# Rollout-Checkliste — neues Projekt einrichten

Geschätzte Dauer: ~45 Minuten für Phase 0.

---

## Phase 0 — Setup (einmalig)

### Repository

- [ ] Repo aus diesem Template erstellen:
  ```bash
  gh repo create <projektname> --template <dein-framework-template-repo> --private
  ```
  Alternativ: Template-Verzeichnis in bestehendes Repo kopieren.

### Labels

- [ ] Labels anlegen:
  ```bash
  bash setup/labels.sh
  ```
  Ergebnis prüfen: 18 Labels in Repo-Settings sichtbar.

### Branch Protection auf `main`

- [ ] PR required (kein direkter Push auf `main`)
- [ ] 1 Approving Review von CODEOWNERS erforderlich
- [ ] "Dismiss stale reviews when new commits are pushed" aktiviert
- [ ] Force-Push blockiert
- [ ] Required Status Checks: `test` · `gates` · `audit` · `test-contract` · `commitlint` · `protected-paths` · `invalidate-verdict`
- [ ] Auto-Merge deaktiviert lassen

### CODEOWNERS

- [ ] In `.github/CODEOWNERS` den Platzhalter `<github-handle>` durch den eigenen Handle ersetzen.

### GitHub Secret Scanning

- [ ] Secret Scanning aktivieren (Repo-Settings → Security → Secret scanning)
- [ ] Push Protection aktivieren

### CI-Skeleton

- [ ] `.github/workflows/ci-skeleton.yml` umbenennen zu `ci.yml` und anpassen:
  - Python-Version setzen
  - `befehle.test`, `befehle.gate` aus CLAUDE.md eintragen
  - Alle 4 Jobs aktivieren: `test`, `gates`, `audit`, `commitlint`
- [ ] `pyproject.toml` mit `[[tool.importlinter.contracts]]` für Layer-Regeln befüllen
  (oder `dependency-cruiser` für Node-Projekte)

Die Workflows `invalidate-verdict.yml`, `guard-protected-paths.yml` und `guard-test-contract.yml`
sind bereits aktiv (kein Anpassen nötig).

**Required Status Checks in Branch Protection (nach CI-Aktivierung):**
`test` · `gates` · `audit` · `commitlint` · `protected-paths` · `test-contract` · `invalidate-verdict`

### Projektkonfiguration

- [ ] `## Projektkonfiguration`-Block in `CLAUDE.md` vollständig ausfüllen:
  - `projekt`, `mensch`, `stack`
  - `befehle` (test, lint, typecheck — projektspezifische Kommandos)
  - `layer_mapping` (reale Verzeichnisse, keine Platzhalter)
  - `module` (Bounded Contexts / Module)
  - `dsgvo_relevant`
  - `audit.block_ab`
  - `limits` anpassen falls nötig

### Glossar seeden

- [ ] `docs/GLOSSARY.md` mit 5–10 Kernentitäten des Projekts befüllen.
  Ohne Glossar hat der ARCHITECT keine Sprachbasis und erzeugt inkonsistente Terminologie.

---

## Phase 0 — Smoke-Test

- [ ] Dummy-Epic nach `epic.md`-Template anlegen (alle DoR-Felder ausfüllen, dann manuell auf `status:ready` setzen):
  ```bash
  # Epic zuerst als backlog anlegen, Template-Body ausfüllen, dann promoten
  gh issue create --title "[EPIC] Smoke-Test" \
    --body-file /tmp/dummy-epic.md \
    --label "type:epic,status:backlog"
  # Nach Ausfüllen: gh issue edit <nr> --remove-label status:backlog --add-label status:ready
  ```

- [ ] ARCHITECT-Session manuell starten und Dummy-Epic zerlegen lassen.

- [ ] Backlog manuell prüfen:
  - DoR-Gate durchgelaufen (Checkliste im Epic abgehakt)?
  - Stories nach INVEST-Schema?
  - Scope-Tabellen mit echten, verifizierten Pfaden (nicht `[neu]` wo Pfad existiert)?
  - Observability-Feld in Tasks ausgefüllt?
  - HANDOFF-Kommentar vorhanden und entspricht docs/PROTOCOL.md §2? (Schema end-to-end verifiziert)

- [ ] Dummy-Issues schließen:
  ```bash
  gh issue close <epic-nr> --reason completed
  # alle zugehörigen Stories und Tasks ebenfalls schließen
  ```

---

## Phase 1 — Kalibrierung (erste echte Story)

- [ ] Echtes Epic anlegen
- [ ] ARCHITECT durchlaufen lassen
- [ ] Backlog-Review: Story-Schnitt und ACs manuell prüfen (einmalige Qualitätskontrolle)
- [ ] Erste Story komplett durch die Pipeline führen und jeden Handoff mitlesen
- [ ] Findings aus der ersten Story in `docs/GLOSSARY.md` und `CLAUDE.md` einfließen lassen
  (nicht in die generischen Framework-Dateien)

---

## Phase 2 — Normalbetrieb

Verbleibende Berührungspunkte:

- `status:approved`-PRs mergen
- `needs-human`-Eskalationen entscheiden und Label entfernen
- Neue Epics anlegen
- Retro-PRs reviewen (Sektion 6 ausfüllen) und mergen

```bash
# Pipeline starten (Modell A — Orchestrator)
/pipeline

# Oder einzelne Rolle (Modell B — getrennte Sessions)
# "Du bist der DEVELOPER. Starte mit story #42."
```
