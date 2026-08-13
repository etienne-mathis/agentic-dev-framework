#!/usr/bin/env bash
###############################################################################
# measure-run.sh — echte Token-Messung aus den Claude-Code-Session-jsonl (P3.0)
#
# Behebt Problem 7 (Token-Kosten unbekannt). Statt eines Diff-Größen-Proxys liest
# dieses Skript den TATSÄCHLICHEN Verbrauch aus den lokalen Session-Logs von
# Claude Code:
#   ~/.claude/projects/<repo-slug>/*.jsonl
# Jede assistant-Zeile trägt message.usage mit:
#   input_tokens · output_tokens · cache_read_input_tokens · cache_creation_input_tokens
#
# Es aggregiert alle usage-Werte in einem Zeit-/Session-Fenster (= ein Rollen-Spawn),
# bestimmt Wall-Clock und Modell-Tier und schreibt eine Tab-getrennte Zeile nach
#   .preflight/actuals.tsv
# mit Spalten:
#   issue \t rolle \t modell \t in_tokens \t out_tokens \t cache_read \t sekunden \t datum
#
# Eigenschaften (bewusst):
#   - REIN LESEND gegenüber den jsonl. Kein API-Key. Zero-Infra.
#   - Der repo-slug wird aus dem absoluten Pfad abgeleitet (alle Zeichen außer
#     [A-Za-z0-9-] → '-'), exakt wie Claude Code die Projektordner benennt.
#
# Aufruf:
#   ./measure-run.sh --issue 42 --rolle developer \
#       --from 2026-08-13T19:00:00Z [--to 2026-08-13T19:20:00Z] \
#       [--modell Sonnet] [--session <id>] [--source-dir .] [--slug <slug>] \
#       [--out .preflight/actuals.tsv] [--dry-run]
#
#   Ohne --to gilt "jetzt". Ohne --modell wird das dominante Modell im Fenster erkannt.
###############################################################################
set -euo pipefail

ISSUE=""; ROLLE=""; MODELL=""; FROM=""; TO=""; SESSION=""
SRC_DIR="."; SLUG=""; OUT=".preflight/actuals.tsv"; DRY=0

while [ $# -gt 0 ]; do
  case "$1" in
    --issue)      ISSUE="$2"; shift 2 ;;
    --rolle)      ROLLE="$2"; shift 2 ;;
    --modell)     MODELL="$2"; shift 2 ;;
    --from)       FROM="$2"; shift 2 ;;
    --to)         TO="$2"; shift 2 ;;
    --session)    SESSION="$2"; shift 2 ;;
    --source-dir) SRC_DIR="$2"; shift 2 ;;
    --slug)       SLUG="$2"; shift 2 ;;
    --out)        OUT="$2"; shift 2 ;;
    --dry-run)    DRY=1; shift ;;
    -h|--help)    grep '^#' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *)            echo "Unbekanntes Argument: $1" >&2; exit 2 ;;
  esac
done

[ -z "$ISSUE" ] && { echo "FEHLER: --issue <nr> fehlt." >&2; exit 2; }
[ -z "$ROLLE" ] && { echo "FEHLER: --rolle <name> fehlt." >&2; exit 2; }
[ -z "$FROM" ]  && { echo "FEHLER: --from <ISO-Zeit> fehlt (Fensterbeginn)." >&2; exit 2; }

# Slug aus dem absoluten Pfad ableiten, falls nicht explizit übergeben.
if [ -z "$SLUG" ]; then
  ABS=$(cd "$SRC_DIR" 2>/dev/null && pwd) || { echo "FEHLER: --source-dir ungültig: $SRC_DIR" >&2; exit 2; }
  SLUG=$(printf '%s' "$ABS" | sed -E 's#[^A-Za-z0-9-]#-#g')
fi

PROJ_DIR="$HOME/.claude/projects/$SLUG"
if [ ! -d "$PROJ_DIR" ]; then
  echo "FEHLER: Kein Session-Verzeichnis: $PROJ_DIR" >&2
  echo "  (Slug aus dem Arbeitsverzeichnis abgeleitet. --slug zum Überschreiben.)" >&2
  exit 1
fi

