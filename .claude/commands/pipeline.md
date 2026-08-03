Arbeite die Agent-Pipeline ab, bis nichts mehr zu tun ist.

Regeln:
- Überspringe alles mit Label `needs-human` ausnahmslos.
- Merge oder approve NIEMALS selbst.
- Zwischen zwei Subagent-Aufrufen kurz Queue-Status loggen.

---

## Schritt 1 — Queue-Status ermitteln (konkrete Befehle)

```bash
echo "=== PIPELINE QUEUE CHECK ==="

# 1 — Roheingaben (höchste Priorität)
INPUT=$(gh issue list --label "type:input" --label "status:triage" \
  --json number,title --jq 'sort_by(.number) | .[0] | "#\(.number) \(.title)"' 2>/dev/null)

# 2 — Strukturierte Epics
EPIC=$(gh issue list --label "type:epic" --label "status:ready" \
  --json number,title --jq 'sort_by(.number) | .[0] | "#\(.number) \(.title)"' 2>/dev/null)

# 3 — Re-Submissions (changes-requested oder security-blocked)
RESUBMIT=$(gh issue list --label "type:story" \
  --json number,title,labels \
  --jq '[.[] | select(.labels[].name == "status:changes-requested" or 
                       .labels[].name == "status:security-blocked")] | 
        sort_by(.number) | .[0] | "#\(.number) \(.title)"' 2>/dev/null)

# 4 — Stories bereit für Developer (depends-on prüfen)
STORIES_READY=$(gh issue list --label "type:story" --label "status:ready" \
  --json number,title,body \
  --jq '[.[] | select(
    (.body | test("^depends-on: none$"; "m")) or
    (.body | test("^depends-on:"; "m") | not)
  )] | sort_by(.number) | .[0] | "#\(.number) \(.title)"' 2>/dev/null)

# 5 — PRs für Review
REVIEW=$(gh pr list --label "status:needs-review" \
  --json number,title --jq 'sort_by(.number) | .[0] | "PR #\(.number) \(.title)"' 2>/dev/null)

# 6 — PRs für Security Review
SEC_REVIEW=$(gh pr list --label "status:security-review" \
  --json number,title --jq 'sort_by(.number) | .[0] | "PR #\(.number) \(.title)"' 2>/dev/null)

# 7 — Retro-Trigger prüfen
RETRO_THRESHOLD=$(grep 'retro_intervall_merges:' CLAUDE.md | grep -oE '[0-9]+' | head -1)
LETZTE_RETRO=$(ls docs/retrospective/*.md 2>/dev/null | grep -v TEMPLATE | sort | tail -1)
VON=$([ -n "$LETZTE_RETRO" ] && grep "^- Von:" "$LETZTE_RETRO" | awk '{print $3}' || echo "1970-01-01")
MERGED_COUNT=$(gh pr list --state merged --json mergedAt \
  --jq "[.[] | select(.mergedAt >= \"${VON}\")] | length" 2>/dev/null || echo "0")
RETRO_OPEN=$(gh pr list --label "type:retro" --state open --json number | jq 'length')

echo "type:input triage:   ${INPUT:-leer}"
echo "type:epic ready:     ${EPIC:-leer}"
echo "re-submission:       ${RESUBMIT:-leer}"
echo "story ready:         ${STORIES_READY:-leer}"
echo "needs-review:        ${REVIEW:-leer}"
echo "security-review:     ${SEC_REVIEW:-leer}"
echo "merged since retro:  ${MERGED_COUNT} / ${RETRO_THRESHOLD}"
echo "retro PR offen:      ${RETRO_OPEN}"
echo "==========================="
```

---

## Schritt 2 — Prioritätsreihenfolge und Subagent-Aufruf

Verarbeite immer den ersten Treffer in dieser Reihenfolge:

1. `$INPUT` nicht leer → `architect input #<nr>` (Phase A + B)
2. `$EPIC` nicht leer → `architect epic #<nr>` (Phase B)
3. `$RESUBMIT` nicht leer → `developer resubmit story #<nr>`
4. `$STORIES_READY` nicht leer → `developer story #<nr>`
5. `$REVIEW` nicht leer → `reviewer pr #<nr>`
6. `$SEC_REVIEW` nicht leer → `cso pr #<nr>`
7. `$MERGED_COUNT ≥ $RETRO_THRESHOLD` UND `$RETRO_OPEN = 0` → `retro`

Abhängigkeits-Auflösung nach jedem Developer-Done:
```bash
# Prüfe welche status:backlog-Stories jetzt status:ready werden können
gh issue list --label "type:story" --label "status:backlog" \
  --json number,body --jq '.[] | select(.body | test("^depends-on:"; "m"))' | \
while read -r story; do
  STORY_NR=$(echo "$story" | jq -r '.number')
  DEPS=$(gh issue view "$STORY_NR" --json body \
    --jq '.body | match("^depends-on: (.+)$"; "m").captures[0].string // empty')
  if [ "$DEPS" = "none" ] || [ -z "$DEPS" ]; then continue; fi
  # Alle referenzierten Issues prüfen
  ALL_DONE=true
  for DEP in $(echo "$DEPS" | tr ',' '\n' | grep -oE '[0-9]+'); do
    STATE=$(gh issue view "$DEP" --json state --jq '.state' 2>/dev/null || echo "open")
    [ "$STATE" != "CLOSED" ] && ALL_DONE=false && break
  done
  if $ALL_DONE; then
    gh issue edit "$STORY_NR" --remove-label "status:backlog" --add-label "status:ready"
    echo "Story #${STORY_NR} → status:ready (depends-on aufgelöst)"
  fi
done
```

---

## Schritt 3 — Wiederholen bis alle Queues leer sind

Nach jedem Subagent-Aufruf: zurück zu Schritt 1.
Abbruchbedingung: alle 7 Queues leer.

---

## Schritt 4 — Abschlussbericht

```bash
echo "=== PIPELINE ABSCHLUSSBERICHT ==="
echo "Offene status:approved PRs (warten auf menschlichen Merge):"
gh pr list --label "status:approved" --json number,title \
  --jq '.[] | "  PR #\(.number) \(.title)"'

echo ""
echo "Offene needs-human Eskalationen:"
gh issue list --label "needs-human" --json number,title,labels \
  --jq '.[] | "  #\(.number) \(.title)"'

echo ""
echo "Offener type:retro PR:"
gh pr list --label "type:retro" --state open --json number,title \
  --jq '.[] | "  PR #\(.number) \(.title)"'

echo ""
STALLED=$(gh issue list --label "type:story" --label "status:backlog" \
  --json number,title --jq '.[] | "  #\(.number) \(.title)"')
[ -n "$STALLED" ] && echo "PIPELINE STALLED — blockierte Stories:" && echo "$STALLED"
echo "================================="
```
