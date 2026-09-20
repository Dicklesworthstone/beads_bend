#!/usr/bin/env bash
# lanes: run the conformance harness on every executor lane the machine has
# and require the same verdict on all of them. The lanes: the interpreter
# (bend file.bend), the native binary at 1 thread and at N threads, the
# JavaScript build under bun, and the device (--gpu on) when the program
# has a bang and a device exists. A lane that cannot be built is reported
# as MISSING, not skipped silently; the overall verdict is PASS only when
# every requested lane passed; a stated reason does not make MISSING pass.
#
# usage: lanes.sh <cases.tsv> <goldens-dir> <main.bend> [--threads N] [--gpu] [--no-stderr] [--checkout DIR]
#          [--timeout S] [--interpreter-timeout S]
#   --gpu      also run the device lane (--gpu on): only meaningful with a bang and a device
#   --threads  the parallel lane's thread count (default: the CPU count)
#   --timeout  compiled-case invocation deadline in seconds (default: 5)
#   --interpreter-timeout  interpreter invocation deadline, including the
#              diagnostic preflight, checking and execution (default: 60)
# Both case budgets must be finite and positive. Builds keep a 600s deadline.
# exit: 0 all lanes pass, 1 any lane fails or is missing, 2 usage.
# Last stdout line includes lanes, stderr_compared, timeouts_seconds and verdict.
set -uo pipefail
usage() { sed -n '2,/^set -/p' "$0" | sed '$d' | sed 's/^# \{0,1\}//'; }
[[ "${1:-}" == "--help" || "${1:-}" == "-h" ]] && { usage; exit 0; }
CASES="${1:-}"; GOLD="${2:-}"; MAIN="${3:-}"; shift 3 2>/dev/null || { usage >&2; exit 2; }
THREADS=""; GPU=0; NOERR=""; CHECKOUT=""; CASE_TIMEOUT=5; INTERPRETER_TIMEOUT=60
while [[ $# -gt 0 ]]; do
  case "$1" in --threads|--checkout|--timeout|--interpreter-timeout) [[ $# -ge 2 && -n "$2" ]] || { echo "error: $1 needs a value" >&2; exit 2; };; esac
  case "$1" in
    --threads) THREADS="${2:?--threads needs N}"; shift 2;;
    --gpu) GPU=1; shift;;
    --no-stderr) NOERR="--no-stderr"; shift;;
    --checkout) CHECKOUT="${2:?--checkout needs DIR}"; shift 2;;
    --timeout) CASE_TIMEOUT="$2"; shift 2;;
    --interpreter-timeout) INTERPRETER_TIMEOUT="$2"; shift 2;;
    *) echo "error: unknown option $1" >&2; exit 2;;
  esac