# Aggregation in Python — robust gegen kaputte/partielle jsonl-Zeilen.
RESULT=$(FROM="$FROM" TO="$TO" SESSION="$SESSION" MODELL="$MODELL" \
  python3 - "$PROJ_DIR"/*.jsonl <<'PYEOF'
import sys, os, json, glob, re
from datetime import datetime, timezone

def parse_ts(s):
    if not s:
        return None
    s = s.strip().replace("Z", "+00:00")
    try:
        dt = datetime.fromisoformat(s)
    except ValueError:
        # Nur Datum? Als Mitternacht UTC interpretieren.
        try:
            dt = datetime.strptime(s[:10], "%Y-%m-%d").replace(tzinfo=timezone.utc)
        except ValueError:
            return None
    if dt.tzinfo is None:
        dt = dt.replace(tzinfo=timezone.utc)
    return dt

frm = parse_ts(os.environ.get("FROM", ""))
to  = parse_ts(os.environ.get("TO", "")) or datetime.now(timezone.utc)
session = os.environ.get("SESSION", "").strip()

in_tok = out_tok = cache_read = cache_create = 0
first_ts = last_ts = None
model_counts = {}

for path in sys.argv[1:]:
    try:
        fh = open(path, "r", encoding="utf-8", errors="replace")
    except OSError:
        continue
    with fh:
        for line in fh:
            line = line.strip()
            if not line:
                continue
            try:
                rec = json.loads(line)
            except json.JSONDecodeError:
                continue
            if session and rec.get("sessionId") != session:
                continue
            ts = parse_ts(rec.get("timestamp"))
            if ts is None or ts < frm or ts > to:
                continue
            msg = rec.get("message")
            if not isinstance(msg, dict):
                continue
            usage = msg.get("usage")
            if not isinstance(usage, dict):
                continue
            model = msg.get("model", "") or ""
            i = usage.get("input_tokens", 0) or 0
            o = usage.get("output_tokens", 0) or 0
            cr = usage.get("cache_read_input_tokens", 0) or 0
            cc = usage.get("cache_creation_input_tokens", 0) or 0
            # Synthetische/leere Zeilen (model "<synthetic>", 0 Tokens) tragen nichts bei.
            if model.startswith("<") or (i + o + cr + cc) == 0:
                continue
            in_tok += i; out_tok += o; cache_read += cr; cache_create += cc
            model_counts[model] = model_counts.get(model, 0) + 1
            if first_ts is None or ts < first_ts:
                first_ts = ts
            if last_ts is None or ts > last_ts:
                last_ts = ts

# Modell-Tier bestimmen: explizit vorgegeben oder aus dem häufigsten Modellstring.
def tier_from_model(m):
    m = m.lower()
    if "haiku" in m:  return "Haiku"
    if "sonnet" in m: return "Sonnet"
    if "opus" in m:   return "Opus"
    return "?"

modell_env = os.environ.get("MODELL", "").strip()
if modell_env:
    tier = modell_env[0].upper() + modell_env[1:].lower()
elif model_counts:
    dominant = max(model_counts, key=model_counts.get)
    tier = tier_from_model(dominant)
else:
    tier = "?"

seconds = 0
if first_ts and last_ts:
    seconds = int((last_ts - first_ts).total_seconds())

msgs = sum(model_counts.values())
# Ausgabe: tier<TAB>in<TAB>out<TAB>cache_read<TAB>cache_create<TAB>seconds<TAB>msgs
print("\t".join(str(x) for x in
      [tier, in_tok, out_tok, cache_read, cache_create, seconds, msgs]))
PYEOF
)

IFS=$'\t' read -r TIER IN OUT_TOK CACHE_READ CACHE_CREATE SECONDS_AGG MSGS <<< "$RESULT"

if [ "${MSGS:-0}" -eq 0 ]; then
  echo "WARNUNG: Keine usage-tragenden Nachrichten im Fenster gefunden." >&2
  echo "  Fenster: ${FROM} .. ${TO:-jetzt}  Slug: $SLUG" >&2
  echo "  Ist der Zeitstempel korrekt (UTC, Format ...Z)?" >&2
  exit 3
fi

DATUM=$(date -u +%Y-%m-%d)
ROW=$(printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s' \
  "$ISSUE" "$ROLLE" "$TIER" "$IN" "$OUT_TOK" "$CACHE_READ" "$SECONDS_AGG" "$DATUM")

echo "── measure-run ──────────────────────────────────────────────"
printf '  issue=#%s rolle=%s modell=%s\n' "$ISSUE" "$ROLLE" "$TIER"
printf '  in=%s out=%s cache_read=%s cache_create=%s  (%s Nachrichten)\n' \
  "$IN" "$OUT_TOK" "$CACHE_READ" "$CACHE_CREATE" "$MSGS"
printf '  wall-clock=%ss\n' "$SECONDS_AGG"

if [ "$DRY" -eq 1 ]; then
  echo "  [--dry-run] nicht geschrieben. Zeile:"
  printf '  %s\n' "$ROW"
  exit 0
fi

mkdir -p "$(dirname "$OUT")"
if [ ! -f "$OUT" ]; then
  printf '# issue\trolle\tmodell\tin_tokens\tout_tokens\tcache_read\tsekunden\tdatum\n' > "$OUT"
fi
printf '%s\n' "$ROW" >> "$OUT"
echo "  → angehängt an $OUT"
echo "─────────────────────────────────────────────────────────────"
