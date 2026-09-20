#!/usr/bin/env bash
# quick-lanes: the two fast lanes (c-1t and js) over the whole corpus, for iteration.
# The gate is scripts/lanes.sh (four lanes); this is the inner loop it is too slow for:
# the interpreter lane type-checks the program for every case (docs/PORT_STATE.md).
# Builds port/main.bend once per lane into OUT, runs scripts/conform.sh through the
# sandbox, and writes each lane's last line (its JSON) to OUT/conform_<lane>.json.
#
# usage: quick-lanes.sh <out-dir>
# exit: 0 both lanes PASS, 1 a lane failed or could not be built, 2 usage.
set -uo pipefail
[[ $# -eq 1 && -d "$1" ]] || { sed -n '2,/^set -/p' "$0" | sed '$d' | sed 's/^# \{0,1\}//' >&2; exit 2; }
OUT="$(cd "$1" && pwd)"
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export BEND_NO_TELEMETRY=1
BEND="${BEND_CLI:-$ROOT/scripts/bend-cli.sh}"
cd "$ROOT" || exit 1
status=0
( cd port && "$BEND" main.bend -o "$OUT/bn" ) >>"$OUT/build_c.log" 2>&1 || { echo "quick-lanes: the C build failed (see $OUT/build_c.log)" >&2; exit 1; }
( cd port && "$BEND" main.bend -o "$OUT/bn.js" ) >>"$OUT/build_js.log" 2>&1 || { echo "quick-lanes: the JS build failed (see $OUT/build_js.log)" >&2; exit 1; }
./scripts/conform.sh goldens/cases.tsv goldens --lane c-1t --timeout 60 -- scripts/ws-run.sh "$OUT/bn" --threads 1 --gpu off -- :: 2>/dev/null | tail -1 | tee "$OUT/conform_c-1t.json" | cut -c1-200
./scripts/conform.sh goldens/cases.tsv goldens --lane js --timeout 60 -- scripts/ws-run.sh python3 "$ROOT/scripts/js-lane.py" "$OUT/bn.js" -- :: 2>/dev/null | tail -1 | tee "$OUT/conform_js.json" | cut -c1-200
for lane in c-1t js; do
  grep -q '"verdict":"PASS"' "$OUT/conform_$lane.json" || status=1
done
exit "$status"
