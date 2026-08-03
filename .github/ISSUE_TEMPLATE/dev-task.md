---
name: Dev Task
about: Vom ARCHITECT angelegt, vom DEVELOPER ausgeführt. Ein Task < task_max_h Stunden.
title: "[TASK] "
labels: ["type:task", "status:backlog"]
---

## Ziel

<!-- Ein Satz, Imperativ: "Implementiere X für Y" -->

## Parent

- Story: #
- Abgedeckte ACs: AC-1, AC-3

## Scope — Dateien & Layer

| Layer | Pfad | Aktion (neu / ändern) |
|---|---|---|
|  |  |  |

## Technische Vorgaben

- Port (Domain-Interface):
- Adapter (Infrastructure-Klasse):
- Ubiquitous Language — verwende: `<Begriffe>` / niemals: `<Synonyme>`

## Tests (Pflicht)

- Unit:
- Integration:
- Mapping: AC-1 → `test_<name>` (AC-ID im Testnamen oder Docstring als `[AC-1]`)

## Zu aktualisieren (Docs)

-

## Definition of Done

- [ ] Alle referenzierten ACs erfüllt, je AC ≥ 1 Test
- [ ] Testsuite grün (lokal, laut `befehle.test` in CLAUDE.md)
- [ ] Docs aktualisiert
- [ ] Commits nach Konvention, referenzieren #<task-nr>
- [ ] Keine neuen Dependencies eingeführt
