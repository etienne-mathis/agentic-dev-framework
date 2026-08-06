#!/usr/bin/env bash
###############################################################################
# preflight.sh — Pre-flight Estimator (PROTOTYP, isoliert)
#
# Schätzt OHNE KI — rein aus Issue-Metadaten + Codebase-Scan — vor jedem
# Agenten-Lauf: welches Modell, wie viele Tokens, go/no-go gegen Budget.
#
# Kombiniert:
#   Lösung C — Modell-Routing + Token-Schätzung + Budget-Gate
#   Lösung A — Codebase-Scan: existiert die Funktionalität schon?
#
# Aufruf — zwei Modi:
#   (a) Bestehendes Issue (DEVELOPER / pipeline):
#       ./preflight.sh <issue-nr> --repo OWNER/NAME --source-dir . [--budget N]
#   (b) Lokaler Story-ENTWURF (ARCHITECT, vor Issue-Erstellung — Lösung A):
#       ./preflight.sh --body-file /tmp/draft.md --title "..." --source-dir .
#
# Budget-Quelle (Priorität): --budget N  >  $PREFLIGHT_BUDGET (Env)  >
#   preflight_budget: aus CLAUDE.md (bei gesetztem --source-dir)  >  kein Gate.
#
# Exit-Codes: 0 = GO   ·   10 = GO-MIT-WARNUNG (Existenz)   ·   20 = NO-GO (Budget)
###############################################################################
set -euo pipefail

# ═══════════════════════════════════════════════════════════════════════════
# CONFIG — alle Heuristik-Parameter an einem Ort (Prototyp: frei tunbar)
# ═══════════════════════════════════════════════════════════════════════════

# Score-Schwellen → Modell-Tier
TIER_HAIKU_MAX=2          # Score 0..2  → Haiku
TIER_SONNET_MAX=6         # Score 3..6  → Sonnet ; ab 7 → Opus

# Token-Schätzung je Tier (ein sauberer Durchlauf, ohne Re-Submission)
TOKENS_HAIKU=6000
TOKENS_SONNET=20000
TOKENS_OPUS=45000

# Zeit-Schätzung je Tier (Minuten, ein sauberer Durchlauf)
TIME_HAIKU=4
TIME_SONNET=11
TIME_OPUS=25

# Zyklus-Risiko: wenn Story tests/acceptance/ berührt UND kein Test-Runner
# konfiguriert ist, drohen Re-Submission-Zyklen (real bei Story #5 passiert).
CYCLE_RISK_MULTIPLIER=15  # +50% als Ganzzahl-Faktor: 15 = *1.5 (÷10)

# Verzeichnisse/Muster die der Codebase-Scan ignoriert:
# Vendor/Build/Tests + Framework-Meta-Dateien (die sind kein Projekt-Quellcode).
SCAN_EXCLUDES='node_modules|vendor|stripe-php|dist|build|/tests/|\.min\.|\.claude/|\.github/|/docs/|/setup/|/scripts/|CLAUDE\.md|README|GLOSSARY|PROTOCOL'

# Wiederverwendungs-Marker: nennt eine Task-Zeile den Identifier ZUSAMMEN mit einem
# dieser Wörter, ist er eine bestehende Dependency (die neu genutzt wird), NICHT das
# Deliverable der Story. Dann darf er KEIN starkes Existenz-Signal auslösen.
# (Adversarialer Fund #10: "bestehende fetchOrders-Funktion nutzen" ist Reuse, kein Neubau.)
DEP_MARKERS='bestehend|vorhanden|existierend|existing|nutzen|verwenden|wiederverwend|reuse|über die|ueber die|via'

