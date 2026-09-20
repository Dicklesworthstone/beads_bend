#!/usr/bin/env bash
# port: one entry point per phase for a scaffolded Bend 2 port. Reads port.env in
# the port root and dispatches to the harness scripts (./scripts/ beside it, or the
# skill's scripts/ when run from the skill) with the flags the phase needs, so an
# agent types one word per phase instead of re-deriving five argument lists. It
# never changes what a script does; every sub-command prints the wrapped script's
# own output and ends with that script's JSON (or count) line.
#
# port.env (KEY=VALUE lines; quotes optional; # comments):
#   ORIGINAL="python3 legacy/x.py"     the oracle's command (capture, floor, bench, doctor)
#   THREADS=4                          the parallel lane's thread count (default: nproc)
#   SWITCH=X_SPEC=1                    the kill-switch env assignment (doctor)
#   PROBE="simulate 8 100"             program args for the kill-switch probe (doctor)
#   HOT="simulate 2000 500"            the hot input for `bench` (incumbent-bench)
#   PIN="CPython 3.12, 1 thread both"  the incumbent contract text for `bench`
#   MAIN=port/main.bend  CASES=goldens/cases.tsv  GOLDENS=goldens  (defaults shown)
#   QUIET=1                            route BEND_CLI through scripts/bend-quiet.sh (2.0.16
#                                      interpreter verdict line on stderr; see its --help)
# ORIGINAL and HOT accept JSON string arrays for exact argv (including spaces
# and empty arguments), e.g. ORIGINAL='["python3","legacy/file name.py"]'.
# usage: port.sh [--root DIR] <command> [args...]
#   init                 write a port.env skeleton (refuses to overwrite)
#   doctor [--gpu]       port-doctor.sh with THREADS, ORIGINAL, SWITCH and PROBE
#   capture [--repin R | --disc D]   golden-capture.sh with ORIGINAL
#   floor [--repeat K]   floor.sh with ORIGINAL (default K=3)
#   cases                cases-lint.sh
#   lanes [--gpu] [--no-stderr]      lanes.sh with THREADS
#   conform <lane> [--no-stderr]     conform.sh on one lane: interpreter | c-1t | c-Nt | js
#   first <case>         first-divergence.sh for one case on the interpreter lane
#   proof                bend PROOF.bend in the port dir; prints the last line and the unsafe count
#   lint                 port-lint.py on MAIN with the LAWS beside it
#   laws                 law-coverage.sh
#   board                parity-board.sh
#   converge             converge.sh
#   state                state-check.sh (and state-json.py --check when present)
#   claims               claims-lint.sh over docs/*.md perf/*.md README.md
#   bench                incumbent-bench.sh: ORIGINAL HOT vs the built binary --threads 1 -- HOT, with PIN
#   report               proof + lanes + board + converge + claims, one gate line each, then a JSON summary
#   env                  print the resolved configuration
# exit: the wrapped script's exit code; 2 usage / no port.env / unknown command.
set -uo pipefail
if [[ "${1:-}" == "--help" || "${1:-}" == "-h" || $# -eq 0 ]]; then sed -n '2,/^set -/p' "$0" | sed '$d' | sed 's/^# \{0,1\}//'; [[ $# -eq 0 ]] && exit 2; exit 0; fi

ROOT="$PWD"
if [[ "${1:-}" == "--root" ]]; then
  [[ $# -ge 2 ]] || { echo 'port: --root needs a directory' >&2; exit 2; }
  ROOT="$(cd "$2" && pwd)" || exit 2; shift 2
fi
CMD="${1:-}"; shift || true
HERE="$(cd "$(dirname "$0")" && pwd)"
REAL_HERE="$(cd "$(dirname "$(readlink -f "$0" 2>/dev/null || echo "$0")")" && pwd)"
# every harness script is looked up by name: the port's copy, this directory, the
# directory this script really lives in (through a symlink), then $PORT_SKILL_SCRIPTS
# (the skill's scripts/ when a port carries only a partial copy). A dangling symlink
# (a copied example whose relative links broke) is skipped, not executed.
lookup() {
  local n="$1" d
  for d in "$ROOT/scripts" "$HERE" "$REAL_HERE" "${PORT_SKILL_SCRIPTS:-}" "$HERE/../scripts"; do
    [[ -n "$d" && -x "$d/$n" && -f "$d/$n" ]] && { echo "$d/$n"; return 0; }
  done
  echo "port: script $n not found in $ROOT/scripts, $HERE, $REAL_HERE or \$PORT_SKILL_SCRIPTS" >&2; return 1
}
S() { local p; p="$(lookup "$1")" || exit 2; echo "$p"; }

ENVF="$ROOT/port.env"
if [[ "$CMD" == "init" ]]; then
  [[ $# -eq 0 ]] || { echo 'port: init takes no arguments' >&2; exit 2; }
  [[ -e "$ENVF" || -L "$ENVF" ]] && { echo "port: $ENVF exists; not overwriting" >&2; exit 2; }
  printf '%s\n' '# port.env: the port'"'"'s knobs, read by scripts/port.sh (see port.sh --help)' \
    'ORIGINAL="python3 legacy/ORIGINAL.py"' 'THREADS=4' 'SWITCH=X_SPEC=1' 'PROBE="<hot args>"' \
    'HOT="<hot args>"' 'PIN="<original commit, toolchain, flags, threads>"' \
    'MAIN=port/main.bend' 'CASES=goldens/cases.tsv' 'GOLDENS=goldens' 'QUIET=0' >"$ENVF" || exit 2
  echo "port: wrote $ENVF (edit ORIGINAL, THREADS, SWITCH, PROBE, HOT, PIN)"; exit 0
fi
[[ -f "$ENVF" ]] || { echo "port: no port.env in $ROOT (run: port.sh init)" >&2; exit 2; }

# Parse quotes and comments without evaluating shell substitutions.
ORIGINAL=""; THREADS=""; SWITCH=""; PROBE=""; HOT=""; PIN=""; MAIN="port/main.bend"; CASES="goldens/cases.tsv"; GOLDENS="goldens"; QUIET=0
CONFIG="$(mktemp "${TMPDIR:-/tmp}/port-config.XXXXXX")" || exit 2
python3 - "$ENVF" >"$CONFIG" <<'PY' || exit 2
import json, pathlib, shlex, sys
try:
    for number, line in enumerate(pathlib.Path(sys.argv[1]).read_text().splitlines(), 1):
        if not line.strip() or line.lstrip().startswith('#'): continue
        key, separator, value = line.partition('='); key = key.strip(); value = value.strip()
        if not separator: raise ValueError(f'line {number}: expected KEY=VALUE')
        if value.startswith('['):
            parsed, end = json.JSONDecoder().raw_decode(value)
            if value[end:].strip() and not value[end:].lstrip().startswith('#'): raise ValueError(f'line {number}: text after JSON')
            value = json.dumps(parsed)
        else:
            lexer = shlex.shlex(value, posix=True); lexer.whitespace_split = True
            value = ' '.join(lexer)
        if '\0' in key + value: raise ValueError(f'line {number}: NUL is not an argument')
        sys.stdout.buffer.write((key + '\0' + value + '\0').encode())
except (OSError, ValueError) as exc:
    sys.exit(f'port: invalid port.env: {exc}')
PY
while IFS= read -r -d '' key && IFS= read -r -d '' val; do
  case "$key" in
    ORIGINAL) ORIGINAL="$val";; THREADS) THREADS="$val";; SWITCH) SWITCH="$val";; PROBE) PROBE="$val";;
    HOT) HOT="$val";; PIN) PIN="$val";; MAIN) MAIN="$val";; CASES) CASES="$val";; GOLDENS) GOLDENS="$val";; QUIET) QUIET="$val";;
    *) echo "port: port.env: unknown key $key" >&2; exit 2;;
  esac