done
[[ -f "$CASES" && -d "$GOLD" && -f "$MAIN" ]] || { usage >&2; exit 2; }
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SETTINGS="$(python3 -B - "$HERE" "$CASES" "$CASE_TIMEOUT" "$INTERPRETER_TIMEOUT" <<'PY'
import argparse,sys
sys.path.insert(0,sys.argv[1])
from case_manifest import cases,positive
try: print(len(cases(sys.argv[2])),positive(sys.argv[3]),positive(sys.argv[4]))
except (OSError,ValueError,argparse.ArgumentTypeError) as exc: sys.exit('error: '+str(exc))
PY
)" || exit 2
read -r CASE_COUNT CASE_TIMEOUT INTERPRETER_TIMEOUT <<<"$SETTINGS"
if [[ -n "${BEND_CLI:-}" ]]; then read -ra BEND <<<"$BEND_CLI"
elif [[ -n "$CHECKOUT" && -f "$CHECKOUT/bend2/main.ts" ]]; then BEND=(bun "$CHECKOUT/bend2/main.ts")
elif command -v bend >/dev/null 2>&1; then BEND=(bend)
else echo "error: no bend on PATH and no --checkout given (or set BEND_CLI)" >&2; exit 2; fi
echo "using: ${BEND[*]}" >&2
echo "case budgets: interpreter=${INTERPRETER_TIMEOUT}s compiled=${CASE_TIMEOUT}s; build budget=600s" >&2
export BEND_NO_TELEMETRY=1
[[ -z "$THREADS" ]] && THREADS="$(nproc 2>/dev/null || sysctl -n hw.ncpu 2>/dev/null || echo 4)"
[[ "$THREADS" =~ ^[1-9][0-9]*$ ]] || { echo 'error: threads must be positive' >&2; exit 2; }
TMP="$(mktemp -d "${TMPDIR:-/tmp}/lanes.XXXXXX")"
BIN="$TMP/port"
run_build() {
  if command -v timeout >/dev/null 2>&1; then timeout --kill-after=2s 600 "$@"
  elif command -v gtimeout >/dev/null 2>&1; then gtimeout --kill-after=2s 600 "$@"
  else echo 'error: timeout or gtimeout is required for bounded builds' >&2; return 125; fi
}
rows=""; bad=0
run_lane() {  # $1 lane name, rest: the port command
  local lane="$1"; shift
  local budget="$CASE_TIMEOUT"
  [[ "$lane" != interpreter ]] || budget="$INTERPRETER_TIMEOUT"
  # LANE_WRAP (this port's addition; unset = the stock behaviour): a wrapper
  # run in front of every lane command as `<wrap…> <lane command…> :: <case
  # args…>`. scripts/ws-run.sh gives the port the same sandboxed workspace
  # (fixed path, fixture, pinned instant) the oracle was captured in.
  local -a cmd=("$@")
  if [[ -n "${LANE_WRAP:-}" ]]; then local -a wrap; read -ra wrap <<<"$LANE_WRAP"; cmd=("${wrap[@]}" "$@" ::); fi
  local out rc; out="$("$HERE/conform.sh" "$CASES" "$GOLD" --lane "$lane" --timeout "$budget" $NOERR -- "${cmd[@]}" 2>&1)"; rc=$?
  local json; json="$(printf '%s\n' "$out" | grep '^{' | tail -1)"
  local v p f parsed
  parsed="$(printf '%s' "$json" | python3 -B -c '
import json,sys
sys.path.insert(0,sys.argv[4])
from case_manifest import cases
def require(ok):
    if not ok: raise ValueError("inconsistent conformance result")
x=json.load(sys.stdin)
require(x["verdict"] in ("PASS","FAIL","INCONCLUSIVE"))
require(all(type(x[k]) is int and x[k]>=0 for k in ("passed","failed","inconclusive")))
require(x["lane"]==sys.argv[1] and x["stderr_compared"] is (sys.argv[2]==""))
rows=x["cases"]
require(isinstance(rows,list) and rows)
require(len(rows)==int(sys.argv[3]))
require(len({r["name"] for r in rows})==len(rows))
require({r["name"] for r in rows}=={name for name,_,_ in cases(sys.argv[5])})
require(all(r["status"] in ("PASS","FAIL","INCONCLUSIVE") and r["pass"] is (r["status"]=="PASS") for r in rows))
require(all(r["status"]!="PASS" or (r.get("stdout")=="ok" and r.get("exit")=="ok" and
    r.get("stderr")==("ok" if sys.argv[2]=="" else "not-compared")) for r in rows))
require(all(x[k]==sum(r["status"]==v for r in rows) for k,v in (("passed","PASS"),("failed","FAIL"),("inconclusive","INCONCLUSIVE"))))
require(x["verdict"]==("FAIL" if x["failed"] else "INCONCLUSIVE" if x["inconclusive"] else "PASS"))
print(x["verdict"],x["passed"],x["failed"])
' "$lane" "$NOERR" "$CASE_COUNT" "$HERE" "$CASES" 2>/dev/null)" || parsed='ERROR 0 0'
  read -r v p f <<<"$parsed"
  [[ $rc -eq 0 || "$v" != PASS ]] || v=ERROR
  printf '%-12s %s (passed=%s failed=%s)\n' "$lane" "${v:-ERROR}" "${p:-?}" "${f:-?}"
  [[ "$v" == "PASS" && $rc -eq 0 ]] || { bad=1; printf '%s\n' "$out" | grep '^FAIL' | head -5 | sed 's/^/    /'; }
  rows+="{\"lane\":\"$lane\",\"verdict\":\"${v:-ERROR}\",\"passed\":${p:-0},\"failed\":${f:-0}},"
}
missing() { printf '%-12s MISSING (%s)\n' "$1" "$2"; rows+="{\"lane\":\"$1\",\"verdict\":\"MISSING\",\"passed\":0,\"failed\":0},"; bad=1; }