# ═══════════════════════════════════════════════════════════════════════════
# ARGUMENTE
# ═══════════════════════════════════════════════════════════════════════════
ISSUE=""; REPO=""; SOURCE_DIR=""; BUDGET=""; BODYFILE=""; TITLE_ARG=""
while [ $# -gt 0 ]; do
  case "$1" in
    --repo)       REPO="$2"; shift 2 ;;
    --source-dir) SOURCE_DIR="$2"; shift 2 ;;
    --budget)     BUDGET="$2"; shift 2 ;;
    --body-file)  BODYFILE="$2"; shift 2 ;;
    --title)      TITLE_ARG="$2"; shift 2 ;;
    -h|--help)    grep '^#' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *)            ISSUE="$1"; shift ;;
  esac
done

# ═══════════════════════════════════════════════════════════════════════════
# BUDGET-QUELLE (Priorität: --budget CLI > $PREFLIGHT_BUDGET Env >
#   preflight_budget: aus CLAUDE.md > kein Gate). Kein API-Key nötig, portabel.
#   Wert "none" (oder leer) bedeutet explizit: kein Budget-Gate.
# ═══════════════════════════════════════════════════════════════════════════
BUDGET_SOURCE=""
if [ -n "$BUDGET" ]; then
  BUDGET_SOURCE="CLI"
elif [ -n "${PREFLIGHT_BUDGET:-}" ]; then
  BUDGET="$PREFLIGHT_BUDGET"; BUDGET_SOURCE="Env"
elif [ -n "$SOURCE_DIR" ] && [ -f "$SOURCE_DIR/CLAUDE.md" ]; then
  # Analog zum Cycle-Risk-Read: nur wenn --source-dir eine CLAUDE.md enthält.
  # POSIX-Zeichenklassen statt \s (BSD/macOS-sed kennt \s nicht); der Wert ist ein
  # einzelnes Token → abschließendes `tr -d` entfernt jeglichen Rest-Whitespace.
  CFG_BUDGET=$(grep -E '^[[:space:]]*preflight_budget:' "$SOURCE_DIR/CLAUDE.md" 2>/dev/null \
    | head -1 \
    | sed -E 's/^[[:space:]]*preflight_budget:[[:space:]]*//; s/[[:space:]]*#.*$//' \
    | tr -d '[:space:]' || true)
  if [ -n "$CFG_BUDGET" ]; then BUDGET="$CFG_BUDGET"; BUDGET_SOURCE="CLAUDE.md"; fi
fi
# "none" (aus Config) normalisieren → kein Gate.
if [ "$BUDGET" = "none" ]; then BUDGET=""; BUDGET_SOURCE=""; fi

# ═══════════════════════════════════════════════════════════════════════════
# 1 — EINGABE BESCHAFFEN — zwei Modi:
#   (a) --body-file: lokaler Story-ENTWURF (ARCHITECT, vor Issue-Erstellung)
#   (b) <issue-nr> --repo: bestehendes Issue (DEVELOPER / pipeline)
# ═══════════════════════════════════════════════════════════════════════════
if [ -n "$BODYFILE" ]; then
  [ -f "$BODYFILE" ] || { echo "FEHLER: --body-file '$BODYFILE' nicht gefunden."; exit 1; }
  BODY=$(cat "$BODYFILE")
  TITLE="${TITLE_ARG:-$(head -1 "$BODYFILE" | sed 's/^#* *//')}"
  LABELS=""
  ISSUE="${ISSUE:-ENTWURF}"
else
  [ -z "$ISSUE" ] && { echo "FEHLER: Issue-Nummer oder --body-file fehlt. -h für Hilfe."; exit 1; }
  [ -z "$REPO" ]  && { echo "FEHLER: --repo OWNER/NAME fehlt."; exit 1; }
  RAW=$(gh issue view "$ISSUE" --repo "$REPO" --json title,body,labels 2>/dev/null) \
    || { echo "FEHLER: Issue #$ISSUE in $REPO nicht erreichbar."; exit 1; }
  TITLE=$(echo "$RAW" | jq -r '.title')
  BODY=$(echo  "$RAW" | jq -r '.body')
  LABELS=$(echo "$RAW" | jq -r '.labels[].name' | paste -sd',' -)
