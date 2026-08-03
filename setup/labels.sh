#!/usr/bin/env bash
# Labels für das Multi-Agent-Framework anlegen.
# Ausführen einmalig im Ziel-Repo: bash setup/labels.sh
# Voraussetzung: gh CLI authentifiziert, Repo-Kontext aktiv.

set -e

echo "Lege Status-Labels an..."
for l in \
  "status:triage:#eeeeee" \
  "status:backlog:#ededed" \
  "status:ready:#0e8a16" \
  "status:in-progress:#fbca04" \
  "status:needs-review:#1d76db" \
  "status:changes-requested:#d93f0b" \
  "status:security-review:#5319e7" \
  "status:security-blocked:#b60205" \
  "status:approved:#0e8a16" \
  "status:done:#c2e0c6"; do
  NAME="${l%:*}"
  COLOR="${l##*:}"
  gh label create "$NAME" --color "$COLOR" --force
  echo "  $NAME"
done

echo "Lege Typ-Labels an..."
for l in \
  "type:input:#f9d0c4" \
  "type:epic:#3e4b9e" \
  "type:story:#5319e7" \
  "type:task:#bfdadc" \
  "type:retro:#0052cc"; do
  NAME="${l%:*}"
  COLOR="${l##*:}"
  gh label create "$NAME" --color "$COLOR" --force
  echo "  $NAME"
done

echo "Lege Steuerungs-Labels an..."
for l in \
  "needs-human:#b60205" \
  "source:retrospective:#0052cc" \
  "perf-kritisch:#e4e669"; do
  NAME="${l%:*}"
  COLOR="${l##*:}"
  gh label create "$NAME" --color "$COLOR" --force
  echo "  $NAME"
done

echo "Lege human-override-Labels an (nur durch Menschen setzbar)..."
for l in \
  "human-override:protected-paths:#b60205" \
  "human-override:test-contract:#b60205" \
  "human-override:api-breaking:#b60205"; do
  NAME="${l%:*}"
  COLOR="${l##*:}"
  gh label create "$NAME" --color "$COLOR" --force
  echo "  $NAME"
done

echo ""
echo "Alle 23 Labels angelegt."