# the interpreter lane runs through interp-lane.sh: the CLI prints "All terms
# check, with N unsafe annotations." on stderr BEFORE main when N > 0 (2.0.16
# counts template instances); that line is the checker's, not the port's.
# Open fd3 inside the command conform launches: its subprocess closes inherited
# descriptors. Positional arguments preserve literal paths and program argv.
run_lane interpreter bash -c 'exec 3>> "$1" || exit 125; shift; exec "$@"' \
  bend-interpreter "$TMP/interp.note" "$HERE/interp-lane.sh" "${BEND[@]}" "$MAIN" --
if [[ -s "$TMP/interp.note" ]]; then echo "interpreter note: $(head -1 "$TMP/interp.note") (the CLI's pre-run line, removed from stderr before comparison; VERSION-DRIFT)"; fi
if run_build "${BEND[@]}" "$MAIN" -o "$BIN" >"$TMP/build.log" 2>&1; then
  run_lane "c-1t" "$BIN" --threads 1 --gpu off --
  [[ "$THREADS" == 1 ]] || run_lane "c-${THREADS}t" "$BIN" --threads "$THREADS" --gpu off --
  if [[ $GPU -eq 1 ]]; then
    # probe first: with a bang and no device the binary refuses `--gpu on`
    # (a MISSING lane with its reason, not sixteen FAILs); with no bang the
    # flag is a silent no-op and the "gpu lane" would be the CPU lane (VOID)
    python3 -B - "$BIN" "$TMP/gpu.probe" "$HERE" <<'PY'
import pathlib,sys
sys.path.insert(0,sys.argv[3])
from case_manifest import run
p=run([sys.argv[1],'--gpu','on','--'],timeout=10)
pathlib.Path(sys.argv[2]).write_bytes(('gpu probe infrastructure failure: '+p['problem']+'\n').encode() if p['problem'] else p['err'])
PY
    if grep -q 'found no GPU device' "$TMP/gpu.probe"; then
      missing gpu "no device: $(head -1 "$TMP/gpu.probe" | head -c 100)"
    elif grep -q '^gpu probe infrastructure failure:' "$TMP/gpu.probe"; then
      missing gpu "$(head -1 "$TMP/gpu.probe")"
    elif ! run_build "${BEND[@]}" "$MAIN" -o "$TMP/probe.c" >/dev/null 2>&1; then
      missing gpu "C emission failed during the device availability check"
    elif ! grep -q '^#define BANGS *[1-9]' "$TMP/probe.c"; then
      missing gpu "the program has no bang: --gpu on is a no-op (VOID as a device lane)"
    else
      run_lane gpu "$BIN" --gpu on --
    fi
  fi
else
  missing c-1t "native build failed: $(head -c 120 "$TMP/build.log" | tr '\n' ' ')"
  [[ "$THREADS" == 1 ]] || missing "c-${THREADS}t" "native build failed"
  [[ $GPU -eq 0 ]] || missing gpu "native build failed"
fi
if run_build "${BEND[@]}" "$MAIN" -o "$BIN.js" >"$TMP/buildjs.log" 2>&1 && command -v bun >/dev/null 2>&1; then
  run_lane js python3 "$HERE/js-lane.py" "$BIN.js" --
else
  missing js "JS build failed or bun missing"
fi
verdict=PASS; [[ $bad -eq 0 ]] || verdict=FAIL
echo "--"
echo "all lanes: $verdict"
stderr_compared=true; [[ -z "$NOERR" ]] || stderr_compared=false
echo "{\"lanes\":[${rows%,}],\"stderr_compared\":$stderr_compared,\"timeouts_seconds\":{\"interpreter\":$INTERPRETER_TIMEOUT,\"compiled\":$CASE_TIMEOUT,\"build\":600},\"verdict\":\"$verdict\"}"
[[ $bad -eq 0 ]]
