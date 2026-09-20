#!/usr/bin/env bash
# evidence-bundle: collect the artifacts a PERF-LEDGER row's `evidence` cell
# points at into perf/evidence/<EXP-id>/ (SHIP-AND-CERTIFY "The evidence
# bundle"; templates in assets/templates/evidence-pack/). Fresh, from the
# current tree: bend --version, the git sha, the PROOF verdict line (run), the
# lanes JSON (scripts/lanes.sh, run), the emitted C as x.c with its
# `#define BANGS` line, a keep audit (bend2-mega-skill keep-audit.sh when it
# is installed beside this skill, else a coarse count of term_keep / term_peek
# / term_take in the C), the card (the EXP-<id> block of perf/EXPERIMENTS.md),
# every ledger line naming the id, and the capture JSON files given with
# --bench / --incumbent (copied, never re-run: a capture is made by its own
# script under its cv gate). Writes rerun.sh and rollback.md from the
# templates with the sha, threads, args and switch substituted, and
# MANIFEST.txt with sha256 of every file. Refuses to overwrite an existing
# bundle (evidence is append-only: name a new directory with --dir).
#
# usage: evidence-bundle.sh EXP-<id> [--dir perf/evidence/EXP-<id>] [--threads N] [--args "<hot args>"]
#          [--switch VAR=1] [--bench FILE.json] [--incumbent FILE.json] [--timeout S]
# --timeout bounds each gate (default 600 seconds; version lookup at most 30).
# exit: 0 bundle written and the gates it ran are green, 1 bundle written with a red gate
#       (the bundle records what is), 2 usage, build failure or the directory exists.
# Last stdout line: {"schema":"p2b.evidence-bundle.v1","sha","bend","host","id","dir","files":N,"proof","lanes","verdict":"GREEN|RED"}
set -uo pipefail
export PYTHONDONTWRITEBYTECODE=1
usage() { sed -n '2,/^set -/p' "$0" | sed '$d' | sed 's/^# \{0,1\}//'; }
[[ "${1:-}" == "--help" || "${1:-}" == "-h" || $# -eq 0 ]] && { usage; [[ $# -eq 0 ]] && exit 2; exit 0; }
ID="${1:-}"; shift
[[ "$ID" =~ ^EXP-[A-Za-z0-9_.-]+$ ]] || { echo "error: the first argument is the card id, EXP-<id>" >&2; usage >&2; exit 2; }
DIR="perf/evidence/$ID"; THREADS=""; ARGS=""; SWITCH=""; BENCH=""; INC=""; LIMIT=600
while [[ $# -gt 0 ]]; do
  case "$1" in
    --dir|--threads|--switch|--bench|--incumbent|--timeout)
      [[ $# -ge 2 && -n "$2" ]] || { echo "error: $1 needs a value" >&2; exit 2; };;
  esac
  case "$1" in
    --dir) DIR="${2:?--dir needs DIR}"; shift 2;;
    --threads) THREADS="${2:?--threads needs N}"; shift 2;;
    --args) [[ $# -ge 2 ]] || exit 2; ARGS="$2"; shift 2;;
    --switch) SWITCH="${2:?--switch needs VAR=VALUE}"; shift 2;;
    --bench) BENCH="${2:?--bench needs FILE}"; shift 2;;
    --incumbent) INC="${2:?--incumbent needs FILE}"; shift 2;;
    --timeout) LIMIT="$2"; shift 2;;
    *) echo "error: unknown option $1" >&2; usage >&2; exit 2;;
  esac
done
[[ -z "$SWITCH" || "$SWITCH" =~ ^[A-Za-z_][A-Za-z0-9_]*= ]] || { echo 'error: --switch needs VAR=VALUE' >&2; exit 2; }
[[ -z "$SWITCH" || -n "$ARGS" ]] || ARGS='[]'
python3 - "$ARGS" <<'PY' || exit 2
import json,sys
try:
    value=json.loads(sys.argv[1]) if sys.argv[1].lstrip().startswith('[') else sys.argv[1].split()
    if not isinstance(value,list) or any(not isinstance(x,str) or '\0' in x for x in value): raise ValueError('expected a string array without NUL')
