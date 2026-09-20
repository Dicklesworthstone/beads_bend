#!/usr/bin/env bash
# version-drift: run a port's gates under two Bend CLIs and diff what a
# porter's claims rest on: `bend --version`, the proof verdict and its unsafe
# count, and the per-lane conformance verdicts (lanes.sh). Nothing is fixed;
# the script reports. A difference in any of those is DRIFT: the port's
# PORT_STATE and claims were made under one CLI and must be re-stated (or the
# port fixed) under the other.
#
# usage: version-drift.sh --old "<cli>" --new "<cli>" [--root DIR] [--threads N]
#                         [--gpu] [--no-stderr] [--probes DIR] [--timeout S]
#   --timeout     maximum seconds for each gate (default 600; version/proof/probes use smaller limits)
#   --old/--new   a Bend CLI as one string: "bend", "bun /path/bend2/main.ts",
#                 "/usr/local/bin/bend-2.0.13" (BEND_CLI is set to it per run)
#   --root        the port's root (default: cwd) with goldens/, port/, scripts/
#   --threads     the parallel lane's thread count (default: 4)
#   --gpu         pass --gpu to lanes.sh
#   --no-stderr   pass --no-stderr to lanes.sh
#   --probes DIR  also run every DIR/*.bend on the interpreter under both CLIs
#                 and diff stdout+stderr+exit (the skill's assets/probes/base)
#                 Optional '#! args: ["..."]' supplies exact application argv.
#                 Every probe repeats under each CLI; timeout or volatility is
#                 INCONCLUSIVE. Small-workload directives only test completion,
#                 not a fixture's separate manual timing/kill experiment.
# lanes.sh always runs the interpreter through interp-lane.sh to remove
# the compiler-owned pre-run checker note.
# exit: 0 SAME, 1 DRIFT/INCONCLUSIVE, 2 usage or a CLI that does not answer --version.
# Last stdout line:
#   {"old":{"cli","version","proof","unsafe","lanes":{lane:verdict,...},"lanes_verdict","probes_diff":[..]},
#    "new":{...},"drift":["version","proof","unsafe","lanes:<lane>","probes:<name>",...],"verdict":"SAME|DRIFT"}
set -uo pipefail
export PYTHONDONTWRITEBYTECODE=1
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
usage() { sed -n '2,/^set -/p' "$0" | sed '$d' | sed 's/^# \{0,1\}//'; }
[[ "${1:-}" == "--help" || "${1:-}" == "-h" ]] && { usage; exit 0; }
OLD=""; NEW=""; ROOT="$PWD"; THREADS=4; GPU=""; NOERR=""; PROBES=""; LIMIT=600
while [[ $# -gt 0 ]]; do
  case "$1" in
    --old|--new|--root|--threads|--probes|--timeout) [[ $# -ge 2 && -n "$2" ]] || { echo "error: $1 needs a value" >&2; exit 2; };;
  esac
  case "$1" in
    --old) OLD="${2:?--old needs CLI}"; shift 2;;
    --new) NEW="${2:?--new needs CLI}"; shift 2;;
    --root) ROOT="${2:?--root needs DIR}"; shift 2;;
    --threads) THREADS="${2:?--threads needs N}"; shift 2;;
    --gpu) GPU="--gpu"; shift;;
    --no-stderr) NOERR="--no-stderr"; shift;;
    --probes) PROBES="${2:?--probes needs DIR}"; shift 2;;
    --timeout) LIMIT="$2"; shift 2;;
    *) echo "error: unknown option $1" >&2; usage >&2; exit 2;;
  esac
