#!/usr/bin/env bash
# port-doctor: run every gate of a port from its root and print the gate
# table exactly as docs/PORT_STATE.md wants it (paste-ready Markdown), plus
# a JSON summary. Gates: the proof (bend port/PROOF.bend: last line and the
# unsafe count), the lanes (scripts/lanes.sh: interpreter, c-1t, c-Nt, js
# and, with --gpu, the device), the parity board (scripts/parity-board.sh),
# the floor when the original's command is given (scripts/floor.sh), and
# the kill-switch parity when --switch and --probe are given. Nothing is
# fixed; the doctor only reports. A missing input (no goldens, no board) is
# reported as MISSING, never skipped silently.
#
# usage: port-doctor.sh [--root DIR] [--threads N] [--gpu] [--checkout DIR]
#                       [--original <cmd...> --] [--switch VAR=1 --probe "<args>"]
#                       [--main port/main.bend] [--cases goldens/cases.tsv] [--goldens goldens]
#   --root      the port's root (default: cwd) with docs/, goldens/, port/, perf/
#   --original  the original's command (ends at `--`), enables the floor gate
#   --original-json  a JSON string array; preserves an original command's own --
#   --switch    an env assignment selecting the spec twin (e.g. X_SPEC=1)
#   --probe     program args to run with and without the switch (same bytes expected)
# exit: 0 every gate green (floor and switch only if requested), 1 otherwise, 2 usage.
# Last stdout line: {"proof","unsafe","lanes","board","floor","switch","verdict"}.
set -uo pipefail
usage() { sed -n '2,/^set -/p' "$0" | sed '$d' | sed 's/^# \{0,1\}//'; }
[[ "${1:-}" == "--help" || "${1:-}" == "-h" ]] && { usage; exit 0; }
ROOT="$PWD"; THREADS=""; GPU=""; CHECKOUT=""; ORIG=(); SWITCH=""; PROBE=""
MAIN=port/main.bend; CASES=goldens/cases.tsv; GOLD=goldens; ORIGINAL_SET=0
while [[ $# -gt 0 ]]; do
  case "$1" in
    --root|--threads|--checkout|--main|--cases|--goldens|--switch|--probe|--original-json)
      [[ $# -ge 2 && -n "$2" ]] || { echo "error: $1 needs a value" >&2; exit 2; };;
  esac
  case "$1" in
    --root) ROOT="${2:?--root needs DIR}"; shift 2;;
    --threads) [[ ${2:-} =~ ^[1-9][0-9]*$ ]] || { echo 'error: --threads needs a positive integer' >&2; exit 2; }; THREADS="--threads $2"; shift 2;;
    --gpu) GPU="--gpu"; shift;;
    --checkout) CHECKOUT="${2:?--checkout needs DIR}"; shift 2;;
    --main) MAIN="${2:?--main needs FILE}"; shift 2;;
    --cases) CASES="${2:?--cases needs FILE}"; shift 2;;
    --goldens) GOLD="${2:?--goldens needs DIR}"; shift 2;;
    --switch) SWITCH="${2:?--switch needs VAR=VALUE}"; shift 2;;
    --probe) PROBE="${2:?--probe needs ARGS}"; shift 2;;
    --original)
      [[ $ORIGINAL_SET -eq 0 ]] || { echo 'error: original command supplied twice' >&2; exit 2; }; ORIGINAL_SET=1
      shift; while [[ $# -gt 0 && "$1" != "--" ]]; do ORIG+=("$1"); shift; done; [[ ${#ORIG[@]} -gt 0 && "${1:-}" == -- ]] || { echo 'error: --original needs a command terminated by --' >&2; exit 2; }; shift;;
    --original-json)
      [[ $ORIGINAL_SET -eq 0 ]] || { echo 'error: original command supplied twice' >&2; exit 2; }; ORIGINAL_SET=1
      original_args="$(mktemp "${TMPDIR:-/tmp}/doctor-original.XXXXXX")" || exit 2
      python3 - "$2" >"$original_args" <<'PY' || exit 2
import json,sys
try:
    args=json.loads(sys.argv[1])
    if not isinstance(args,list) or not args or any(not isinstance(x,str) or '\0' in x for x in args):
        raise ValueError('expected a nonempty JSON string array without NUL')
    for arg in args: sys.stdout.buffer.write(arg.encode()+b'\0')
except ValueError as exc: sys.exit('error: invalid original command: '+str(exc))
PY
      while IFS= read -r -d '' arg; do ORIG+=("$arg"); done <"$original_args"
      shift 2;;
    *) echo "error: unknown option $1" >&2; usage >&2; exit 2;;
  esac
