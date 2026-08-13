#!/usr/bin/env bash
###############################################################################
# preflight-calibrate.sh — Feedback-Loop für die Token-Kalibrierung (A.3)
#
# Anker-Hierarchie (P3.0):
#   1. ECHTE Ist-Tokens aus .preflight/actuals.tsv (measure-run.sh liest sie aus
#      den Claude-Code-Session-jsonl). Wenn vorhanden → primärer Anker.
#   2. Diff-Größen-PROXY aus GitHub-Daten (Fallback, wenn keine actuals.tsv da ist).
# Er liest .preflight/estimates.tsv (das der Preflight im Issue-Modus schreibt) und
# ermittelt je gemergtem Story-PR:
#   - Ist-Tokens   (Summe in+out aller Rollen-Spawns des Issues aus actuals.tsv)
#   - Diff-Größe   (Insertions + Deletions aus dem Patch — Proxy-Fallback)
#   - Zyklen       (cycle: aus HANDOFF-Kommentaren am PR — Re-Submissions)
# Ausgabe je Tier: geschätzt vs. Ist-Proxy (Median) + Korrekturvorschlag für
# die TOKENS_*-Konstanten in preflight.sh.
#
# WICHTIG: Dieses Skript ÄNDERT preflight.sh NICHT. Es schlägt vor — der Mensch
# übernimmt die Werte bewusst (preflight.sh ist ein geschützter Pfad).
#
# Aufruf:
#   ./preflight-calibrate.sh [--repo OWNER/NAME] [--estimates PATH] [--since YYYY-MM-DD]
#   Ohne --repo wird das Repo aus dem aktuellen Verzeichnis abgeleitet (gh).
###############################################################################
set -euo pipefail

# Muss zu den Werten in preflight.sh passen — Basis für den Korrekturvorschlag.
TOKENS_HAIKU=6000
TOKENS_SONNET=20000
TOKENS_OPUS=45000

REPO=""; EST=".preflight/estimates.tsv"; SINCE=""
while [ $# -gt 0 ]; do
  case "$1" in
    --repo)      REPO="$2"; shift 2 ;;
    --estimates) EST="$2"; shift 2 ;;
    --since)     SINCE="$2"; shift 2 ;;
    -h|--help)   grep '^#' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *)           shift ;;
  esac
done

# Repo ableiten, falls nicht übergeben.
if [ -z "$REPO" ]; then
  REPO=$(gh repo view --json nameWithOwner --jq '.nameWithOwner' 2>/dev/null || true)
fi
[ -z "$REPO" ] && { echo "FEHLER: --repo OWNER/NAME fehlt und ließ sich nicht ableiten."; exit 1; }

if [ ! -f "$EST" ]; then
  echo "Keine Schätzdaten ($EST) — nichts zu kalibrieren."
  echo "Der Preflight schreibt sie erst, wenn er im Issue-Modus (echte Nummer) läuft."
  exit 0
fi

TMPD=$(mktemp -d); trap 'rm -rf "$TMPD"' EXIT

# Echte Ist-Tokens (P3.0): wenn measure-run.sh eine actuals.tsv geschrieben hat,
# nutzen wir sie als ANKER statt der Diff-Größe (Diff bleibt Fallback).
# Spalten: issue \t rolle \t modell \t in \t out \t cache_read \t sekunden \t datum
ACT=".preflight/actuals.tsv"
USE_ACTUALS=0
if [ -f "$ACT" ]; then
  USE_ACTUALS=1
  echo "Ist-Tokens gefunden ($ACT) — echte Messung als Anker (Diff-Proxy = Fallback)."
fi

# Summe der echten in+out-Tokens aller Rollen-Spawns eines Issues (0 wenn keine Daten).
real_tokens_for() {  # $1 = issue-nr
  [ "$USE_ACTUALS" -eq 1 ] || { echo 0; return; }
  awk -F'\t' -v i="$1" '$1 !~ /^#/ && $1==i {s += $4 + $5} END {print s + 0}' "$ACT"
}

# Gemergte PRs einmalig holen (Body für closes-Zuordnung).
MERGED=$(gh pr list --repo "$REPO" --state merged \
  --json number,body --limit 200 2>/dev/null || echo '[]')

# Pro Issue nur die letzte Schätzung behalten (Re-Runs überschreiben).
awk -F'\t' 'NF>=5 {last[$1]=$0} END{for(i in last) print last[i]}' "$EST" \
  | sort -t$'\t' -k1,1n > "$TMPD/est.tsv"