done
[[ -n "$OLD" && -n "$NEW" ]] || { usage >&2; exit 2; }
[[ "$THREADS" =~ ^[1-9][0-9]*$ ]] || { echo 'error: --threads needs a positive integer' >&2; exit 2; }
python3 -c 'import math,sys; n=float(sys.argv[1]); sys.exit(not math.isfinite(n) or n<=0)' "$LIMIT" || { echo 'error: timeout must be finite and positive' >&2; exit 2; }
if [[ -n "$PROBES" ]]; then
  [[ -d "$PROBES" ]] || { echo "error: probe directory not found: $PROBES" >&2; exit 2; }
  PROBES="$(cd "$PROBES" && pwd)"
  probe_files=("$PROBES"/*.bend)
  [[ -f "${probe_files[0]}" ]] || { echo 'error: no .bend probes' >&2; exit 2; }
fi
cd "$ROOT" || { echo "error: no such root $ROOT" >&2; exit 2; }
export BEND_NO_TELEMETRY=1
TMP="$(mktemp -d "${TMPDIR:-/tmp}/version-drift.XXXXXX")"
run_to() {
  local seconds="$1"; shift
  python3 - "$HERE" "$seconds" "$LIMIT" "$@" <<'PY'
import sys
sys.path.insert(0,sys.argv[1])
from case_manifest import run
r=run(sys.argv[4:],timeout=min(float(sys.argv[2]),float(sys.argv[3])),merge_stderr=True)
sys.stdout.buffer.write(r['out'])
sys.exit(r['rc'] if r['rc'] is not None else 125)
PY
}
inconclusive=0
fingerprint() {
  python3 - "$HERE" "$PROBES" <<'PY'
import hashlib,json,pathlib,sys
sys.path.insert(0,sys.argv[1])
from case_manifest import regular_bytes
rows={}
for base in ['port','scripts','goldens']+([sys.argv[2]] if sys.argv[2] else []):
    root=pathlib.Path(base)
    if not root.is_dir() or root.is_symlink(): sys.exit('cannot fingerprint source directory: '+base)
    for path in sorted(root.rglob('*')):
        if path.is_dir():
            if path.is_symlink(): sys.exit('cannot fingerprint directory symlink: '+str(path))
            continue
        rows[str(path)]=hashlib.sha256(regular_bytes(path)).hexdigest()
print(json.dumps(rows,sort_keys=True))
PY
}
fingerprint >"$TMP/inputs.before.json" || exit 2

# gates <tag> <cli>: version, proof line, unsafe count, lanes JSON, probes
gates() {
  local tag="$1" cli="$2"; local -a B=(); local word
  while IFS= read -r -d '' word; do B+=("$word"); done < <(python3 -c 'import pathlib,shlex,shutil,sys; a=shlex.split(sys.argv[1]); a[0]=shutil.which(a[0]) or a[0]; [sys.stdout.buffer.write((str(pathlib.Path(x).resolve()) if pathlib.Path(x).is_file() else x).encode()+b"\0") for x in a]' "$cli")
  [[ ${#B[@]} -gt 0 ]] || { echo 'error: invalid/empty CLI' >&2; exit 2; }
  local ver; ver="$(run_to 30 "${B[@]}" --version 2>&1 | tail -1)" || { echo "error: $cli does not answer --version" >&2; exit 2; }
  [[ "$ver" =~ ^bend\ [0-9]+\.[0-9]+\.[0-9]+([+-][A-Za-z0-9.-]+)?$ ]] || { echo "error: $cli returned no recognizable Bend version: $ver" >&2; exit 2; }
  local proof="MISSING" unsafe="?"
  if [[ -f port/PROOF.bend ]]; then
    proof="$(cd port && run_to 120 "${B[@]}" PROOF.bend 2>&1 | tail -1)"; proof_rc=$?
    [[ $proof_rc -eq 0 && "$proof" =~ ^All\ terms\ check(,\ with\ [0-9]+\ unsafe\ annotations?)?\.$ ]] || inconclusive=1
    if [[ "$proof" == "All terms check." ]]; then unsafe=0
    elif [[ "$proof" =~ with\ ([0-9]+)\ unsafe ]]; then unsafe="${BASH_REMATCH[1]}"; fi
  fi
  local lanes_json="" lanes_v="MISSING"
  local lanes="scripts/lanes.sh"; [[ -f "$lanes" ]] || lanes="$HERE/lanes.sh"
  if [[ -f "$lanes" && -f goldens/cases.tsv && -f port/main.bend ]]; then
    BEND_CLI="$cli" run_to 600 bash "$lanes" goldens/cases.tsv goldens port/main.bend --threads "$THREADS" $GPU $NOERR >"$TMP/$tag.lanes" 2>&1; lanes_rc=$?
    lanes_json="$(grep '^{' "$TMP/$tag.lanes" | tail -1)"
    lanes_v="$(printf '%s' "$lanes_json" | PYTHONPATH="$HERE${PYTHONPATH:+:$PYTHONPATH}" python3 -c 'import json,sys; from case_manifest import cases,validate_lanes; x=json.load(sys.stdin); validate_lanes(x,int(sys.argv[1]),gpu=bool(sys.argv[2]),check_err=not bool(sys.argv[3]),case_count=len(cases("goldens/cases.tsv"))); print(x["verdict"])' "$THREADS" "$GPU" "$NOERR" 2>/dev/null)" || lanes_v=ERROR
    [[ $lanes_rc -eq 0 ]] || { lanes_v=ERROR; inconclusive=1; }
  fi
  [[ "$proof" != MISSING && "$lanes_v" == PASS ]] || inconclusive=1
  if [[ -n "$PROBES" && -d "$PROBES" ]]; then
    mkdir -p "$TMP/$tag.probes"
    for f in "$PROBES"/*.bend; do
      local n; n="$(basename "$f" .bend)"
      # Keep JSON argv boundaries; invalid or duplicate directives cannot
      # silently fall back to the fixture's potentially expensive default.
      if ! python3 -B - "$HERE" "$f" >"$TMP/$tag.probes/$n.argv" <<'PY'
import sys
from pathlib import Path
sys.path.insert(0, sys.argv[1])
from case_manifest import argv
try:
    directives = [line.split(':', 1)[1] for line in Path(sys.argv[2]).read_text().splitlines() if line.startswith('#! args:')]
    if len(directives) > 1:
        raise ValueError('duplicate #! args directive')
    for argument in argv(directives[0]) if directives else []:
        sys.stdout.buffer.write(argument.encode() + b'\0')
except (OSError, ValueError) as exc:
    print(f'error: probe argv: {exc}', file=sys.stderr)
    sys.exit(2)
PY
      then
        echo "INCONCLUSIVE: malformed probe arguments in $n" >&2; inconclusive=1
        printf '%s\n' 'malformed probe arguments' >"$TMP/$tag.probes/$n.err"
        : >"$TMP/$tag.probes/$n.out"; printf '2\n' >"$TMP/$tag.probes/$n.exit"
        continue
      fi
      local -a ARGV=(); local argument
      while IFS= read -r -d '' argument; do ARGV+=("$argument"); done <"$TMP/$tag.probes/$n.argv"
      # Preserve separate stdout/stderr for probe byte comparisons.
      probe_run() { python3 - "$HERE" "$LIMIT" "$@" <<'PY'
import sys
sys.path.insert(0,sys.argv[1])
from case_manifest import run
r=run(sys.argv[3:],timeout=min(30,float(sys.argv[2])))
sys.stdout.buffer.write(r['out']); sys.stderr.buffer.write(r['err'])
sys.exit(r['rc'] if r['rc'] is not None else 125)
PY
      }
      probe_run "${B[@]}" "$f" -- ${ARGV[@]+"${ARGV[@]}"} >"$TMP/$tag.probes/$n.out" 2>"$TMP/$tag.probes/$n.err"; prc=$?; echo "$prc" >"$TMP/$tag.probes/$n.exit"
      if [[ "$prc" -ge 124 ]]; then
        echo "INCONCLUSIVE: probe $n under $tag exited $prc (timeout, launcher or signal)" >&2; inconclusive=1
      fi
      # A volatile probe cannot establish compiler drift. Run the same CLI
      # again before comparing it with a different CLI.
      probe_run "${B[@]}" "$f" -- ${ARGV[@]+"${ARGV[@]}"} >"$TMP/$tag.probes/$n.repeat.out" 2>"$TMP/$tag.probes/$n.repeat.err"; rrc=$?
      if [[ "$rrc" -ge 124 ]]; then
        echo "INCONCLUSIVE: repeat probe $n under $tag exited $rrc (timeout, launcher or signal)" >&2; inconclusive=1
      fi
      if [[ "$prc" != "$rrc" ]] || ! cmp -s "$TMP/$tag.probes/$n.out" "$TMP/$tag.probes/$n.repeat.out" || ! cmp -s "$TMP/$tag.probes/$n.err" "$TMP/$tag.probes/$n.repeat.err"; then
        echo "INCONCLUSIVE: volatile probe $n under $tag" >&2; inconclusive=1
      fi
    done
  fi
  printf '%s\n' "$ver" >"$TMP/$tag.version"; printf '%s\n' "$proof" >"$TMP/$tag.proof"
  printf '%s\n' "$unsafe" >"$TMP/$tag.unsafe"; printf '%s\n' "$lanes_json" >"$TMP/$tag.lanesjson"; printf '%s\n' "$lanes_v" >"$TMP/$tag.lanesv"
  echo "[$tag] $cli"
  echo "  version: $ver"
  echo "  proof:   $proof (unsafe $unsafe)"
  echo "  lanes:   ${lanes_v:-ERROR}"
  printf '%s' "$lanes_json" | grep -o '{"lane":"[^"]*","verdict":"[A-Z]*","passed":[0-9]*,"failed":[0-9]*}' | sed 's/^/           /'
}
gates old "$OLD"
gates new "$NEW"
fingerprint >"$TMP/inputs.after.json" || inconclusive=1
cmp -s "$TMP/inputs.before.json" "$TMP/inputs.after.json" || { echo 'INCONCLUSIVE: inputs changed during drift checks' >&2; inconclusive=1; }

python3 - "$TMP" "$OLD" "$NEW" "$inconclusive" <<'PY'
import json, pathlib, sys
root = pathlib.Path(sys.argv[1])
inconclusive = sys.argv[4] != '0'
def side(tag, cli):
    global inconclusive
    row = {'cli': cli}
    for key, suffix in [('version','version'), ('proof','proof'), ('unsafe','unsafe'), ('lanes_verdict','lanesv')]:
        row[key] = (root / f'{tag}.{suffix}').read_text().rstrip('\n')
    try:
        lanes = json.loads((root / f'{tag}.lanesjson').read_text())['lanes']
        row['lanes'] = {item['lane']: item['verdict'] for item in lanes}
        if not lanes or len(row['lanes']) != len(lanes):
            raise ValueError('missing or duplicate lane rows')
    except (ValueError, KeyError, TypeError):
        row['lanes'] = {}; inconclusive = True
    return row
old, new = side('old', sys.argv[2]), side('new', sys.argv[3])
drift = [key for key in ('version','proof','unsafe','lanes_verdict') if old[key] != new[key]]
drift += ['lanes:' + key for key in sorted(old['lanes'].keys() | new['lanes'].keys())
          if old['lanes'].get(key) != new['lanes'].get(key)]
probe_diffs = []
for source in sorted((root / 'old.probes').glob('*.exit')):
    name = source.stem
    for suffix in ('out','err','exit'):
        filename = name + '.' + suffix
        if (root / 'old.probes' / filename).read_bytes() != (root / 'new.probes' / filename).read_bytes():
            probe_diffs.append(filename); drift.append('probes:' + filename)
verdict = 'INCONCLUSIVE' if inconclusive else 'DRIFT' if drift else 'SAME'
print('--\ndrift: ' + (', '.join(drift) or 'none'))
print('version-drift: ' + verdict)
print(json.dumps(dict(old=old, new=new, drift=drift, probes_diff=probe_diffs, artifacts=str(root), verdict=verdict), separators=(',', ':')))
sys.exit(verdict != 'SAME')
PY