fi

# Body in Tempfile für section-Parsing
TMP=$(mktemp); echo "$BODY" > "$TMP"
trap 'rm -f "$TMP"' EXIT

# Hilfsfunktion: Abschnitt zwischen "## <name>" und nächster "## " extrahieren
section() {
  awk -v h="$1" '
    $0 ~ "^## " h { grab=1; next }
    /^## / && grab { grab=0 }
    grab { print }
  ' "$TMP"
}

# ═══════════════════════════════════════════════════════════════════════════
# 2 — METADATEN-SIGNALE MESSEN
# ═══════════════════════════════════════════════════════════════════════════
AC_COUNT=$(section "Acceptance Criteria" | grep -cE '^\s*-\s' || true)
TASK_COUNT=$(section "Tasks" | grep -cE '^\s*-\s' || true)

# Neue Dateien: Tasks-Zeilen mit Erstell-Verben
NEW_FILES=$(section "Tasks" \
  | grep -icE '(erstellen|erstelle|anlegen|erzeugen|create|new file|hinzufügen)' || true)

# Module: distinkte Top-Level-Verzeichnisse in Backtick-Pfaden im ganzen Body
MODULES=$(grep -oE '`[a-zA-Z0-9_./-]+`' "$TMP" \
  | tr -d '`' \
  | grep -E '/' \
  | sed -E 's|^([a-zA-Z0-9_-]+)/.*|\1|' \
  | sort -u | grep -vc '^$' || true)
[ "$MODULES" -lt 1 ] && MODULES=1

# ═══════════════════════════════════════════════════════════════════════════
# 3 — SCORE BERECHNEN
# ═══════════════════════════════════════════════════════════════════════════
score_bucket() {  # $1=wert  $2..=schwellen aufsteigend → gibt Index (0..n)
  local v="$1"; shift; local i=0
  for t in "$@"; do [ "$v" -gt "$t" ] && i=$((i+1)); done
  echo "$i"
}

S_AC=$(score_bucket   "$AC_COUNT"   2 4 6)     # 0..3
S_TASK=$(score_bucket "$TASK_COUNT" 2 4 6)     # 0..3
S_NEW=$(score_bucket  "$NEW_FILES"  0 1 2)     # 0..3
S_MOD=$(score_bucket  "$MODULES"    1 2)       # 0..2

SCORE=$((S_AC + S_TASK + S_NEW + S_MOD))       # 0..11

# ═══════════════════════════════════════════════════════════════════════════
# 4 — TIER + BASIS-SCHÄTZUNG
# ═══════════════════════════════════════════════════════════════════════════
if   [ "$SCORE" -le "$TIER_HAIKU_MAX" ];  then TIER="Haiku";  TOKENS=$TOKENS_HAIKU;  TIME=$TIME_HAIKU
elif [ "$SCORE" -le "$TIER_SONNET_MAX" ]; then TIER="Sonnet"; TOKENS=$TOKENS_SONNET; TIME=$TIME_SONNET
else                                           TIER="Opus";   TOKENS=$TOKENS_OPUS;   TIME=$TIME_OPUS
fi