median() {  # $1 = datei mit einer Zahl je Zeile
  sort -n "$1" 2>/dev/null | awk '
    {a[NR]=$1}
    END{ if(NR==0){print "n/a"; exit}
         m=int((NR+1)/2)
         if(NR%2){print a[m]} else {printf "%d", int((a[m]+a[m+1])/2)} }'
}

echo "══════════════════════════════════════════════════════════════════════"
echo " PREFLIGHT-KALIBRIERUNG  ·  $REPO"
[ -n "$SINCE" ] && echo " Zeitfenster: ab $SINCE"
echo "══════════════════════════════════════════════════════════════════════"
echo " Einzelne Story-Läufe (geschätzt vs. Ist-Proxy):"

MATCHED=0
while IFS=$'\t' read -r issue tier tokens_est time_est datum; do
  [ -z "${issue:-}" ] && continue
  # Zeitfenster-Filter (String-Vergleich auf ISO-Datum ist korrekt sortierbar).
  if [ -n "$SINCE" ] && [ "$datum" \< "$SINCE" ]; then continue; fi

  # PR finden, der genau diesen Issue schließt ("closes #<nr>", case-insensitive).
  pr=$(echo "$MERGED" | jq -r --arg i "$issue" \
    '.[] | select((.body // "") | ascii_downcase
      | test("closes #" + $i + "([^0-9]|$)")) | .number' 2>/dev/null | head -1)
  [ -z "$pr" ] && continue

  # Ist-Proxy 1: Diff-Größe (geänderte Zeilen). `gh pr diff` kennt kein --stat,
  # daher aus dem Patch: Zeilen mit +/- (ohne die +++/--- Header) zählen.
  patch=$(gh pr diff "$pr" --repo "$REPO" --patch 2>/dev/null || true)
  ins=$(printf '%s\n' "$patch" | grep -cE '^\+[^+]' || true)
  del=$(printf '%s\n' "$patch" | grep -cE '^-[^-]'  || true)
  diff_lines=$(( ${ins:-0} + ${del:-0} ))

  # Ist-Proxy 2: Zyklen (höchster cycle:-Wert aus den HANDOFF-Kommentaren).
  cyc=$(gh pr view "$pr" --repo "$REPO" --json comments \
    --jq '.comments[].body' 2>/dev/null \
    | grep -oE 'cycle: *[0-9]+' | grep -oE '[0-9]+' | sort -n | tail -1 || true)
  [ -z "$cyc" ] && cyc=1

  real=$(real_tokens_for "$issue")

  echo "$tokens_est"  >> "$TMPD/${tier}.est"
  echo "$diff_lines"  >> "$TMPD/${tier}.diff"
  echo "$cyc"         >> "$TMPD/${tier}.cyc"
  [ "${real:-0}" -gt 0 ] && echo "$real" >> "$TMPD/${tier}.real"
  MATCHED=$((MATCHED+1))
  if [ "${real:-0}" -gt 0 ]; then
    printf '   #%-4s %-7s est~%-6s ist=%-7s diff=%-5s cycles=%s  → PR #%s\n' \
      "$issue" "$tier" "$tokens_est" "$real" "$diff_lines" "$cyc" "$pr"
  else
    printf '   #%-4s %-7s est~%-6s diff=%-5s cycles=%s  → PR #%s\n' \
      "$issue" "$tier" "$tokens_est" "$diff_lines" "$cyc" "$pr"
  fi
done < "$TMPD/est.tsv"

if [ "$MATCHED" -eq 0 ]; then
  echo "   (keine geschätzten Issues mit gemergtem Story-PR gefunden)"
  echo "──────────────────────────────────────────────────────────────────────"
  echo " Kein Ist-Proxy verfügbar — Kalibrierung übersprungen."
  exit 0
fi