except ValueError as exc: sys.exit('error: invalid --args: '+str(exc))
PY
[[ -f port/main.bend && -f port/PROOF.bend && -d perf ]] || { echo "error: run from the port root (port/, perf/)" >&2; exit 2; }
[[ -e "$DIR" || -L "$DIR" ]] && { echo "error: $DIR exists; evidence is append-only, name a new --dir" >&2; exit 2; }
python3 -c 'import math,sys; n=float(sys.argv[1]); sys.exit(not math.isfinite(n) or n<=0)' "$LIMIT" || { echo 'error: timeout must be finite and positive' >&2; exit 2; }
python3 - "$DIR" <<'PY' || exit 2
from pathlib import Path
import sys
target=Path(sys.argv[1]).resolve()
if any(target == Path(base).resolve() or Path(base).resolve() in target.parents for base in ('port','scripts','docs','goldens')):
    sys.exit('error: bundle directory must be outside the captured source directories')
PY
BEND=()
while IFS= read -r -d '' word; do BEND+=("$word"); done < <(python3 -c 'import pathlib,shlex,shutil,sys; a=shlex.split(sys.argv[1]); a[0]=shutil.which(a[0]) or a[0]; [sys.stdout.buffer.write((str(pathlib.Path(x).resolve()) if pathlib.Path(x).is_file() else x).encode()+b"\0") for x in a]' "${BEND_CLI:-bend}")
[[ ${#BEND[@]} -gt 0 ]] || { echo 'error: invalid/empty Bend command' >&2; exit 2; }
export BEND_NO_TELEMETRY=1
[[ -z "$THREADS" ]] && THREADS="$(nproc 2>/dev/null || sysctl -n hw.ncpu 2>/dev/null || echo 4)"
[[ "$THREADS" =~ ^[1-9][0-9]*$ ]] || { echo 'error: threads must be positive' >&2; exit 2; }
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TPL="$HERE/../assets/templates/evidence-pack"
MEGA="${MEGA_SKILL_DIR:-$HERE/../../bend2-mega-skill}"
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
sha="$(git rev-parse HEAD 2>/dev/null || echo none)"; bendv="$(run_to 30 "${BEND[@]}" --version 2>/dev/null | tail -1)"; version_rc=$?; host="$(uname -s -m 2>/dev/null | tr ' ' '-')"
today="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
mkdir -p "$DIR" || exit 2
bad=0
[[ $version_rc -eq 0 && -n "$bendv" ]] || bad=1
[[ "$sha" != none ]] || { echo 'no Git commit: generated replay cannot establish its checkout' >&2; bad=1; }
# Record the input file set before the gates. Directory symlinks and special
# files are refused: silently omitting them would make replay verification false.
snapshot() {
  python3 - "$1" "$HERE" <<'PY'
import hashlib,json,pathlib,sys
sys.path.insert(0,sys.argv[2])
from case_manifest import regular_bytes
rows={}
for base in ('port','scripts','docs','goldens'):
    root=pathlib.Path(base)
    if not root.is_dir() or root.is_symlink(): sys.exit('snapshot requires a real directory: '+base)
    for p in sorted(root.rglob('*')):
        if p.is_symlink() and p.is_dir(): sys.exit('snapshot refuses directory symlink: '+str(p))
        if p.is_dir(): continue
        if not p.is_file(): sys.exit('snapshot refuses missing/special file: '+str(p))
        rows[str(p)]={'sha256':hashlib.sha256(regular_bytes(p)).hexdigest(),'link':str(p.readlink()) if p.is_symlink() else None}
pathlib.Path(sys.argv[1]).write_text(json.dumps(rows,indent=2)+'\n')
PY
}
snapshot "$DIR/source-hashes.json" || exit 2
run_to 600 bash "$HERE/pin-check.sh" docs/PIN.toml >"$DIR/pin-check.txt" 2>&1; pin_rc=$?
pin_v="$(tail -1 "$DIR/pin-check.txt" | python3 -c 'import json,sys; print(json.load(sys.stdin)["verdict"])' 2>/dev/null)" || pin_v=ERROR
[[ $pin_rc -eq 0 && "$pin_v" == GREEN ]] || { echo "pin-check: ${pin_v:-ERROR}" >&2; bad=1; }
# proof
proof="$(cd port && run_to 600 "${BEND[@]}" PROOF.bend 2>&1 | tail -1)"; proof_rc=$?
printf '%s\n%s\n' "$proof" "$bendv" >"$DIR/PROOF.txt"
[[ $proof_rc -eq 0 && "$proof" =~ ^All\ terms\ check(,\ with\ [0-9]+\ unsafe\ annotations?)?\.$ ]] || bad=1
echo "proof:   $proof ($bendv)"
# lanes
lanes="MISSING (no goldens/cases.tsv)"; lanes_v="MISSING"
if [[ -f goldens/cases.tsv && -d goldens ]]; then
  run_to 600 bash "$HERE/lanes.sh" goldens/cases.tsv goldens port/main.bend --threads "$THREADS" >"$DIR/lanes.txt" 2>&1
  lanes_rc=$?
  lanes="$(grep '^{' "$DIR/lanes.txt" | tail -1)"; printf '%s\n' "$lanes" >"$DIR/lanes.json"
  lanes_v="$(printf '%s' "$lanes" | PYTHONPATH="$HERE${PYTHONPATH:+:$PYTHONPATH}" python3 -c 'import json,sys; from case_manifest import cases,validate_lanes; x=json.load(sys.stdin); validate_lanes(x,int(sys.argv[1]),case_count=len(cases("goldens/cases.tsv"))); print(x["verdict"])' "$THREADS" 2>/dev/null)" || lanes_v=ERROR
  [[ $lanes_rc -eq 0 ]] || lanes_v=FAIL
fi
[[ "$lanes_v" == PASS ]] || bad=1
echo "lanes:   $lanes_v (threads $THREADS)"
# the emitted C and the keep audit
if run_to 600 "${BEND[@]}" port/main.bend -o "$DIR/x.c" >"$DIR/build.log" 2>&1 && [[ -s "$DIR/x.c" ]]; then
  bangs="$(grep -m1 '^#define BANGS' "$DIR/x.c" || echo '#define BANGS (absent)')"
  if [[ -x "$MEGA/scripts/keep-audit.sh" ]]; then
    run_to 600 bash "$MEGA/scripts/keep-audit.sh" port/main.bend >"$DIR/keep-audit.txt" 2>&1 || bad=1
    echo "keep:    bend2-mega-skill keep-audit.sh → $DIR/keep-audit.txt"
  else
    { echo "coarse keep audit (bend2-mega-skill keep-audit.sh not installed): counts over $DIR/x.c"
      for w in term_keep term_peek term_take term_seal term_free; do printf '%-10s %s\n' "$w" "$(grep -c "$w" "$DIR/x.c" || true)"; done; } >"$DIR/keep-audit.txt"
    echo "keep:    coarse counts → $DIR/keep-audit.txt (install bend2-mega-skill for per-def figures)"
  fi
  echo "C:       $DIR/x.c ($bangs)"
else
  echo "C:       build failed ($(head -c 120 "$DIR/build.log"))"; bad=1
fi
# the card and the ledger lines
if [[ -f perf/EXPERIMENTS.md ]]; then
  python3 - "$ID" perf/EXPERIMENTS.md >"$DIR/card.md" <<'PY'
import pathlib,re,sys
active=False
for line in pathlib.Path(sys.argv[2]).read_text().splitlines():
    if re.match(r'^#{1,6}\s',line):
        ids=re.findall(r'(?<![A-Za-z0-9_.-])EXP-[A-Za-z0-9_.-]+',line)
        if ids: active=sys.argv[1] in ids
    if active: print(line)
PY
  [[ -s "$DIR/card.md" ]] || echo "(no block naming $ID in perf/EXPERIMENTS.md: write the card before the lever)" >"$DIR/card.md"
else
  echo "(missing perf/EXPERIMENTS.md: no card captured for $ID)" >"$DIR/card.md"
fi
python3 - "$ID" >"$DIR/ledger-lines.txt" <<'PY'
import pathlib,re,sys
pattern=re.compile(r'(?<![A-Za-z0-9_.-])'+re.escape(sys.argv[1])+r'(?![A-Za-z0-9_.-])')
found=False
for filename in ('perf/PERF-LEDGER.md','perf/NEGATIVE-EVIDENCE.md','docs/PORT_STATE.md'):
    path=pathlib.Path(filename)
    if not path.is_file(): continue
    for number,line in enumerate(path.read_text().splitlines(),1):
        if pattern.search(line): print(f'{filename}:{number}:{line}'); found=True
if not found: print('(no ledger line names '+sys.argv[1]+' yet)')
PY
capture_json() {
  local src="$1" dst="$2"
  [[ -z "$src" ]] && return 0
  if [[ ! -f "$src" ]]; then echo "missing supplied capture: $src" >&2; bad=1; return; fi
  cp "$src" "$dst" || { bad=1; return; }
  python3 - "$dst" <<'PY' || bad=1
import json,math,sys
try:
    def finite(value): raise ValueError('nonfinite JSON value '+value)
    def real(value):
        result=float(value)
        if not math.isfinite(result): raise ValueError('nonfinite JSON number '+value)
        return result
    def unique(pairs):
        result={}
        for key,value in pairs:
            if key in result: raise ValueError('duplicate JSON key '+key)
            result[key]=value
        return result
    with open(sys.argv[1]) as stream:
        x=json.load(stream,parse_constant=finite,parse_float=real,object_pairs_hook=unique)
    if not isinstance(x,dict): raise ValueError('capture must be an object')
    v=x.get('verdict')
    if v not in ('MEASURED','PASS','OK'): raise ValueError(f'capture verdict {v!r} is not accepted measurement evidence')
except (OSError,ValueError) as e:
    print(f'invalid measurement capture: {e}',file=sys.stderr); sys.exit(1)
PY
}
capture_json "$BENCH" "$DIR/bench-speedup.json"
capture_json "$INC" "$DIR/incumbent-bench.json"
# HEAD alone does not identify an agent's working tree. Preserve the actual
# port, harness, spec and golden bytes, plus the tracked patch and full hashes.
if snapshot "$DIR/source-hashes.after.json"; then
  cmp -s "$DIR/source-hashes.json" "$DIR/source-hashes.after.json" || { echo 'source changed during evidence gates' >&2; bad=1; }
  if tar -chf "$DIR/source.tar" port scripts docs goldens; then
    python3 - "$DIR/source-hashes.json" "$DIR/source.tar" <<'PY' || bad=1
import hashlib,json,sys,tarfile
expected=json.load(open(sys.argv[1])); actual={}
with tarfile.open(sys.argv[2]) as archive:
    for member in archive:
        if member.isdir(): continue
        if not (member.isfile() or member.islnk()): sys.exit('source archive contains a nonregular member: '+member.name)
        with archive.extractfile(member) as stream:
            actual[member.name]=hashlib.sha256(stream.read()).hexdigest()
if actual != {name: row['sha256'] for name,row in expected.items()}:
    sys.exit('source archive differs from the bytes recorded before gates')
PY
  else bad=1; fi
else bad=1; fi
git diff --binary HEAD -- port scripts docs goldens >"$DIR/source.patch" 2>/dev/null || true
# rerun.sh and rollback.md from the templates (inline fallback when the port carries only scripts/)
sub() { python3 -c '
import re,shlex,sys
names=("sha","threads","hot args","EXP-id","X_SPEC","bend version","date")
values=dict(zip(names,sys.argv[1:]))
for key,source in (("sha_sh","sha"),("threads_sh","threads"),("args_sh","hot args"),("switch_sh","X_SPEC")):
    values[key]=shlex.quote(values[source])
pattern = r"\x27<([a-z]+_sh)>\x27|<([^<>]+)>"
print(re.sub(pattern,lambda m:values.get(m[1] or m[2],m[0]),sys.stdin.read()),end="")
' "$sha" "$THREADS" "$ARGS" "$ID" "$SWITCH" "$bendv" "$today"; }
if [[ -d "$TPL" ]]; then
  for f in rerun.sh rollback.md README.md; do [[ -f "$TPL/$f" ]] && sub <"$TPL/$f" >"$DIR/$f"; done
else
  sub >"$DIR/rerun.sh" <<'SH'
#!/usr/bin/env bash
set -euo pipefail
export PYTHONDONTWRITEBYTECODE=1
SHA='<sha_sh>'; N='<threads_sh>'; ARGS='<args_sh>'; SWITCH='<switch_sh>'
LIMIT="${1:-600}"
python3 -c 'import math,sys; n=float(sys.argv[1]); sys.exit(not math.isfinite(n) or n<=0)' "$LIMIT"
HERE="$(cd "$(dirname "$0")" && pwd)"
[[ "$(git rev-parse HEAD 2>/dev/null)" == "$SHA" ]] || exit 2
verify_snapshot() {
  python3 - "$HERE/source-hashes.json" <<'PY'
import hashlib,json,os,pathlib,re,stat,sys
def read(path):
    fd=os.open(path,os.O_RDONLY|os.O_NONBLOCK)
    try:
        if not stat.S_ISREG(os.fstat(fd).st_mode): raise ValueError('not a regular file: '+str(path))
        with os.fdopen(fd,'rb',closefd=False) as stream: return stream.read()
    finally: os.close(fd)
bundle=pathlib.Path(sys.argv[1]).parent
entries=re.findall(r'^  ([0-9a-f]{64})  ([A-Za-z0-9_.-]+)$',read(bundle/'MANIFEST.txt').decode(),re.M)
names=[name for _,name in entries]
if len(names)!=len(set(names)) or set(names)!={p.name for p in bundle.iterdir() if p.name!='MANIFEST.txt'}:
    sys.exit('bundle manifest file set differs')
for digest,name in entries:
    if hashlib.sha256(read(bundle/name)).hexdigest()!=digest: sys.exit('bundle artifact hash differs: '+name)
rows=json.loads(read(sys.argv[1]))
current={}
for base in ('port','scripts','docs','goldens'):
    root=pathlib.Path(base)
    if not root.is_dir() or root.is_symlink(): sys.exit('source directory differs: '+base)
    for p in sorted(root.rglob('*')):
        if p.is_symlink() and p.is_dir(): sys.exit('source directory symlink is not captured: '+str(p))
        if p.is_dir(): continue
        if not p.is_file(): sys.exit('source missing/special file: '+str(p))
        current[str(p)]={'sha256':hashlib.sha256(read(p)).hexdigest(),'link':str(p.readlink()) if p.is_symlink() else None}
def matches(name):
    old, new = rows.get(name), current.get(name)
    if old is None or new is None: return False
    return old['sha256']==new['sha256'] and (old['link']==new['link'] or new['link'] is None)
bad=[n for n in rows.keys() | current.keys() if not matches(n)]
if bad: sys.exit('source differs from captured bytes: '+', '.join(bad))
PY
}
verify_snapshot
SCRIPTS="$PWD/scripts"
run_to() {
  python3 - "$SCRIPTS" "$LIMIT" "$@" <<'PY'
import sys
sys.path.insert(0,sys.argv[1])
from case_manifest import run
r=run(sys.argv[3:],timeout=float(sys.argv[2]),merge_stderr=True)
sys.stdout.buffer.write(r['out'])
sys.exit(r['rc'] if r['rc'] is not None else 125)
PY
}
pin="$(run_to bash ./scripts/pin-check.sh docs/PIN.toml | tail -1)"
printf '%s' "$pin" | python3 -c 'import json,sys; sys.exit(json.load(sys.stdin).get("verdict")!="GREEN")'
BEND=()
while IFS= read -r -d '' word; do BEND+=("$word"); done < <(python3 -c 'import pathlib,shlex,shutil,sys; a=shlex.split(sys.argv[1]); a[0]=shutil.which(a[0]) or a[0]; [sys.stdout.buffer.write((str(pathlib.Path(x).resolve()) if pathlib.Path(x).is_file() else x).encode()+b"\0") for x in a]' "${BEND_CLI:-bend}")
[[ ${#BEND[@]} -gt 0 ]] || exit 2
export BEND_NO_TELEMETRY=1
proof="$(cd port && run_to "${BEND[@]}" PROOF.bend 2>&1 | tail -1)"
printf '%s\n' "$proof"
[[ "$proof" =~ ^All\ terms\ check(,\ with\ [0-9]+\ unsafe\ annotations?)?\.$ ]] || exit 1
version="$(run_to "${BEND[@]}" --version | tail -1)"
[[ "$(printf '%s\n%s' "$proof" "$version")" == "$(cat "$HERE/PROOF.txt")" ]] || { echo 'proof or compiler version differs from capture' >&2; exit 1; }
lanes="$(run_to bash ./scripts/lanes.sh goldens/cases.tsv goldens port/main.bend --threads "$N" | tail -1)"
printf '%s' "$lanes" | PYTHONPATH="$SCRIPTS${PYTHONPATH:+:$PYTHONPATH}" python3 -c 'import json,sys; from case_manifest import cases,validate_lanes; x=json.load(sys.stdin); validate_lanes(x,int(sys.argv[1]),case_count=len(cases("goldens/cases.tsv"))); old=json.load(open(sys.argv[2])); sys.exit(x!=old)' "$N" "$HERE/lanes.json"
printf '%s\n%s\n' "$version" "$lanes"
if [[ -n "$SWITCH" ]]; then
  run_to bash ./scripts/port-doctor.sh --threads "$N" --switch "$SWITCH" --probe "$ARGS"
fi
verify_snapshot
SH
  printf '# Rollback of %s\n\nNow: `%s <binary> -- %s` selects the spec twin (parity unchanged). Source: `git revert %s`; move the PERF-LEDGER row to NEGATIVE-EVIDENCE as NEGATIVE(reverted) with a retry predicate; the law stays.\n' "$ID" "${SWITCH:-<X_SPEC=1>}" "$ARGS" "$sha" >"$DIR/rollback.md"
fi
chmod +x "$DIR/rerun.sh" 2>/dev/null || bad=1
# manifest
python3 - "$DIR" "$ID" "$today" "$sha" "$bendv" "$host" "$THREADS" <<'PY' || bad=1
import hashlib,pathlib,sys
d=pathlib.Path(sys.argv[1]); names=('id','date','sha','bend','host','threads')
lines=['bundle: '+'  '.join(f'{k}: {v}' for k,v in zip(names,sys.argv[2:])), 'sha256:']
for p in sorted(d.iterdir()):
    if p.name!='MANIFEST.txt': lines.append(f'  {hashlib.sha256(p.read_bytes()).hexdigest()}  {p.name}')
(d/'MANIFEST.txt').write_text('\n'.join(lines)+'\n')
PY
nf="$(ls "$DIR" | wc -l | tr -d ' ')"
verdict=GREEN; [[ $bad -eq 0 ]] || verdict=RED
echo "--"
echo "evidence-bundle: $DIR ($nf files) → $verdict; the PERF-LEDGER evidence cell is \`$DIR\`"
python3 - "$sha" "$bendv" "$host" "$ID" "$DIR" "$nf" "$proof" "$lanes_v" "$verdict" <<'PY'
import json,sys
keys=('sha','bend','host','id','dir','files','proof','lanes','verdict')
row=dict(zip(keys,sys.argv[1:])); row['files']=int(row['files'])
print(json.dumps(dict(schema='p2b.evidence-bundle.v1',**row)))
PY
[[ $bad -eq 0 ]]