done <"$CONFIG"
[[ -n "$THREADS" ]] || THREADS="$(nproc 2>/dev/null || sysctl -n hw.ncpu 2>/dev/null || echo 4)"
[[ "$THREADS" =~ ^[1-9][0-9]*$ && "$QUIET" =~ ^[01]$ ]] || { echo 'port: THREADS must be positive and QUIET must be 0 or 1' >&2; exit 2; }
ARGV_HELPER="$(S case_manifest.py)"
parse_args() {
  python3 -B - "$ARGV_HELPER" "$1" <<'PY'
import sys
from pathlib import Path
sys.path.insert(0, str(Path(sys.argv[1]).parent))
from case_manifest import argv
try:
    for item in argv(sys.argv[2]): sys.stdout.buffer.write(item.encode() + b'\0')
except ValueError as exc: sys.exit(f'port: {exc}')
PY
}
parse_args "$ORIGINAL" >"$CONFIG.orig" || exit 2
parse_args "$HOT" >"$CONFIG.hot" || exit 2
ORIG=(); HOTA=()
while IFS= read -r -d '' arg; do ORIG+=("$arg"); done <"$CONFIG.orig"
while IFS= read -r -d '' arg; do HOTA+=("$arg"); done <"$CONFIG.hot"
if [[ -n "${BEND_CLI:-}" ]]; then read -ra BEND <<<"$BEND_CLI"; else BEND=(bend); fi
if [[ "$QUIET" == "1" && "${BEND[0]}" != *bend-quiet.sh ]]; then   # never wrap the wrapper (a nested call would fork forever)
  Q="$(lookup bend-quiet.sh)" || exit 2
  export BEND_REAL_CLI="${BEND_CLI:-bend}"; export BEND_CLI="$Q"; BEND=("$Q")
