#!/usr/bin/env bash
# interp-sample: the interpreter lane on a SAMPLE of the corpus (this port's own script, bead bb-oxc). The interpreter
# type-checks the whole program on every case (~4.5 min and ~11 GB each at this size), so the full corpus is out of
# reach; the sample is the first case of every case-name prefix (the `r8_`..`r12_` round prefixes use their second
# word), each row prefixed with `@env=BUN_JSC_forceRAMSize=10737418240` (bun's heap sized for a shared host) and
# `@env=INTERP_NOTE_CACHE=1` (the checker's note computed once). The result is PARTIAL by construction.
# usage: interp-sample.sh [--list] [--limit N]
#   --list    print the sample rows and exit
#   --limit N the first N rows only
# Writes the conform log to $TMPDIR/interp-sample.log; its last stdout line is conform's JSON without the cases array.
# exit: conform's exit code; 2 usage.
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/.." && pwd)"
LIST=0; LIMIT=0
while [[ $# -gt 0 ]]; do
  case "$1" in
    --help|-h) sed -n '2,/^set -/p' "$0" | sed '$d; s/^# \{0,1\}//'; exit 0;;
    --list) LIST=1; shift;;
    --limit) [[ $# -ge 2 && "$2" =~ ^[0-9]+$ ]] || { echo "error: --limit needs a number" >&2; exit 2; }; LIMIT="$2"; shift 2;;
    *) echo "error: unknown argument $1" >&2; exit 2;;
  esac
done
OUT="${TMPDIR:-/tmp}"
SAMPLE="$OUT/interp-sample.tsv"
python3 - "$ROOT/goldens/cases.tsv" "$SAMPLE" "$LIMIT" <<'EOF'
import json, sys
src, dst, limit = sys.argv[1], sys.argv[2], int(sys.argv[3])
seen, rows = set(), []
with open(src, encoding="utf-8") as fh:
    for line in fh:
        if line.startswith("#") or not line.strip():
            continue
        parts = line.rstrip("\n").split("\t")
        words = parts[0].split("_")
        prefix = words[1] if words[0] in ("r8", "r9", "r10", "r12") and len(words) > 1 else words[0]
        if prefix in seen:
            continue
        seen.add(prefix)
        argv = json.loads(parts[1])
        # ws_inner.py refuses @env on a scenario (it applies to one step), so a @scn row runs with the defaults
        if not any(a.startswith("@scn=") for a in argv):
            argv = ["@env=BUN_JSC_forceRAMSize=10737418240", "@env=INTERP_NOTE_CACHE=1"] + argv
        rows.append("\t".join([parts[0], json.dumps(argv)] + parts[2:]))
if limit:
    rows = rows[:limit]
with open(dst, "w", encoding="utf-8") as fh:
    fh.write("\n".join(rows) + "\n")
EOF
if [[ $LIST -eq 1 ]]; then cat "$SAMPLE"; exit 0; fi
cd "$ROOT" || exit 2
"$HERE/conform.sh" "$SAMPLE" goldens --lane interpreter --timeout 900 -- "$HERE/ws-run.sh" \
  bash -c 'exec 3>> "$1" || exit 125; shift; exec "$@"' bend-interpreter "$OUT/interp-sample.note" \
  "$HERE/interp-lane.sh" "$HERE/bend-cli.sh" "$ROOT/port/main.bend" -- :: > "$OUT/interp-sample.log" 2>&1
rc=$?
tail -1 "$OUT/interp-sample.log" | python3 -c "import json,sys; d=json.load(sys.stdin); d.pop('cases', None); print(json.dumps(d))"
exit $rc
