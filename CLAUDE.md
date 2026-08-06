# Multi-Agent-Protokoll (verbindlich für jede Agenten-Rolle)

**Session-Start: Führe immer zuerst `/init` aus. Niemals direkt coden ohne geclaimed Issue.**

Du agierst pro Session in genau EINER Rolle: ARCHITECT | DEVELOPER | REVIEWER | CSO | RETRO.
Die Rolle steht in deinem Startauftrag. Führe niemals Arbeit einer anderen Rolle aus.

- Einzige Zustandsquelle ist GitHub. Zustand änderst du ausschließlich über
  Label-Wechsel plus HANDOFF-Kommentar. Genau ein `status:`-Label pro Issue/PR.
- Claim-Regel: Label wechseln, Assignee setzen, CLAIM-Kommentar posten (Schema §1
  in docs/PROTOCOL.md), dann zurücklesen und verifizieren. Bist du nicht der jüngste
  CLAIM: abbrechen, nächsten Kandidaten nehmen.
- Issues/PRs mit Label `needs-human` überspringst du ausnahmslos.
- HANDOFF- und ESCALATION-Kommentare exakt im Schema aus docs/PROTOCOL.md.
- ESCALATION-reason ausschließlich als Slug aus der Tabelle in docs/PROTOCOL.md §3.
- Beende jede Session mit genau einer Signal-Zeile nach docs/PROTOCOL.md §5.
- Absolut verboten für jede Rolle:
  `gh pr merge` · `gh pr review --approve` · Force-Push · History-Rewrite ·
  Tests löschen, skippen oder abschwächen ·
  Änderungen an `.github/`, `.claude/`, `CLAUDE.md`, `docs/PROTOCOL.md`, CI-Konfiguration,
  Framework-Skripten (`scripts/glossar_gate.sh`, `scripts/preflight.sh`, `scripts/preflight-calibrate.sh`) ·
  Label `human-override:protected-paths` setzen ·
  Label `human-override:test-contract` setzen ·
  Label `human-override:api-breaking` setzen.
- Jeder neue Commit nach einem Reviewer-/CSO-Verdikt invalidiert es automatisch
  (erzwungen durch `invalidate-verdict.yml`). Kein Agent muss das manuell tun.
- Verwende ausschließlich Begriffe aus dem Glossar (Pfad: `glossar` in Projektkonfiguration).
  Keine Synonyme — in Code, Issues, Kommentaren und Docs.
- Leere Queue: melde `QUEUE EMPTY <rolle>` und beende die Session.
  Warte nie aktiv auf andere Agenten.

---

## Projektkonfiguration

<!-- EINZIGER projektspezifischer Block — hier und nur hier anpassen.
     Alles andere in dieser Datei ist generisch und bleibt unverändert. -->

```yaml
projekt: <projektname>
mensch: @<github-handle>
default_branch: main
stack: python-fastapi          # python-fastapi | n8n | node

befehle:
  test: uv run pytest
  lint: uv run ruff check .
  typecheck: uv run mypy src
  gate: >
    uv run ruff check . &&
    uv run mypy src &&
    uv run lint-imports &&
    uv run pytest --cov --cov-report=xml &&
    uv run diff-cover coverage.xml --compare-branch=origin/main
      --fail-under=90 &&
    bash scripts/glossar_gate.sh

layer_mapping:
  presentation: src/api/
  application: src/application/
  domain: src/domain/
  infrastructure: src/infrastructure/

module: []                     # Bounded Contexts / Module des Projekts
glossar: docs/GLOSSARY.md
docs_quelle: docs/
dsgvo_relevant: true
preflight_budget: none         # Tokens; none = kein Gate (Preflight-Budget-Gate)

audit:
  block_ab: high               # critical | high | medium | low

gates:
  coverage_changed_lines: 90   # Prozent; via diff-cover
  layers: import-linter        # pyproject.toml [[tool.importlinter.contracts]]
  glossar_gate: true           # scripts/glossar_gate.sh

observability:
  # Einmalige Middleware (FastAPI: Request-Log, Latency-Histogramm, Error-Counter).
  # Nach Einrichtung prüft der Reviewer nur noch domänenspezifische Events.
  middleware: src/api/middleware/observability.py
  pflicht:
    - "endpoint: via middleware (kein manuelles Logging nötig)"
    - "adapter: 1 Log je externem Call mit Dauer"
    - "job/worker: Start/Ende/Fehler-Log"
    - "domain-event: benannter Log nach Glossar-Begriffen"

api_contract: none             # docs/api/openapi.yaml | none
                               # Bei gesetztem Pfad: CI-Job contract-api läuft,
                               # Breaking Changes erfordern human-override:api-breaking

pii_patterns:
  - email
  - e_mail
  - mail
  - vorname
  - nachname
  - geburtsdatum
  - birth
  - iban
  - bic
  - telefon
  - phone
  - adresse
  - anschrift
  - address
  - plz
  - zip
  - steuer
  - tax_id
  - sozialversicherung
  - ssn
  - ip_address
  - user_agent
  - latitude
  - longitude

limits:
  task_max_h: 8
  tasks_pro_story: 3
  review_zyklen_max: 2
  retro_intervall_merges: 5    # Retro nach N gemergten PRs
  muster_schwelle: 3           # Ab N Wiederholungen eines Findings → Muster
```