fi
export BEND_NO_TELEMETRY=1
cd "$ROOT" || exit 2
run_bend() {
  if command -v timeout >/dev/null 2>&1; then timeout --kill-after=2s 600 "${BEND[@]}" "$@"
  elif command -v gtimeout >/dev/null 2>&1; then gtimeout --kill-after=2s 600 "${BEND[@]}" "$@"
  else echo 'port: timeout or gtimeout is needed for bounded compiler gates' >&2; return 125; fi
}
need_orig() { [[ ${#ORIG[@]} -gt 0 ]] || { echo "port: ORIGINAL is not set in port.env" >&2; exit 2; }; }
no_args() { [[ $# -eq 0 ]] || { echo "port: $CMD does not accept these arguments: $*" >&2; exit 2; }; }
gate_line() { "$@" 2>&1 | tail -1; }
proof_gate() { # prints the checker's full output, then a JSON line; returns bend's exit code
  local out rc last n verdict
  out="$(cd "$(dirname "$MAIN")" && run_bend PROOF.bend 2>&1)"; rc=$?
  last="$(printf '%s\n' "$out" | tail -1)"; printf '%s\n' "$out"
  n="$(printf '%s' "$last" | sed -n 's/.*with \([0-9]*\) unsafe.*/\1/p')"; [[ -z "$n" ]] && n=0
  verdict=RED
  [[ $rc -eq 0 && "$last" =~ ^All\ terms\ check(,\ with\ [0-9]+\ unsafe\ annotations?)?\.$ ]] && verdict=GREEN
  python3 - "$last" "$n" "$rc" "$verdict" <<'PY'
import json,sys
print(json.dumps(dict(gate='proof',last=sys.argv[1],unsafe=int(sys.argv[2]),exit=int(sys.argv[3]),verdict=sys.argv[4]),separators=(',',':')))
PY
  [[ "$verdict" == GREEN ]]
}

case "$CMD" in
  env)
    no_args "$@"
    echo "root=$ROOT scripts=$(dirname "$(S lanes.sh)") bend=${BEND[*]} original=${ORIGINAL:-<unset>} threads=$THREADS switch=${SWITCH:-<unset>} probe=${PROBE:-<unset>} hot=${HOT:-<unset>} main=$MAIN cases=$CASES goldens=$GOLDENS quiet=$QUIET"; exit 0;;
  doctor)
    args=(--root "$ROOT" --threads "$THREADS" --main "$MAIN" --cases "$CASES" --goldens "$GOLDENS")
    [[ "${1:-}" == "--gpu" ]] && { args+=(--gpu); shift; }; no_args "$@"
    [[ ${#ORIG[@]} -gt 0 ]] && args+=(--original-json "$(python3 -c 'import json,sys; print(json.dumps(sys.argv[1:]))' "${ORIG[@]}")")
    [[ -n "$SWITCH" || -n "$PROBE" ]] && args+=(--switch "$SWITCH" --probe "$PROBE")
    exec "$(S port-doctor.sh)" "${args[@]}";;
  capture) need_orig; exec "$(S golden-capture.sh)" "$CASES" "$GOLDENS" "$@" -- "${ORIG[@]}";;
  floor) need_orig; k=3; if [[ "${1:-}" == "--repeat" ]]; then [[ $# -ge 2 ]] || exit 2; k="$2"; shift 2; fi; no_args "$@"; exec "$(S floor.sh)" "$CASES" "$GOLDENS" --repeat "$k" -- "${ORIG[@]}";;
  cases) no_args "$@"; exec "$(S cases-lint.sh)" "$CASES";;
  lanes) exec "$(S lanes.sh)" "$CASES" "$GOLDENS" "$MAIN" --threads "$THREADS" "$@";;
  conform)
    lane="${1:-interpreter}"; shift || true
    case "$lane" in
      interpreter) exec "$(S conform.sh)" "$CASES" "$GOLDENS" --lane interpreter "$@" -- "$(S interp-lane.sh)" "${BEND[@]}" "$MAIN" --;;
      c-1t|c-*t)
        n="${lane#c-}"; n="${n%t}"; [[ "$n" =~ ^[1-9][0-9]*$ ]] || { echo 'port: native lane needs a positive thread count' >&2; exit 2; }
        build_dir="$(mktemp -d "${TMPDIR:-/tmp}/port-build.XXXXXX")" || exit 2; bin="$build_dir/port"
        run_bend "$MAIN" -o "$bin" >/dev/null 2>&1 || { echo "port: build of $MAIN failed" >&2; exit 1; }
        exec "$(S conform.sh)" "$CASES" "$GOLDENS" --lane "$lane" "$@" -- "$bin" --threads "$n" --gpu off --;;
      js)
        build_dir="$(mktemp -d "${TMPDIR:-/tmp}/port-build.XXXXXX")" || exit 2; js="$build_dir/port.js"
        run_bend "$MAIN" -o "$js" >/dev/null 2>&1 || { echo "port: JS build of $MAIN failed" >&2; exit 1; }
        exec "$(S conform.sh)" "$CASES" "$GOLDENS" --lane js "$@" -- python3 "$(S js-lane.py)" "$js" --;;
      *) echo "port: conform lane must be interpreter, c-1t, c-<N>t or js" >&2; exit 2;;
    esac;;
  first) [[ $# -eq 1 && -n "$1" ]] || { echo "port: first needs exactly one case name" >&2; exit 2; }
    exec "$(S first-divergence.sh)" "$1" "$CASES" "$GOLDENS" -- "$(S interp-lane.sh)" "${BEND[@]}" "$MAIN" --;;
  proof) no_args "$@"; proof_gate; exit $?;;
  lint) L="$(lookup port-lint.py)" || exit 2; laws="$(dirname "$MAIN")/LAWS.bend"; [[ -f "$laws" ]] && exec "$L" "$MAIN" --laws "$laws" "$@"; exec "$L" "$MAIN" "$@";;
  laws) no_args "$@"; d="$(dirname "$MAIN")"; exec "$(S law-coverage.sh)" "$d/LAWS.bend" "$d/PROOF.bend" docs/FEATURE_PARITY.md "$MAIN";;
  board) no_args "$@"; exec "$(S parity-board.sh)" docs/FEATURE_PARITY.md;;
  converge) exec "$(S converge.sh)" docs/PORT_STATE.md "$@";;
  state)
    no_args "$@"
    "$(S state-check.sh)" docs/PORT_STATE.md; rc=$?
    if J="$(lookup state-json.py 2>/dev/null)"; then "$J" docs/PORT_STATE.md --check | tail -1 || rc=1; fi
    exit $rc;;
  claims) no_args "$@"; files=(); for f in docs/*.md perf/*.md README.md; do [[ -f "$f" ]] && files+=("$f"); done; exec "$(S claims-lint.sh)" "${files[@]}";;
  bench) no_args "$@"; need_orig; [[ -n "$HOT" ]] || { echo "port: HOT is not set in port.env" >&2; exit 2; }
    build_dir="$(mktemp -d "${TMPDIR:-/tmp}/port-build.XXXXXX")" || exit 2; bin="$build_dir/port"
    run_bend "$MAIN" -o "$bin" >/dev/null 2>&1 || { echo "port: build of $MAIN failed" >&2; exit 1; }
    exec "$(S incumbent-bench.sh)" --runs "${RUNS:-6}" --tag "$(printf '%s' "$HOT" | tr ' ' '_')" --pin "$PIN" --original "${ORIG[@]}" "${HOTA[@]}" --port "$bin" --threads 1 --gpu off -- "${HOTA[@]}";;
  report)
    no_args "$@"
    p="$(proof_gate 2>/dev/null | tail -1)"; proof_rc=$?
    l="$(gate_line "$(S lanes.sh)" "$CASES" "$GOLDENS" "$MAIN" --threads "$THREADS")"; lanes_rc=$?
    b="$(gate_line "$(S parity-board.sh)" docs/FEATURE_PARITY.md)"; board_rc=$?
    c="$(gate_line "$(S converge.sh)" docs/PORT_STATE.md)"; converge_rc=$?
    files=(); for f in docs/*.md perf/*.md README.md; do [[ -f "$f" ]] && files+=("$f"); done
    k="$(gate_line "$(S claims-lint.sh)" "${files[@]}")"; claims_rc=$?
    echo "| proofs | \`bend $(dirname "$MAIN")/PROOF.bend\` | $p |"; echo "| lanes | \`scripts/lanes.sh $CASES $GOLDENS $MAIN --threads $THREADS\` | $l |"
    echo "| parity | \`scripts/parity-board.sh docs/FEATURE_PARITY.md\` | $b |"; echo "| converge | \`scripts/converge.sh docs/PORT_STATE.md\` | $c |"; echo "| claims | \`scripts/claims-lint.sh docs/*.md perf/*.md README.md\` | $k |"
    jv() { printf '%s' "$1" | python3 -c 'import json,sys; print(json.load(sys.stdin)["verdict"])' 2>/dev/null; }
    pv="$(jv "$p")"; lv="$(jv "$l")"; bv="$(jv "$b")"; cv="$(jv "$c")"
    lv="$(python3 -B - "$ARGV_HELPER" "$l" "$THREADS" "$CASES" <<'PY'
import json,sys
from pathlib import Path
sys.path.insert(0,str(Path(sys.argv[1]).parent))
from case_manifest import cases,validate_lanes
try:
    validate_lanes(json.loads(sys.argv[2]),int(sys.argv[3]),case_count=len(cases(sys.argv[4])))
    print('PASS')
except (ValueError,OSError,TypeError): print('FAIL')
PY
)"
    all=GREEN; [[ "$pv" == GREEN && "$lv" == PASS && ( "$bv" == FULL || "$bv" == DEBT ) && "$cv" == CONVERGED && $claims_rc -eq 0 && $proof_rc -eq 0 && $lanes_rc -eq 0 && $board_rc -eq 0 && $converge_rc -eq 0 ]] || all=RED
    python3 - "$pv" "$lv" "$bv" "$cv" "$k" "$all" <<'PY'
import json,sys
print(json.dumps(dict(zip(('proof','lanes','board','converge','claims','verdict'),sys.argv[1:])),separators=(',',':')))
PY
    [[ "$all" == GREEN ]];;
  *) echo "port: unknown command '$CMD' (see --help)" >&2; exit 2;;
esac
