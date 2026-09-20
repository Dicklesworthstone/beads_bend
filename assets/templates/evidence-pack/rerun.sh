#!/usr/bin/env bash
# rerun: reproduce <EXP-id>'s gate lines from a checkout at the card's commit.
# Written by scripts/evidence-bundle.sh at Phase 5 with the <placeholders>
# substituted. Every line prints an artifact the auditor diffs against this
# bundle (SHIP-AND-CERTIFY "Auditor reproduction (must be empty-diff)").
# The captures are commented: they re-run under their own cv gate, and a
# refused capture is NO_EVIDENCE, never a number.
set -euo pipefail
export PYTHONDONTWRITEBYTECODE=1
SHA='<sha_sh>'; N='<threads_sh>'; ARGS='<args_sh>'; SWITCH='<switch_sh>'
LIMIT="${1:-600}"  # optional positional timeout, seconds per gate
python3 -c 'import math,sys; n=float(sys.argv[1]); sys.exit(not math.isfinite(n) or n<=0)' "$LIMIT"
BEND=()
while IFS= read -r -d '' word; do BEND+=("$word"); done < <(python3 -c 'import pathlib,shlex,shutil,sys; a=shlex.split(sys.argv[1]); a[0]=shutil.which(a[0]) or a[0]; [sys.stdout.buffer.write((str(pathlib.Path(x).resolve()) if pathlib.Path(x).is_file() else x).encode()+b"\0") for x in a]' "${BEND_CLI:-bend}")
[[ ${#BEND[@]} -gt 0 ]] || exit 2
export BEND_NO_TELEMETRY=1
[[ "$(git rev-parse HEAD 2>/dev/null)" == "$SHA" ]] || { echo "checkout $SHA first: git checkout $SHA" >&2; exit 2; }
HERE="$(cd "$(dirname "$0")" && pwd)"
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
    # source.tar materializes file symlinks. Accept those identical bytes;
    # a new or retargeted symlink still changes the recorded input topology.
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
proof="$(cd port && run_to "${BEND[@]}" PROOF.bend 2>&1 | tail -1)"
printf '%s\n' "$proof"
[[ "$proof" =~ ^All\ terms\ check(,\ with\ [0-9]+\ unsafe\ annotations?)?\.$ ]] || exit 1
version="$(run_to "${BEND[@]}" --version | tail -1)"
[[ "$(printf '%s\n%s' "$proof" "$version")" == "$(cat "$HERE/PROOF.txt")" ]] || { echo 'proof or compiler version differs from capture' >&2; exit 1; }
lanes="$(run_to bash ./scripts/lanes.sh goldens/cases.tsv goldens port/main.bend --threads "$N" | tail -1)"
printf '%s' "$lanes" | PYTHONPATH="$SCRIPTS${PYTHONPATH:+:$PYTHONPATH}" python3 -c 'import json,sys; from case_manifest import cases,validate_lanes; x=json.load(sys.stdin); validate_lanes(x,int(sys.argv[1]),case_count=len(cases("goldens/cases.tsv"))); old=json.load(open(sys.argv[2])); sys.exit(x!=old)' "$N" "$HERE/lanes.json"
printf '%s\n%s\n' "$version" "$lanes"
if [[ -n "$SWITCH" ]]; then
  # doctor compares complete stdout, stderr and exit status under a timeout.
  run_to bash ./scripts/port-doctor.sh --threads "$N" --switch "$SWITCH" --probe "$ARGS"
fi
# A gate may itself change its inputs. Preflight alone cannot certify the
# source bytes that remain after the complete replay.
verify_snapshot
# captures (PERFORMANCE-CAMPAIGN Step 6; bend2-mega-skill beside the skill):
#   <skill>/../bend2-mega-skill/scripts/bench-speedup.sh port/main.bend --threads 1,$N --aa --max-cv 5 --args "-- $ARGS" | tail -1
#   ./scripts/incumbent-bench.sh --runs 6 --pin "<PLAN §2 pin text>" --original <original cmd> $ARGS --port ./x --threads 1 --gpu off -- $ARGS | tail -1
