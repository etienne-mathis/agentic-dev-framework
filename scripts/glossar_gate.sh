#!/usr/bin/env bash
# Glossar-Gate: Prüft ob im Diff verbotene Synonyme für definierte Glossar-Begriffe verwendet werden.
# Läuft als CI-Job und als Teil von befehle.gate (lokal via Developer).
#
# Voraussetzung: docs/GLOSSARY.md hat eine "Verboten"-Spalte:
# | Begriff | Definition | Verboten (Synonyme) |
# | Mandant | ...        | tenant, kunde, client |
#
# Aufruf: bash scripts/glossar_gate.sh [basis-branch]
# Standard-Basis: origin/main

set -euo pipefail

BASIS="${1:-origin/main}"

# GLOSSARY.md muss existieren
if [ ! -f docs/GLOSSARY.md ]; then
  echo "OK — docs/GLOSSARY.md nicht gefunden, Gate übersprungen."
  exit 0
fi

# Synonyme aus der "Verboten"-Spalte der GLOSSARY.md extrahieren
SYN=$(awk -F'|' '
  /^\|/ && NR > 2 {
    gsub(/^[ \t]+|[ \t]+$/, "", $4)
    if ($4 != "" && $4 != "Verboten (Synonyme)" && $4 != "---" && $4 !~ /^<!--/) print $4
  }
' docs/GLOSSARY.md \
  | tr ',' '\n' \
  | sed 's/^[[:space:]]*//;s/[[:space:]]*$//' \
  | grep -v '^$' \
  | paste -sd'|' - || true)

if [ -z "$SYN" ]; then
  echo "OK — keine Synonyme im Glossar definiert, Gate übersprungen."
  exit 0
fi

# Sicherstellen dass origin/main erreichbar ist
if ! git rev-parse --verify "$BASIS" > /dev/null 2>&1; then
  echo "OK — Basis-Branch '$BASIS' nicht erreichbar (initialer Commit?), Gate übersprungen."
  exit 0
fi

# Nur hinzugefügte Zeilen prüfen; Glossar und Retro-Docs ausschließen
HITS=$(git diff "${BASIS}...HEAD" -U0 \
       -- ':!docs/GLOSSARY.md' ':!docs/retrospective/' ':!docs/adr/' \
       | grep '^+' \
       | grep -v '^\+\+\+' \
       | grep -inwE "($SYN)" || true)

if [ -n "$HITS" ]; then
  echo "Glossar-Verstoß — kanonischen Begriff aus docs/GLOSSARY.md verwenden:"
  echo "$HITS"
  exit 1
fi

echo "OK — keine Glossar-Verstöße."
