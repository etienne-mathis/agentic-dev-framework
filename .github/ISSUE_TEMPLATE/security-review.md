---
name: Security Review (CSO)
about: Checkliste des CSO. Wird als PR-Kommentar ausgefüllt gepostet. Nicht als separates Issue verwenden.
title: "[SEC] PR #"
labels: ["status:security-review"]
---

## Referenz

- PR: # · Story: # · Geprüfter Stand (Commit-SHA):

## 1 — Secrets & Credentials

- [ ] Kein Secret im Diff (Keys, Tokens, Passwörter, Connection-Strings, .env-Inhalte)
- [ ] GitHub Secret Scanning / Push Protection ohne Alert für diesen Branch
- Befund: none | <Details mit Datei:Zeile>

## 2 — PII-Scan (unabhängig von dsgvo_relevant)

- [ ] Diff auf PII-Patterns geprüft (Muster aus CLAUDE.md `pii_patterns`)
- [ ] Kein undeklarierter PII-Treffer
- Befund: none | <Pattern, Datei:Zeile>

## 3 — AuthN / AuthZ

| Endpoint/Route | Methode | Auth erforderlich? | Implementiert? | Beleg (Datei:Zeile) |
|---|---|---|---|---|
|  |  |  |  |  |

- [ ] Jeder neue/geänderte Endpoint hat eine explizite Auth-Entscheidung (auch bewusstes "public")
- [ ] IDOR geprüft — fremde Ressourcen-IDs nicht abrufbar

## 4 — Input-Validierung

- [ ] Alle externen Inputs an der Systemgrenze validiert (Schema/Pydantic/Zod)
- [ ] Queries parametrisiert, keine String-Konkatenation in SQL
- [ ] File-Uploads / Deserialisierung geprüft (falls im Diff; sonst N/A mit Begründung)

## 5 — DSGVO

<!-- N/A mit Begründung, wenn dsgvo_relevant: false UND kein PII-Treffer -->

- [ ] Neue personenbezogene Daten? Falls ja: Zweck + Rechtsgrundlage in Story benannt
- [ ] Keine PII in Logs oder Fehlermeldungen
- [ ] Löschbarkeit / Auskunftsfähigkeit nicht verschlechtert

## 6 — Dependencies

- [ ] Lockfile-Diff geprüft, neue/aktualisierte Pakete gelistet
- [ ] Audit ohne Blocking-Findings (Schwelle: `audit.block_ab` aus CLAUDE.md)
- Befund: none | <ID, Paket==Version, Severity>

## Verdikt

- [ ] PASS → Label `status:approved`
- [ ] BLOCK → Label `status:security-blocked`
- Höchste Severity: `critical` | `high` | `medium` | `low`
- Remediation-Anforderungen:
  1.