done
if [[ -n "$SWITCH" || -n "$PROBE" ]]; then
  [[ -n "$SWITCH" && -n "$PROBE" && "$SWITCH" =~ ^[A-Za-z_][A-Za-z0-9_]*= ]] || { echo 'error: --switch VAR=VALUE and --probe ARGS are required together' >&2; exit 2; }
fi
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
THREAD_COUNT="${THREADS#--threads }"
[[ -n "$THREAD_COUNT" ]] || THREAD_COUNT="$(nproc 2>/dev/null || sysctl -n hw.ncpu 2>/dev/null || echo 4)"
[[ "$THREAD_COUNT" =~ ^[1-9][0-9]*$ ]] || { echo 'error: cannot determine a positive thread count' >&2; exit 2; }
THREADS="--threads $THREAD_COUNT"
[[ -z "$CHECKOUT" ]] || CHECKOUT="$(cd "$CHECKOUT" && pwd)" || exit 2
cd "$ROOT" || { echo "error: no such root $ROOT" >&2; exit 2; }
PROOF_DIR="$(dirname "$MAIN")"
if [[ -n "${BEND_CLI:-}" ]]; then read -ra BEND <<<"$BEND_CLI"
elif [[ -n "$CHECKOUT" && -f "$CHECKOUT/bend2/main.ts" ]]; then BEND=(bun "$CHECKOUT/bend2/main.ts"); export BEND_CLI="bun $CHECKOUT/bend2/main.ts"
elif command -v bend >/dev/null 2>&1; then BEND=(bend)
else echo "error: no bend on PATH and no --checkout (or BEND_CLI)" >&2; exit 2; fi
export BEND_NO_TELEMETRY=1
# The shared runner bounds process lifetime and pipe drain after the parent
# exits, including a descendant retaining stdout past an ordinary timeout.
run_to() {
  local seconds="$1" merged=0; shift
  if [[ "${1:-}" == --merge-stderr ]]; then merged=1; shift; fi
  python3 -B - "$HERE" "$seconds" "$merged" "$@" <<'PY'
import sys
sys.path.insert(0,sys.argv[1])
from case_manifest import run
result=run(sys.argv[4:],timeout=float(sys.argv[2]),merge_stderr=sys.argv[3]=='1')
sys.stdout.buffer.write(result['out'])
sys.stderr.buffer.write(result['err'])
sys.exit(result['rc'] if result['rc'] is not None else 125)
PY
}
bad=0; today="$(date -u +%Y-%m-%d)"
row() {
  python3 - "$1" "$2" "$3" "$today" <<'PY'
import sys
def cell(text):
    return text.replace('\\','\\\\').replace('|','\\|').replace('\r',' ').replace('\n',' ')
gate,command,result,date=map(cell,sys.argv[1:])
print(f'| {gate} | `{command}` | {result} | {date} |')
PY
}
j() { python3 -c 'import json,sys; print(json.dumps(sys.argv[1])[1:-1])' "$1"; }
echo "| gate | command | result | date |"
echo "|---|---|---|---|"

# proof
proof="MISSING (no $PROOF_DIR/PROOF.bend)"; unsafe="?"; ann="?"; inst="?"; count_mode="unknown"; bendv="$(run_to 30 "${BEND[@]}" --version 2>/dev/null | tail -1)"; version_rc=$?
[[ $version_rc -eq 0 && -n "$bendv" ]] || bad=1
if [[ -f "$PROOF_DIR/PROOF.bend" ]]; then
  out="$(cd "$PROOF_DIR" && run_to 600 --merge-stderr "${BEND[@]}" PROOF.bend 2>&1 | tail -1)"; proof_rc=$?
  proof="$out"
  if [[ "$out" == "All terms check." ]]; then unsafe=0
  elif [[ "$out" =~ ^All\ terms\ check,\ with\ ([0-9]+)\ unsafe\ annotations?\.$ ]]; then unsafe="${BASH_REMATCH[1]}"
  else bad=1; fi
  [[ $proof_rc -eq 0 ]] || bad=1
  # 2.0.16+: the CLI's number is @unsafe defs + template instances; state the split (VERSION-DRIFT)
  # Count the loaded book, including imports. Text grep counts comments and
  # misses imported definitions, so it cannot establish the trusted split.
  LIST_BEND=("${BEND[@]}"); LIST_ARGS=()
  if [[ "${BEND[0]##*/}" == bend-quiet.sh ]]; then read -ra LIST_BEND <<<"${BEND_REAL_CLI:-bend}"; fi
  [[ -z "$CHECKOUT" ]] || LIST_ARGS+=(--checkout "$CHECKOUT")
  if listing="$(BEND_CLI="${LIST_BEND[*]}" run_to 60 bun "$HERE/list-instances.ts" "$PROOF_DIR/PROOF.bend" "${LIST_ARGS[@]}" 2>/dev/null | tail -1)"; then
    split="$(python3 - "$listing" "$unsafe" "$bendv" "${LIST_BEND[@]}" <<'PY'
