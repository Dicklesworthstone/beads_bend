#!/usr/bin/env bash
# make-fixture: produce goldens/fixtures/<name>.jsonl by running a scenario
# through the ORIGINAL in the ws-run sandbox and saving the store it leaves.
# Fixtures are inputs, but the realistic ones are the original's own output:
# nothing here is hand-typed, and the scenario file is the fixture's provenance.
#
# usage: make-fixture.sh <fixture-name> <scenario-name> [-- <original command…>]
#        (default original: br --no-db)
# Refuses to overwrite an existing fixture: goldens depend on fixture bytes, so
# a changed fixture is a new name (or an explicit move of the old file) plus a
# `golden-capture.sh --repin`.
# exit: 0 written, 1 a scenario step failed or left no store, 2 usage/exists.
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; ROOT="$(cd "$HERE/.." && pwd)"
if [[ "${1:-}" == --help || "${1:-}" == -h ]]; then sed -n '2,/^set -/p' "$0" | sed '$d; s/^# \{0,1\}//'; exit 0; fi
NAME="${1:-}"; SCN="${2:-}"; shift 2 2>/dev/null || { echo 'usage: make-fixture.sh <fixture-name> <scenario-name> [-- <original…>]' >&2; exit 2; }
[[ "$NAME" =~ ^[a-z][a-z0-9_]*$ ]] || { echo 'error: fixture name must match [a-z][a-z0-9_]*' >&2; exit 2; }
[[ "${1:-}" == -- ]] && shift
ORIGINAL=("$@"); [[ ${#ORIGINAL[@]} -gt 0 ]] || ORIGINAL=(br --no-db)
OUT="$ROOT/goldens/fixtures/$NAME.jsonl"
[[ ! -e "$OUT" ]] || { echo "error: $OUT exists; fixtures are never overwritten (see --help)" >&2; exit 2; }
[[ -f "$ROOT/goldens/scenarios/$SCN.scn" ]] || { echo "error: no scenario goldens/scenarios/$SCN.scn" >&2; exit 2; }
"$HERE/ws-run.sh" --oracle "${ORIGINAL[@]}" :: "@scn=$SCN" 2>/dev/null | python3 -B -c '
import sys
data = sys.stdin.buffer.read().split(b"\n")
marker = b"--- .beads/issues.jsonl ---"
bad = [line for line in data if line.startswith(b"[exit ") and line != b"[exit 0]"]
if bad:
    sys.exit("error: a scenario step failed: " + bad[0].decode())
starts = [i for i, line in enumerate(data) if line == marker]
if not starts:
    sys.exit("error: the scenario never changed the store")
block = []
for line in data[starts[-1] + 1:]:
    if line.startswith(b"--- .beads/") or line.startswith(b"[exit "):
        break
    block.append(line)
with open(sys.argv[1], "xb") as out:
    out.write(b"\n".join(block) + b"\n")
print(f"wrote {sys.argv[1]}: {len(block)} records")
' "$OUT"
