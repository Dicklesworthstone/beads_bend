#!/usr/bin/env bash
# graveyard-sweep: Step 0 of every lever (PERFORMANCE-CAMPAIGN). Searches the
# port's ledgers (perf/NEGATIVE-EVIDENCE.md, perf/PERF-LEDGER.md,
# perf/EXPERIMENTS.md) and, when it is installed beside this skill,
# bend2-mega-skill's inherited graveyard, for the lever's words: one `-e word`
# per word, case-insensitive (`rg 'fork\|bang'` reads the bar literally and
# matches nothing: the no-op sweep the worked example's review caught,
# perf/EXPERIMENTS.md EXP-001). Then runs
# `cass search "<words>" --robot --days 60 --limit 20` when cass is on PATH.
# Prints every entry found (file:line and the NE-/EXP- id on that line) or
# `no entry`; when cass is missing prints `BLOCKER: cass unavailable` (the
# card records it; never a silent skip). Writes the marker perf/.sweep-ok
# (lever + UTC time) so the pre-lever hook in
# assets/hooks/settings-fragment-v2.json can see a fresh sweep, and prints the
# card's `graveyard sweep` row verbatim for pasting into perf/EXPERIMENTS.md.
# An entry found means: read its retry predicate; the lever is re-attemptable
# only if the predicate holds now, and the card says why.
#
# usage: graveyard-sweep.sh "<lever words>" [--ledgers perf] [--days 60] [--marker perf/.sweep-ok] [--no-cass]
# exit: 0 swept (entries or none; a cass BLOCKER is still a sweep), 1 failed search/marker, 2 usage.
# Last stdout line: {"schema":"p2b.graveyard-sweep.v1","sha","bend","host","lever","entries":N,"ids":[..],
#   "inherited":N,"cass":"ok:<hits>|BLOCKER|skipped","marker":"perf/.sweep-ok"}
set -uo pipefail
usage() { sed -n '2,/^set -/p' "$0" | sed '$d' | sed 's/^# \{0,1\}//'; }
[[ "${1:-}" == "--help" || "${1:-}" == "-h" || $# -eq 0 ]] && { usage; [[ $# -eq 0 ]] && exit 2; exit 0; }
LEVER=""; LEDGERS="perf"; DAYS=60; MARKER=""; CASS=1
while [[ $# -gt 0 ]]; do
  case "$1" in
    --ledgers) LEDGERS="${2:?--ledgers needs DIR}"; shift 2;;
    --days) DAYS="${2:?--days needs N}"; shift 2;;
    --marker) MARKER="${2:?--marker needs FILE}"; shift 2;;
    --no-cass) CASS=0; shift;;
    -*) echo "error: unknown option $1" >&2; usage >&2; exit 2;;
    *) [[ -z "$LEVER" ]] && LEVER="$1" || LEVER="$LEVER $1"; shift;;
  esac
done
[[ "$LEVER" =~ [^[:space:]] && "$LEVER" != *$'\n'* && "$LEVER" != *$'\r'* ]] || { echo "error: name nonblank lever words on one line" >&2; usage >&2; exit 2; }
[[ "$DAYS" =~ ^[1-9][0-9]*$ ]] || { echo 'error: --days must be positive' >&2; exit 2; }
[[ -d "$LEDGERS" ]] || { echo "error: no ledger directory $LEDGERS (run from the port root)" >&2; exit 2; }
[[ -n "$MARKER" ]] || MARKER="$LEDGERS/.sweep-ok"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
read -ra WORDS <<<"$LEVER"
if command -v rg >/dev/null 2>&1; then
  search() { local pats=(); local w; for w in "${WORDS[@]}"; do pats+=(-e "$w"); done; rg -F -n -i --no-heading --with-filename "${pats[@]}" "$@" 2>/dev/null; }
else
  search() { local pats=(); local w; for w in "${WORDS[@]}"; do pats+=(-e "$w"); done; grep -F -n -i -H "${pats[@]}" "$@" 2>/dev/null; }