import hashlib,json,sys
from pathlib import Path
try:
    x=json.loads(sys.argv[1]); groups=[x['unsafe_defs'],x['instances']]
    if any(not isinstance(g,list) or any(not isinstance(n,str) or not n for n in g) for g in groups):
        raise ValueError('invalid unsafe name lists')
    names=groups[0]+groups[1]
    if len(names)!=len(set(names)): raise ValueError('duplicate or overlapping unsafe names')
    mode=x['count_mode']
    if mode not in ('explicit-only','explicit-and-instances'): raise ValueError('unknown count semantics')
    known_modes={'bend 2.0.13':'explicit-only','bend 2.0.14':'explicit-only',
                 'bend 2.0.15':'explicit-only','bend 2.0.16':'explicit-and-instances'}
    if sys.argv[3] in known_modes and mode!=known_modes[sys.argv[3]]:
        raise ValueError('listing count semantics differ from compiler version')
    expected=len(groups[0])+(len(groups[1]) if mode=='explicit-and-instances' else 0)
    if (type(x['counted']) is not int or x['counted']!=len(names) or
            type(x['compiler_counted']) is not int or x['compiler_counted']!=expected or expected!=int(sys.argv[2])):
        raise ValueError('listing does not reconcile with compiler verdict')
    mains=[Path(a).resolve() for a in sys.argv[4:] if a.endswith('bend2/main.ts')]
    if mains:
        main=mains[-1]; checkout=main.parent.parent
        if (Path(x['checkout']).resolve()!=checkout or
                x['main_sha256']!=hashlib.sha256(main.read_bytes()).hexdigest() or
                x['bend_sha256']!=hashlib.sha256((main.parent/'bend.ts').read_bytes()).hexdigest()):
            raise ValueError('listing used different compiler source')
    print(len(groups[0]),len(groups[1]),mode)
except (KeyError,TypeError,ValueError,OSError) as exc:
    sys.exit('unsafe split unavailable: '+str(exc))
PY
)" || { split=""; bad=1; }
    if [[ -n "$split" ]]; then read -r ann inst count_mode <<<"$split"; fi
  elif [[ "$unsafe" != 0 ]]; then
    bad=1
  fi
  if [[ "$unsafe" == 0 && "$ann" == '?' ]]; then
    ann=0
    case "$bendv" in
      'bend 2.0.16') inst=0; count_mode=explicit-and-instances;;
      'bend 2.0.13'|'bend 2.0.14'|'bend 2.0.15') count_mode=explicit-only;;
      *) bad=1;;  # A future CLI's zero must not invent its count semantics.
    esac
  fi
else bad=1; fi
split_note="unsafe $unsafe = $ann @unsafe + $inst template instances"
[[ "$count_mode" != explicit-only ]] || split_note="unsafe $unsafe = $ann @unsafe; $inst template instances (not counted by this CLI)"
row proofs "bend $PROOF_DIR/PROOF.bend" "$proof ($split_note; ${bendv:-bend ?})"

# lanes
lanes="MISSING (no $CASES or $MAIN)"; lanes_v="MISSING"
if [[ -f "$CASES" && -f "$MAIN" ]]; then
  # shellcheck disable=SC2086  # validated integer and constant flags, intentionally word-split
  lanes="$(bash "$HERE/lanes.sh" "$CASES" "$GOLD" "$MAIN" $THREADS $GPU 2>/dev/null | grep '^{' | tail -1)"; lanes_rc=$?
  lanes_v="$(printf '%s' "$lanes" | python3 -B -c '
import json,sys
sys.path.insert(0,sys.argv[1])
from case_manifest import cases,validate_lanes
validate_lanes(json.load(sys.stdin),int(sys.argv[2]),bool(sys.argv[3]),case_count=len(cases(sys.argv[4])))
print("PASS")
' "$HERE" "$THREAD_COUNT" "$GPU" "$CASES" 2>/dev/null)" || lanes_v=FAIL
  if [[ $lanes_rc -ne 0 ]]; then lanes_v=FAIL; bad=1; fi
  [[ "$lanes_v" == PASS ]] || bad=1
else bad=1; fi
row lanes "$(printf '%s' "scripts/lanes.sh $CASES $GOLD $MAIN $THREADS $GPU" | sed 's/ *$//')" "$lanes"