# Metrik-Wahl: echte Ist-Tokens schlagen den Diff-Proxy, sobald genug Daten da sind.
METRIC="diff"; METRIC_LABEL="diff_lines"
if [ "$USE_ACTUALS" -eq 1 ] && ls "$TMPD"/*.real >/dev/null 2>&1; then
  METRIC="real"; METRIC_LABEL="ist_tokens"
fi

echo "──────────────────────────────────────────────────────────────────────"
printf ' %-8s %-4s %-14s %-14s %s\n' "Tier" "n" "est_tokens(med)" "${METRIC_LABEL}(med)" "cycles(med)"

# Anker für den Vorschlag: das Tier mit den meisten Datenpunkten der gewählten Metrik.
ANCHOR_TIER=""; ANCHOR_N=0; ANCHOR_METRIC=""
for tier in Haiku Sonnet Opus; do
  [ -f "$TMPD/${tier}.est" ] || continue
  n=$(wc -l < "$TMPD/${tier}.est" | tr -d ' ')
  med_est=$(median "$TMPD/${tier}.est")
  med_metric=$([ -f "$TMPD/${tier}.${METRIC}" ] && median "$TMPD/${tier}.${METRIC}" || echo "n/a")
  med_cyc=$(median "$TMPD/${tier}.cyc")
  printf ' %-8s %-4s %-14s %-14s %s\n' "$tier" "$n" "$med_est" "$med_metric" "$med_cyc"
  # Anker-Kandidat braucht einen belastbaren Metrik-Wert.
  m_n=$([ -f "$TMPD/${tier}.${METRIC}" ] && wc -l < "$TMPD/${tier}.${METRIC}" | tr -d ' ' || echo 0)
  if [ "$m_n" -gt "$ANCHOR_N" ]; then
    ANCHOR_N="$m_n"; ANCHOR_TIER="$tier"; ANCHOR_METRIC="$med_metric"
  fi
done

echo "──────────────────────────────────────────────────────────────────────"
if [ "$METRIC" = "real" ]; then
  echo " Korrekturvorschlag (Ist-Tokens aus measure-run.sh — echte Messung):"
else
  echo " Korrekturvorschlag (Proxy-basiert — Diff-Größe als Aufwands-Stellvertreter):"
fi
echo " Anker = Tier mit den meisten ${METRIC_LABEL}-Datenpunkten: ${ANCHOR_TIER:-keins} ($ANCHOR_N Läufe)."

case "$ANCHOR_TIER" in
  Haiku)  ANCHOR_TOK=$TOKENS_HAIKU ;;
  Sonnet) ANCHOR_TOK=$TOKENS_SONNET ;;
  Opus)   ANCHOR_TOK=$TOKENS_OPUS ;;
esac

if [ -z "${ANCHOR_METRIC:-}" ] || [ "$ANCHOR_METRIC" = "0" ] || [ "$ANCHOR_METRIC" = "n/a" ]; then
  echo " Anker-Metrik ist 0/n/a — kein belastbares Verhältnis. Manuell prüfen."
else
  if [ "$METRIC" = "real" ]; then
    echo " Setzt TOKENS_* auf den gemessenen Median-Verbrauch je Tier direkt:"
  else
    echo " Skaliert TOKENS_* so, dass sie dem beobachteten Diff-Größen-Verhältnis folgen"
    echo " (Anker-Token bleiben fix):"
  fi
  for tier in Haiku Sonnet Opus; do
    [ -f "$TMPD/${tier}.${METRIC}" ] || continue
    med_metric=$(median "$TMPD/${tier}.${METRIC}")
    case "$tier" in
      Haiku)  cur=$TOKENS_HAIKU ;;
      Sonnet) cur=$TOKENS_SONNET ;;
      Opus)   cur=$TOKENS_OPUS ;;
    esac
    TU=$(echo "$tier" | tr 'a-z' 'A-Z')
    if [ "$METRIC" = "real" ]; then
      # Echte Messung: der gemessene Median IST der neue Vorschlag.
      printf '   TOKENS_%s: %s  → Vorschlag %s  (gemessener Median)\n' "$TU" "$cur" "$med_metric"
    elif [ "$tier" = "$ANCHOR_TIER" ]; then
      printf '   TOKENS_%s: %s  (Anker — unverändert)\n' "$TU" "$cur"
    else
      sugg=$(( ANCHOR_TOK * med_metric / ANCHOR_METRIC ))
      printf '   TOKENS_%s: %s  → Vorschlag %s  (aktuell %s)\n' "$TU" "$cur" "$sugg" "$cur"
    fi
  done
  echo
  echo " Hinweis: Medianzyklen > 1 in einem Tier deuten auf Re-Submission-Aufwand,"
  echo " den der CYCLE_RISK_MULTIPLIER in preflight.sh bereits teilweise abbildet."
fi
echo " Übernahme bewusst durch den Menschen — preflight.sh ist geschützt."
echo "══════════════════════════════════════════════════════════════════════"