fi
files=(); for f in "$LEDGERS"/NEGATIVE-EVIDENCE.md "$LEDGERS"/PERF-LEDGER.md "$LEDGERS"/EXPERIMENTS.md; do [[ -f "$f" ]] && files+=("$f"); done
[[ ${#files[@]} -gt 0 ]] || { echo "error: no ledgers under $LEDGERS (NEGATIVE-EVIDENCE.md, PERF-LEDGER.md, EXPERIMENTS.md)" >&2; exit 2; }
hits="$(search "${files[@]}")"; search_rc=$?; n=0; ids=""
[[ $search_rc -le 1 ]] || { echo 'error: ledger search failed; sweep not certified' >&2; exit 1; }
if [[ -n "$hits" ]]; then
  n="$(printf '%s\n' "$hits" | wc -l | tr -d ' ')"
  echo "ledger entries for '$LEVER' ($n line(s)):"
  printf '%s\n' "$hits" | head -40 | sed 's/^/  /'
  ids="$(printf '%s\n' "$hits" | grep -oE '(NE|EXP)-[0-9]+' | sort -u | tr '\n' ' ' | sed 's/ *$//')"
  [[ -n "$ids" ]] && echo "  ids: $ids (read each retry predicate before the card)"
else
  echo "ledger entries for '$LEVER': no entry"
fi
# the inherited graveyard (bend2-mega-skill beside this skill, or MEGA_SKILL_DIR)
inh=0; MEGA="${MEGA_SKILL_DIR:-$HERE/../../bend2-mega-skill}"
if [[ -f "$MEGA/assets/ledgers/NEGATIVE-EVIDENCE.md" ]]; then
  ih="$(search "$MEGA/assets/ledgers/NEGATIVE-EVIDENCE.md")"
  search_rc=$?
  [[ $search_rc -le 1 ]] || { echo 'error: inherited ledger search failed; sweep not certified' >&2; exit 1; }
  if [[ -n "$ih" ]]; then inh="$(printf '%s\n' "$ih" | wc -l | tr -d ' ')"; echo "inherited graveyard (bend2-mega-skill): $inh line(s)"; printf '%s\n' "$ih" | head -20 | sed 's/^/  /'; else echo "inherited graveyard (bend2-mega-skill): no entry"; fi
else
  echo "inherited graveyard: bend2-mega-skill not found beside this skill (the scaffold's ledgers carried it when present)"
fi
# cass over the last DAYS days
cass_s="skipped"
if [[ $CASS -eq 1 ]]; then
  if command -v cass >/dev/null 2>&1; then
    ch="$(cass search "$LEVER reverted OR slower OR no improvement OR refused" --robot --days "$DAYS" --limit 20 2>/dev/null)"; cass_rc=$?
    k="$(printf '%s' "$ch" | python3 -c '
import json,sys
try:
    data=json.load(sys.stdin)
    if not isinstance(data.get("hits"),list) or data.get("budget",{}).get("timed_out"): raise ValueError("incomplete search")
    print(len(data["hits"]))
except (ValueError,TypeError,AttributeError): sys.exit(1)
')"; parse_rc=$?
    if [[ $cass_rc -eq 0 && $parse_rc -eq 0 ]]; then
      cass_s="ok:$k"; echo "cass search --days $DAYS: $k returned hit(s)"
      printf '%s\n' "$ch" | sed 's/^/  /'
    else
      cass_s="BLOCKER"; echo 'BLOCKER: cass search failed, timed out, or returned invalid JSON (record in the card)'
    fi
  else
    cass_s="BLOCKER"; echo "BLOCKER: cass unavailable (record this line in the card; do not skip the sweep silently)"
  fi
fi
printf 'lever: %s\nswept: %s\n' "$LEVER" "$(date -u +%Y-%m-%dT%H:%M:%SZ)" >"$MARKER" || { echo "error: cannot write sweep marker $MARKER" >&2; exit 1; }
patstr=""; for w in "${WORDS[@]}"; do patstr+="-e '$w' "; done
echo "--"
echo "card row (paste into perf/EXPERIMENTS.md):"
printf '| graveyard sweep | `rg -F -n -i %s%s/*.md` → %s; inherited: %s; cass (%s d): %s |\n' "$patstr" "$LEDGERS" "$( [[ $n -gt 0 ]] && echo "$n line(s) ${ids:+[$ids]}" || echo 'no entry')" "$( [[ $inh -gt 0 ]] && echo "$inh line(s)" || echo 'no entry')" "$DAYS" "$cass_s"
sha="$(git rev-parse --short HEAD 2>/dev/null || echo none)"; host="$(uname -s -m 2>/dev/null | tr ' ' '-')"
if [[ -n "${BEND_CLI:-}" ]]; then read -ra BEND <<<"$BEND_CLI"; else BEND=(bend); fi
bendv="$("${BEND[@]}" --version 2>/dev/null | tail -1)"
python3 - "$sha" "$bendv" "$host" "$LEVER" "$n" "$ids" "$inh" "$cass_s" "$MARKER" <<'PY'
import json,sys
keys=('sha','bend','host','lever','entries','ids','inherited','cass','marker')
row=dict(zip(keys,sys.argv[1:]))
row['entries']=int(row['entries']); row['inherited']=int(row['inherited'])
row['ids']=row['ids'].split()
print(json.dumps(dict(schema='p2b.graveyard-sweep.v1',**row)))
PY
exit 0