# board
board="MISSING (no docs/FEATURE_PARITY.md)"; board_v="MISSING"
if [[ -f docs/FEATURE_PARITY.md ]]; then
  board="$(bash "$HERE/parity-board.sh" docs/FEATURE_PARITY.md 2>/dev/null | grep '^rows=' | tail -1)"; board_rc=$?
  board_v="$(printf '%s' "$board" | sed -n 's/.*verdict=\([A-Z]*\).*/\1/p')"
  [[ "$board_v" == FULL || "$board_v" == DEBT ]] || bad=1
  [[ $board_rc -eq 0 ]] || bad=1
else bad=1; fi
row parity "scripts/parity-board.sh docs/FEATURE_PARITY.md" "$board"

# floor (optional)
floor="not run (no --original)"; floor_v="n/a"
if [[ ${#ORIG[@]} -gt 0 ]]; then
  floor="$(bash "$HERE/floor.sh" "$CASES" "$GOLD" --repeat 2 -- "${ORIG[@]}" 2>/dev/null | grep '^{' | tail -1)"; floor_rc=$?
  floor_v="$(printf '%s' "$floor" | python3 -B -c '
import json,sys
sys.path.insert(0,sys.argv[1])
from case_manifest import cases,validate_floor
validate_floor(json.load(sys.stdin),len(cases(sys.argv[2])),repeat=2)
print("STABLE")
' "$HERE" "$CASES" 2>/dev/null)" || floor_v=INCONCLUSIVE
  if [[ $floor_rc -ne 0 ]]; then floor_v=INCONCLUSIVE; bad=1; fi
  [[ "$floor_v" == STABLE ]] || bad=1
  row floor "scripts/floor.sh $CASES $GOLD --repeat 2 -- ${ORIG[*]}" "$floor"
fi

# kill-switch parity (optional)
switch="not run (no --switch/--probe)"; switch_v="n/a"
if [[ -n "$SWITCH" && -n "$PROBE" ]]; then
  TMP="$(mktemp -d "${TMPDIR:-/tmp}/doctor.XXXXXX")"
  if run_to 600 "${BEND[@]}" "$MAIN" -o "$TMP/x" >/dev/null 2>&1; then
    PARGS=()
    python3 - "$PROBE" >"$TMP/args" <<'PY' || exit 2
import json,sys
a=json.loads(sys.argv[1]) if sys.argv[1].lstrip().startswith('[') else sys.argv[1].split()
if not isinstance(a,list) or any(not isinstance(x,str) or '\0' in x for x in a): sys.exit('invalid probe argv')
for s in a: sys.stdout.buffer.write(s.encode()+b'\0')
PY
    while IFS= read -r -d '' arg; do PARGS+=("$arg"); done <"$TMP/args"
    # An inherited spec selector must not make both arms run the spec twin.
    run_to 60 env -u "${SWITCH%%=*}" "$TMP/x" --gpu off -- "${PARGS[@]}" </dev/null >"$TMP/a.out" 2>"$TMP/a.err"; a_rc=$?
    run_to 60 env "$SWITCH" "$TMP/x" --gpu off -- "${PARGS[@]}" </dev/null >"$TMP/b.out" 2>"$TMP/b.err"; b_rc=$?
    if [[ "$a_rc" == "$b_rc" && "$a_rc" -lt 124 ]] && cmp -s "$TMP/a.out" "$TMP/b.out" && cmp -s "$TMP/a.err" "$TMP/b.err"; then switch="identical stdout, stderr and exit with and without $SWITCH on '$PROBE'"; switch_v=PASS
    else switch="DIFFERENT with $SWITCH on '$PROBE'"; switch_v=FAIL; bad=1; fi
  else switch="build failed"; switch_v=FAIL; bad=1; fi
  row kill-switch "$SWITCH <binary> --gpu off -- $PROBE  vs  env -u ${SWITCH%%=*} <binary> --gpu off -- $PROBE  (binary built from $MAIN into a temp dir)" "$switch_v: $switch"
fi

verdict=GREEN; [[ $bad -eq 0 ]] || verdict=RED
echo
echo "doctor: $verdict"
printf '{"proof":"%s","unsafe":"%s","unsafe_annotations":"%s","instances":"%s","unsafe_count_mode":"%s","bend":"%s","lanes":"%s","board":"%s","floor":"%s","switch":"%s","verdict":"%s"}\n' \
  "$(j "$proof")" "$unsafe" "$ann" "$inst" "$count_mode" "$(j "$bendv")" "$lanes_v" "$board_v" "$floor_v" "$switch_v" "$verdict"
[[ $bad -eq 0 ]]