# ═══════════════════════════════════════════════════════════════════════════
# 5 — LÖSUNG A: CODEBASE-SCAN (existiert die Funktionalität schon?)
# ═══════════════════════════════════════════════════════════════════════════
EXISTENCE_HIT=""; EXISTENCE_FILE=""
if [ -n "$SOURCE_DIR" ] && [ -d "$SOURCE_DIR" ]; then
  # STARKES Signal: echte Code-Identifier (camelCase / snake_case) aus den Tasks,
  # die wörtlich im Bestandscode stehen. Das ist präzise — solche Bezeichner sind
  # fast nie Prosa. Findet der Estimator sie, existiert die Funktionalität sicher.
  # Dies ist das EINZIGE Existenz-Signal: verlässlich oder gar nicht. Das früher
  # zusätzlich berechnete schwache Term-Überlappungs-Signal wurde entfernt, weil
  # es zu verrauscht war (generische Terme markierten faktisch nur Dateigröße).
  IDENTIFIERS=$( { section "Story"; section "Tasks"; echo "$TITLE"; } \
    | grep -oE '[a-zA-Z][a-zA-Z0-9_]{5,}' 2>/dev/null \
    | grep -E '[a-z][A-Z]|_' \
    | sort -u || true)

  while IFS= read -r idf; do
    [ -z "$idf" ] && continue
    # Wird der Identifier in der Story mit einem Wiederverwendungs-Marker genannt?
    # Dann ist er eine bestehende Dependency, kein Deliverable → überspringen.
    MENTION=$(grep -i "$idf" "$TMP" 2>/dev/null || true)
    if echo "$MENTION" | grep -qiE "$DEP_MARKERS"; then continue; fi
    HIT=$(grep -rilF "$idf" "$SOURCE_DIR" 2>/dev/null | grep -vE "$SCAN_EXCLUDES" | head -1 || true)
    if [ -n "$HIT" ]; then
      EXISTENCE_HIT="stark"; EXISTENCE_FILE="$HIT"; STRONG_ID="$idf"; break
    fi
  done <<< "$IDENTIFIERS"
fi

# Adjustment: NUR bei starkem Signal Tier herabstufen (verlässlich).
DOWNGRADED=""
if [ "$EXISTENCE_HIT" = "stark" ]; then
  case "$TIER" in
    Opus)   TIER="Sonnet"; TOKENS=$TOKENS_SONNET; TIME=$TIME_SONNET; DOWNGRADED="ja" ;;
    Sonnet) TIER="Haiku";  TOKENS=$TOKENS_HAIKU;  TIME=$TIME_HAIKU;  DOWNGRADED="ja" ;;
  esac
fi

# ═══════════════════════════════════════════════════════════════════════════
# 6 — ZYKLUS-RISIKO (tests/acceptance ohne Test-Runner)
# ═══════════════════════════════════════════════════════════════════════════
CYCLE_RISK=""
TOUCHES_TESTS=$(grep -icE 'tests/acceptance' "$TMP" || true)
NO_RUNNER=""
if [ -n "$SOURCE_DIR" ] && [ -f "$SOURCE_DIR/CLAUDE.md" ]; then
  grep -qiE 'test:.*(NOT CONFIGURED|nicht konfiguriert)' "$SOURCE_DIR/CLAUDE.md" \
    && NO_RUNNER="ja" || true
fi
if [ "$TOUCHES_TESTS" -gt 0 ] && [ -n "$NO_RUNNER" ]; then
  CYCLE_RISK="ja"
  TOKENS=$(( TOKENS * CYCLE_RISK_MULTIPLIER / 10 ))
  TIME=$((   TIME   * CYCLE_RISK_MULTIPLIER / 10 ))
fi

# ═══════════════════════════════════════════════════════════════════════════
# 7 — BUDGET-GATE
# ═══════════════════════════════════════════════════════════════════════════
VERDICT="GO"; EXIT=0
# Nur ganzzahlige Budgets gaten; ungültige Werte ignorieren (kein Gate, kein Crash).
if [ -n "$BUDGET" ] && ! printf '%s' "$BUDGET" | grep -qE '^[0-9]+$'; then
  echo "WARNUNG: Budget-Wert '$BUDGET' (aus $BUDGET_SOURCE) ist keine Ganzzahl — Budget-Gate deaktiviert." >&2
  BUDGET=""; BUDGET_SOURCE=""
fi
if [ -n "$BUDGET" ]; then
  if [ "$TOKENS" -gt "$BUDGET" ]; then VERDICT="NO-GO"; EXIT=20; fi
fi
[ "$EXISTENCE_HIT" = "stark" ] && [ "$EXIT" -eq 0 ] && { VERDICT="GO (mit Warnung)"; EXIT=10; }

