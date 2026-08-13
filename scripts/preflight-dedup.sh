#!/usr/bin/env bash
# preflight-dedup.sh — warnt vor redundanten Stories/Epics.
#
# Vergleicht einen Entwurf (Titel + optional Body) mit bestehenden Issues
# (offen UND geschlossen) via `gh`, per Overlap signifikanter Terme.
# REIN ADVISORY: Der Bash-Teil liefert einen gerankten Hinweis; das Ja/Nein-Urteil
# (Duplikat? Refactor? echter Neubau?) trifft der ARCHITECT. Kein Vektor-DB, keine KI —
# deterministischer, auditierbarer Bash-Hinweis (USP-konform).
#
# Nutzung:
#   scripts/preflight-dedup.sh --title "<titel>" [--body-file <pfad>] \
#     [--repo <owner/name>] [--threshold <n>]
#
# Exit-Codes:
#   0  = kein potenzielles Duplikat oberhalb der Schwelle
#   15 = potenzielles Duplikat gefunden (Hinweis, kein Stopp)

set -u

THRESHOLD=3          # Mindestanzahl geteilter signifikanter Terme für einen Treffer
TITLE=""
BODYFILE=""
REPO=""

while [ $# -gt 0 ]; do
  case "$1" in
    --title)     TITLE="${2:-}"; shift 2 ;;
    --body-file) BODYFILE="${2:-}"; shift 2 ;;
    --repo)      REPO="${2:-}"; shift 2 ;;
    --threshold) THRESHOLD="${2:-3}"; shift 2 ;;
    *) shift ;;
  esac
done

if [ -z "$TITLE" ] && { [ -z "$BODYFILE" ] || [ ! -f "$BODYFILE" ]; }; then
  echo "preflight-dedup: kein Entwurf (--title und/oder --body-file) übergeben — übersprungen." >&2
  exit 0
fi

REPO_ARG=""
[ -n "$REPO" ] && REPO_ARG="--repo $REPO"

# Kleine, generische Stopword-Liste (DE + EN) plus Framework-Vokabular.
STOP=" der die das und oder ein eine als fuer für mit von zu im in den dem des the a an of to for and or on at auf nach bei aus über ueber sowie soll wird werden kann muss story epic task input feature bug component komponente implementieren erstellen anlegen hinzufuegen hinzufügen umstellen extrahieren "

# normiert stdin: lowercase, nicht-alnum -> Zeilenumbruch, Terme >= 4 Zeichen, ohne Stopwords, unique+sortiert.
norm() {
  tr '[:upper:]' '[:lower:]' \
    | tr -c 'a-z0-9äöü' '\n' \
    | awk 'length >= 4' \
    | while IFS= read -r w; do
        case "$STOP" in
          *" $w "*) : ;;
          *) printf '%s\n' "$w" ;;
        esac
      done \
    | sort -u
}

DRAFT_TERMS=$( { printf '%s\n' "$TITLE"; [ -n "$BODYFILE" ] && [ -f "$BODYFILE" ] && cat "$BODYFILE"; } | norm )

if [ -z "$DRAFT_TERMS" ]; then
  echo "preflight-dedup: keine signifikanten Terme im Entwurf — übersprungen." >&2
  exit 0
fi

# Bestehende Issues (offen + geschlossen). PRs sind hier bewusst nicht enthalten.
ISSUES=$(gh issue list $REPO_ARG --state all --limit 300 \
  --json number,title,state 2>/dev/null || echo "[]")

HITS=""
BEST=0

while IFS="$(printf '\t')" read -r NUM STATE ITITLE; do
  [ -z "${NUM:-}" ] && continue
  ITERMS=$(printf '%s' "$ITITLE" | norm)
  [ -z "$ITERMS" ] && continue
  SHARED=$(comm -12 <(printf '%s\n' "$DRAFT_TERMS") <(printf '%s\n' "$ITERMS") 2>/dev/null | grep -c . || true)
  SHARED=${SHARED:-0}
  if [ "$SHARED" -ge "$THRESHOLD" ]; then
    HITS="${HITS}  #${NUM} [${STATE}] — ${SHARED} geteilte Terme — ${ITITLE}
"
    [ "$SHARED" -gt "$BEST" ] && BEST="$SHARED"
  fi
done <<EOF
$(printf '%s' "$ISSUES" | jq -r '.[] | "\(.number)\t\(.state)\t\(.title)"' 2>/dev/null)
EOF

if [ -n "$HITS" ]; then
  echo "WARNUNG: mögliche Duplikate (>= ${THRESHOLD} geteilte signifikante Terme):"
  printf '%s' "$HITS" | sort -t'#' -k2 -rn 2>/dev/null || printf '%s' "$HITS"
  echo "Der ARCHITECT entscheidet: echtes Duplikat (Story verwerfen), Refactor/Erweiterung"
  echo "eines bestehenden Issues, oder eigenständiger Neubau. Lies die genannten Issues."
  exit 15
fi

echo "Dedup-Scan: kein potenzielles Duplikat erkannt (Schwelle ${THRESHOLD})."
exit 0
