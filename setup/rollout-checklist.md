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

- [ ] Agenten-Set vollständig? Prüfen, dass ALLE Rollen-Prompts mitgekommen sind
  (v. a. bei manueller Kopie in ein bestehendes Repo):
  ```bash
  for a in architect developer reviewer cso retro test-author; do
    test -f ".claude/agents/$a.md" && echo "ok $a" || echo "FEHLT $a"
  done
  ```
  Fehlt `test-author.md`, kann der DEVELOPER den Contract-Schritt zwar per Fallback selbst
  ausführen (siehe `developer.md` Schritt 1c), sauberer ist aber die vollständige Kopie.

### Labels

- [ ] Labels anlegen:
  ```bash
  bash setup/labels.sh
  ```
  Ergebnis prüfen: 23 Labels in Repo-Settings sichtbar.

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

### CI einrichten

Die drei Guard-Workflows (`invalidate-verdict.yml`, `guard-protected-paths.yml`, `guard-test-contract.yml`)
sind bereits aktiv — kein Anpassen nötig, laufen auf jedem PR.

Für den vollständigen CI (test, gates, audit, commitlint):

- [ ] Template kopieren:
  ```bash
  cp setup/ci.yml.example .github/workflows/ci.yml
  ```
- [ ] `ci.yml` öffnen und befüllen:
  - Python- oder Node-Version eintragen (`<<<PYTHON_VERSION>>>` oder `<<<NODE_VERSION>>>`)
  - Test-, Lint- und Typecheck-Befehle aus dem Projekt eintragen (alle `<<<BEFEHLE_*>>>`)
  - Nicht genutzten Stack vollständig entfernen (Python ODER Node, nicht beides)
- [ ] `pyproject.toml` mit `[[tool.importlinter.contracts]]` für Layer-Regeln befüllen
  (oder `dependency-cruiser` für Node-Projekte)
- [ ] Committen und auf grüne Checks warten

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

### Doc-Kanon projektspezifisch ausfüllen

Die vier Kanon-Dateien werden mit agnostischer Baseline ausgeliefert und enthalten
`<AUSFÜLLEN: ...>`-Platzhalter sowie `// onboarding:`-Hinweise. Beim Onboarding konkretisieren:

- [ ] `docs/product-concept.adoc` — Problem, ICP, Scope In/Out, messbare Erfolgskriterien, USP.
- [ ] `docs/architecture.adoc` — Tech-Stack, Module (= CLAUDE.md `module`), Datenmodell,
  erste ADRs. Layer-Baseline ist bereits gesetzt; nur bei Abweichung anpassen.
- [ ] `docs/conventions.adoc` — Abschnitt 5 (Formatter/Linter, bevorzugte/verbotene Libs,
  Namens-/Fehlerkonventionen). Baseline-Anti-Generik-Regeln gelten sofort.
- [ ] `docs/current-state.adoc` — beim Projektstart einmal initialisieren; danach pflegt der RETRO.

### Preflight-Existenz-Check

- [ ] `scripts/preflight.sh` ist ausführbar (`chmod +x scripts/preflight.sh`).
  Der ARCHITECT ruft es in Schritt 1c automatisch im Entwurfs-Modus auf, um redundante
  Stories zu verhindern (Funktionalität existiert schon → Story wird nicht angelegt).
  Kein weiteres Setup nötig — läuft rein aus Issue-Metadaten + Codebase-Grep, ohne KI.
  Optional manuell testbar: `bash scripts/preflight.sh <issue-nr> --repo <owner/name> --source-dir .`

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