# ═══════════════════════════════════════════════════════════════════════════
# 8 — REPORT
# ═══════════════════════════════════════════════════════════════════════════
bar() { printf '─%.0s' $(seq 1 70); echo; }
bar
echo "PRE-FLIGHT  ·  ${REPO:+$REPO }#$ISSUE"
echo "$TITLE"
bar
printf "  Signale     AC:%s  Tasks:%s  neue Dateien:%s  Module:%s\n" \
  "$AC_COUNT" "$TASK_COUNT" "$NEW_FILES" "$MODULES"
printf "  Score       %s / 11   (AC:%s Task:%s New:%s Mod:%s)\n" \
  "$SCORE" "$S_AC" "$S_TASK" "$S_NEW" "$S_MOD"
echo
printf "  Modell      %s\n" "$TIER"
[ -n "$DOWNGRADED" ] && printf "              (herabgestuft — Funktionalität existiert vermutlich)\n"
printf "  Tokens      ~%s\n" "$TOKENS"
printf "  Zeit        ~%s min\n" "$TIME"
[ -n "$CYCLE_RISK" ] && printf "  Zyklus-Risk +50%% eingerechnet (tests/acceptance ohne Test-Runner)\n"
echo
if [ "$EXISTENCE_HIT" = "stark" ]; then
  bar
  echo "  WARNUNG — LÖSUNG A: Funktionalität existiert bereits (starkes Signal)"
  printf "  Identifier '%s' steht im Bestandscode: %s\n" \
    "$STRONG_ID" "${EXISTENCE_FILE#$SOURCE_DIR/}"
  echo "  → Refactor/Extract statt Neubau. Modell herabgestuft."
elif [ -n "$SOURCE_DIR" ]; then
  echo "  Codebase-Scan: keine bestehende Implementierung erkannt"
fi
bar
printf "  VERDIKT     %s\n" "$VERDICT"
[ -n "$BUDGET" ] && printf "  Budget      %s Tokens verfügbar (aus %s)\n" "$BUDGET" "$BUDGET_SOURCE"
bar

# ═══════════════════════════════════════════════════════════════════════════
# 9 — HANDOFF-NOTE bei NO-GO (Anknüpfungspunkt für nächste Session)
# ═══════════════════════════════════════════════════════════════════════════
if [ "$EXIT" -eq 20 ]; then
  echo
  echo "  NO-GO: geschätzte $TOKENS Tokens > Budget $BUDGET."
  echo "  Kopiervorlage für Issue-Kommentar (sauberer Anknüpfungspunkt):"
  echo
  cat <<EOF
### PREFLIGHT-DEFER
issue: #$ISSUE
grund: budget-insufficient
geschätzt: ${TOKENS} Tokens / ${TIME} min
budget-war: ${BUDGET} Tokens
empfohlenes-modell: ${TIER}
status: nicht gestartet — in nächster Session mit ausreichend Budget aufnehmen
EOF
fi

# ═══════════════════════════════════════════════════════════════════════════
# 10 — FEEDBACK-LOOP (A.3): Schätzung protokollieren — NUR im Issue-Modus.
# Ein echter Issue lässt sich später gegen den gemergten Story-PR kalibrieren
# (preflight-calibrate.sh). Im Draft-Modus (ISSUE=ENTWURF) wird nichts geloggt,
# weil es dort keinen späteren Ist-Proxy gibt.
# Format (Tab-getrennt): issue \t tier \t tokens_est \t time_est \t datum
# ═══════════════════════════════════════════════════════════════════════════
if [ -z "$BODYFILE" ] && printf '%s' "$ISSUE" | grep -qE '^[0-9]+$'; then
  mkdir -p .preflight
  printf '%s\t%s\t%s\t%s\t%s\n' \
    "$ISSUE" "$TIER" "$TOKENS" "$TIME" "$(date -u +%F)" >> .preflight/estimates.tsv
fi

exit "$EXIT"
