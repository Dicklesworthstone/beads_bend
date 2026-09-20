#!/usr/bin/env bash
# law-mutation: the admission test for laws. A law that stays green when the
# def it speaks about is broken pins nothing (gavel's "a law pins its
# function only if no argument-ignoring body satisfies it. That is a thing
# you run"; bend-sha256's "negative public mutations"; evm-bend's "5 semantic
# mutants rejected"). This script copies the port directory to a temp dir,
# applies one textual mutation at a time to the body of each named def (a
# fast twin, a spec twin, any def a law mentions) and runs the proof under
# every mutant:
#   INVALID   the mutant does not check on its own (`bend <file> -o m.c`, a
#             check without a run): not evidence about any law
#   KILLED    a structured checker refutation names a law or equality lemma
#   ERROR     compiler crash, launch failure, or an unclassified diagnostic
#   SURVIVED  `bend PROOF.bend` stays green: the laws are WEAK for this def
#   TIMEOUT   a bend run passed --timeout: a timeout is not a passing proof
# The port is never edited; everything happens in a mktemp copy. Baseline:
# the unmutated PROOF must be green or the run stops (exit 2).
#
# Operators (one mutant each, at the FIRST matching site inside the def's
# body; an operator with no site in a def produces no mutant, counted in
# "nosite"):
#   add2sub    Nat.add( U32.add( F32.add( -> .sub(     sub2add   .sub( -> .add(
#   mul2add    .mul( -> .add(                          le2lt     is_le( -> is_lt(
#   lt2le      is_lt( -> is_le(                        ge2gt     is_ge( -> is_gt(
#   gt2ge      is_gt( -> is_ge(                        eq2ne     is_eq( -> is_ne(
#   plus2minus the infix sugar ` + ` -> ` - ` (never `++` or a glued `1n+p`)
#   minus2plus ` - ` -> ` + `                          times2plus ` * ` -> ` + `
#   zero2one   a literal 0n in an arm body (never a `case` pattern) -> 1n
#   one2zero   a literal 1n in an arm body -> 0n
#   base       the first `case 0n:` / `case Nil{}:` / `case []:` arm's body
#              -> 0n (-> 1n when it already is 0n): a dropped base case
#   swapargs   the two arguments of the first two-argument call whose callee
#              is not a commutative Base op (Nat/U32/F32 add, mul, min, max;
#              U32 xor/and/or; Bool and/or/xor) swapped
# A mutant that is semantically equivalent to the source (rare with these
# operators) SURVIVES: read the diff the script prints before calling a law
# weak, and pick another operator or another def.
#
# usage: law-mutation.sh <port-dir> <def-name>... [--file main.bend] [--proof PROOF.bend]
#                        [--ops a,b,...] [--timeout S] [--keep]
#   <port-dir>   the directory holding the .bend files (main, LAWS, PROOF); read only
#   <def-name>   a top-level def in --file to mutate (`par`, `report.fin`); repeatable
#   --file       the file that defines the defs, relative to <port-dir> (default main.bend)
#   --proof      the proof file, relative to <port-dir> (default PROOF.bend)
#   --ops        comma list of operators (default: all of the above)
#   --timeout    seconds per bend run (default 90)
#   --keep       accepted explicitly; artifacts are always retained for inspection
# BEND_CLI is honored ("bun /path/bend2/main.ts"); otherwise `bend` on PATH.
# exit: 0 STRONG (each requested def has a killed valid mutant and no
#       survivor, timeout or tool error), 1 WEAK (a mutant survived),
#       3 INCONCLUSIVE (incomplete evidence), 2 usage or a RED baseline.
# Last stdout line: {"port","file","defs":[…],"mutants":[{"def","op","status","killed_by","secs"}],
#                    "valid","killed","survived","invalid","timeouts","nosite","verdict"}
set -uo pipefail
export PYTHONDONTWRITEBYTECODE=1
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)" || exit 2
usage() { sed -n '2,/^set -/p' "$0" | sed '$d' | sed 's/^# \{0,1\}//'; }
[[ "${1:-}" == "--help" || "${1:-}" == "-h" ]] && { usage; exit 0; }
[[ $# -lt 2 ]] && { usage >&2; exit 2; }
PORT="$1"; shift
FILE="main.bend"; PROOF="PROOF.bend"; OPS=""; TO=90; KEEP=0; DEFS=()
while [[ $# -gt 0 ]]; do
  case "$1" in --file|--proof|--ops|--timeout) [[ $# -ge 2 && -n "$2" ]] || { echo "error: $1 needs a value" >&2; exit 2; };; esac
  case "$1" in
    --file) FILE="${2:-}"; shift 2;;
    --proof) PROOF="${2:-}"; shift 2;;
    --ops) OPS="${2:-}"; shift 2;;
    --timeout) TO="${2:-}"; shift 2;;
    --keep) KEEP=1; shift;;
    -*) echo "error: unknown option $1" >&2; exit 2;;
    *) DEFS+=("$1"); shift;;
  esac
done
[[ -d "$PORT" && -f "$PORT/$FILE" && -f "$PORT/$PROOF" ]] || { echo "error: need $PORT/$FILE and $PORT/$PROOF" >&2; usage >&2; exit 2; }
[[ ${#DEFS[@]} -gt 0 ]] || { echo "error: name at least one def" >&2; exit 2; }
python3 - "$PORT" "$FILE" "$PROOF" <<'PY' || exit 2
from pathlib import Path,PurePosixPath
import os,sys
for name in sys.argv[2:]:
    path = PurePosixPath(name)
    if path.is_absolute() or '..' in path.parts:
        sys.exit('error: --file and --proof must stay inside the copied port directory')
for directory,folders,files in os.walk(sys.argv[1]):
    for name in folders+files:
        path=Path(directory)/name
        if (path.is_dir() and path.is_symlink()) or not (path.is_dir() or path.is_file()):
            sys.exit('error: port copy refuses directory symlinks/special files: '+str(path))
PY
[[ "$TO" =~ ^[0-9]+([.][0-9]+)?$ ]] && awk -v n="$TO" 'BEGIN {exit !(n>0)}' || { echo "error: timeout must be positive" >&2; exit 2; }
for def in "${DEFS[@]}"; do [[ "$def" =~ ^[A-Za-z_][A-Za-z0-9_.]*$ ]] || { echo "error: invalid def name $def" >&2; exit 2; }; done
ALL_OPS="add2sub sub2add mul2add le2lt lt2le ge2gt gt2ge eq2ne plus2minus minus2plus times2plus zero2one one2zero base swapargs"
[[ -z "$OPS" ]] && OPS="$ALL_OPS" || OPS="${OPS//,/ }"
for op in $OPS; do [[ " $ALL_OPS " == *" $op "* ]] || { echo "error: unknown operator $op" >&2; exit 2; }; done
BEND=()
while IFS= read -r -d '' word; do BEND+=("$word"); done < <(python3 -c 'import pathlib,shlex,shutil,sys; a=shlex.split(sys.argv[1]); a[0]=shutil.which(a[0]) or a[0]; [sys.stdout.buffer.write((str(pathlib.Path(x).resolve()) if pathlib.Path(x).is_file() else x).encode()+b"\0") for x in a]' "${BEND_CLI:-bend}")
[[ ${#BEND[@]} -gt 0 ]] || { echo 'error: invalid/empty BEND_CLI' >&2; exit 2; }
command -v "${BEND[0]}" >/dev/null 2>&1 || { echo "error: ${BEND[0]} not found (set BEND_CLI)" >&2; exit 2; }
export BEND_NO_TELEMETRY=1
T="$(mktemp -d "${TMPDIR:-/tmp}/lawmut.XXXXXX")"
trap 'echo "artifacts retained: $T" >&2' EXIT
mkdir -p "$T/base" && cp -RL "$PORT/." "$T/base/" || { echo 'error: incomplete port copy' >&2; exit 2; }
echo "using: ${BEND[*]}   port: $PORT   file: $FILE   proof: $PROOF   timeout: ${TO}s" >&2

# run bend with a timeout; prints the exit code; output in $2
brun() {
  local dir="$1" out="$2"; shift 2
  python3 - "$HERE" "$dir" "$out" "$TO" "${BEND[@]}" "$@" <<'PY'
import pathlib,sys
sys.path.insert(0,sys.argv[1])
from case_manifest import run
result=run(sys.argv[5:],cwd=sys.argv[2],timeout=float(sys.argv[4]),merge_stderr=True)
pathlib.Path(sys.argv[3]).write_bytes(result['out'])
rc=result['rc']
print(125 if rc is None else 128-rc if rc<0 else rc)
PY
}
now() { python3 -c 'import time; print(time.monotonic())'; }
elapsed() { awk -v a="$1" -v b="$2" 'BEGIN{printf "%.2f", b-a}'; }

# baseline: the proof must be green before any mutation
rc=$(brun "$T/base" "$T/base.out" "$PROOF")
if [[ "$rc" -ne 0 ]] || ! tail -1 "$T/base.out" | grep -Eq '^All terms check(, with [0-9]+ unsafe annotations?)?\.$'; then
  echo "error: baseline $PROOF is not green (exit $rc): $(tail -1 "$T/base.out")" >&2; exit 2
fi
echo "baseline: $(tail -1 "$T/base.out")"

# the def's body span in the file: [s, e) line numbers; e = next column-0 line
span() {  # $1 file, $2 def name -> "s e" or ""
  awk -v name="$2" '
    { declaration = $0; sub(/^@unsafe[ \t]+/, "", declaration) }
    !s && index(declaration, "def " name "(") == 1 { s = NR; next }
    s && /^[^ \t#]/ { print s, NR; found = 1; exit }
    END { if (s && !found) print s, NR + 1 }
  ' "$1"
}

COMMUTATIVE='Nat.add Nat.mul Nat.min Nat.max U32.add U32.mul U32.min U32.max U32.xor U32.and U32.or F32.add F32.mul F32.min F32.max Bool.and Bool.or Bool.xor'

# mutate $1 (file) lines [$2,$3) with operator $4 into $5; prints 1 when a site was found
mutate() {
  python3 - "$1" "$2" "$3" "$4" "$5" "$COMMUTATIVE" <<'PY'
import pathlib,re,sys
source,start,end,op,destination,comm=sys.argv[1:]
lines=pathlib.Path(source).read_text().splitlines(keepends=True)
def code(line):
    # Keep offsets, hide literals/comments. A textual mention of Nat.add in
    # a diagnostic must not count as a semantic mutant of the function.
    out=[]; quote=''; escaped=False
    for char in line:
        if quote:
            out.append(' ')
            if escaped: escaped=False
            elif char=='\\': escaped=True
            elif char==quote: quote=''
        elif char in ('"',"'"):
            quote=char; out.append(' ')
        elif char=='#':
            out.extend(' '*(len(line)-len(out))); break
        else: out.append(char)
    return ''.join(out)
ops=dict(add2sub=('.add(','.sub('),sub2add=('.sub(','.add('),mul2add=('.mul(','.add('),
         le2lt=('is_le(','is_lt('),lt2le=('is_lt(','is_le('),ge2gt=('is_ge(','is_gt('),gt2ge=('is_gt(','is_ge('),
         eq2ne=('is_eq(','is_ne('),plus2minus=(' + ',' - '),minus2plus=(' - ',' + '),times2plus=(' * ',' + '))
hit=False
for index in range(int(start)-1,min(int(end)-1,len(lines))):
    line=lines[index]; masked=code(line); begin=finish=None; replacement=''
    if op in ops:
        old,replacement=ops[op]; begin=masked.find(old)
        if begin<0: continue
        finish=begin+len(old)
    elif op in ('zero2one','one2zero'):
        if re.match(r'\s*case\b',masked): continue
        literal,replacement=('0n','1n') if op=='zero2one' else ('1n','0n')
        match=re.search(r'(?<![A-Za-z0-9_.])'+literal+r'(?![A-Za-z0-9_])',masked)
        if not match: continue
        begin,finish=match.span()
    elif op=='swapargs':
        for match in re.finditer(r'([A-Za-z_][A-Za-z0-9_.]*)\(([^(),]+),([^(),]+)\)',masked):
            if match[1] in comm.split(): continue
            begin,finish=match.span()
            replacement=match[1]+'('+line[match.start(3):match.end(3)].strip()+', '+line[match.start(2):match.end(2)].strip()+')'
            break
        if begin is None: continue
    elif op=='base':
        match=re.fullmatch(r'([ \t]*)case (?:0n|Nil\{\}|\[\]):\s*',masked)
        if not match: continue
        indent=len(match[1].expandtabs(8)); stop=index+1
        while stop<min(int(end)-1,len(lines)):
            next_code=code(lines[stop])
            width=len(next_code)-len(next_code.lstrip(' \t'))
            if next_code.strip() and len(next_code[:width].expandtabs(8))<=indent: break
            stop+=1
        body=''.join(code(text) for text in lines[index+1:stop]).strip()
        if not body: continue
        replacement='1n' if body=='0n' else '0n'
        lines[index+1:stop]=[' '*(indent+2)+replacement+'\n']; hit=True; break
    if begin is not None:
        lines[index]=line[:begin]+replacement+line[finish:]; hit=True; break
pathlib.Path(destination).write_text(''.join(lines))
print(int(hit))
PY
}

mutants=""; valid=0; killed=0; survived=0; invalid=0; timeouts=0; errors=0; nosite=0; uncovered=0
for def in "${DEFS[@]}"; do
  def_valid=0
  sp="$(span "$T/base/$FILE" "$def")"
  [[ -n "$sp" ]] || { echo "RED: def $def not found in $FILE" >&2; exit 2; }
  s="${sp% *}"; e="${sp#* }"
  echo "def $def: $FILE lines $s-$((e-1))"
  s=$((s+1))   # the body only: a swap or a rename inside the header is a parameter rename, not a mutation
  for op in $OPS; do
    d="$T/m_${def//./_}_$op"; mkdir -p "$d" && cp -RL "$T/base/." "$d/" || { echo 'error: incomplete mutant copy' >&2; exit 2; }
    hit="$(mutate "$T/base/$FILE" "$s" "$e" "$op" "$d/$FILE")"
    if [[ "$hit" != "1" ]]; then nosite=$((nosite+1)); continue; fi
    if cmp -s "$T/base/$FILE" "$d/$FILE"; then nosite=$((nosite+1)); continue; fi
    diffline="$(diff "$T/base/$FILE" "$d/$FILE" | grep '^[<>]' | sed 's/^/      /' | head -4)"
    t0=$(now)
    rc=$(brun "$d" "$d/check.out" "$FILE" -o "$d/m.c")
    if [[ "$rc" -eq 124 ]]; then st=TIMEOUT; kb=""; timeouts=$((timeouts+1))
    elif [[ "$rc" -eq 1 ]] && grep -q '^Location:' "$d/check.out"; then st=INVALID; kb="$(grep -v '^$' "$d/check.out" | grep -v '^Error:$' | head -1 | cut -c1-80)"; invalid=$((invalid+1))
    elif [[ "$rc" -ne 0 ]]; then st=ERROR; kb="unclassified compile failure (exit $rc)"; errors=$((errors+1))
    elif [[ ! -s "$d/m.c" ]]; then st=ERROR; kb="compiler exited zero without emitted C"; errors=$((errors+1))
    else
      rc=$(brun "$d" "$d/proof.out" "$PROOF")
      if [[ "$rc" -eq 124 ]]; then st=TIMEOUT; kb=""; timeouts=$((timeouts+1))
      elif [[ "$rc" -eq 0 ]] && tail -1 "$d/proof.out" | grep -Eq '^All terms check(, with [0-9]+ unsafe annotations?)?\.$'; then st=SURVIVED; kb=""; survived=$((survived+1)); valid=$((valid+1)); def_valid=$((def_valid+1))
      elif [[ "$rc" -eq 1 ]] && grep -q '^- expected :' "$d/proof.out" && grep -q '^- observed :' "$d/proof.out" && python3 - "$d" "$d/proof.out" <<'PY'
import pathlib, re, sys
root = pathlib.Path(sys.argv[1]); output = pathlib.Path(sys.argv[2]).read_text()
locations = re.findall(r'^Location:\s*(\S+)', output, re.M)
laws = set()
for path in root.rglob('*.bend'):
    source = path.read_text()
    laws.update(re.findall(r'^law\s+([\w.]+)', source, re.M))
    for match in re.finditer(r'^def\s+([\w.]+)\([^\n]*(?:\n[ \t]+->[^\n]*)?', source, re.M):
        signature = match.group(0)
        if '->' in signature and '==' in signature.split('->', 1)[1]: laws.add(match.group(1))
sys.exit(not any(loc == name or loc.endswith('.' + name) for loc in locations for name in laws))
PY
      then st=KILLED; kb="$(grep -m1 '^Location: ' "$d/proof.out" | sed 's/^Location: //')"; killed=$((killed+1)); valid=$((valid+1)); def_valid=$((def_valid+1))
      else st=ERROR; kb="unclassified proof failure (exit $rc)"; errors=$((errors+1)); fi
    fi
    secs=$(elapsed "$t0" "$(now)")
    printf '  %-9s %-8s %-9s %s %ss\n' "$op" "$st" "${kb:--}" "" "$secs"
    printf '%s\n' "$diffline"
    mutants+="$(python3 -c 'import json,sys; d,o,s,k,t=sys.argv[1:]; print(json.dumps(dict(definition=d,op=o,status=s,killed_by=k,secs=float(t))).replace("\"definition\":", "\"def\":"))' "$def" "$op" "$st" "$kb" "$secs"),"
  done
  if [[ $def_valid -eq 0 ]]; then echo "INCONCLUSIVE: $def has no completed valid mutant"; uncovered=$((uncovered+1)); fi
done
verdict=INCONCLUSIVE
if [[ $survived -gt 0 ]]; then verdict=WEAK
elif [[ $valid -gt 0 && $uncovered -eq 0 && $timeouts -eq 0 && $errors -eq 0 ]]; then verdict=STRONG; fi
echo "mutants: valid=$valid killed=$killed survived=$survived invalid=$invalid timeouts=$timeouts errors=$errors uncovered=$uncovered nosite=$nosite   verdict: $verdict"
echo "kept: $T"
defs_json="$(printf '"%s",' "${DEFS[@]}")"
python3 - "$PORT" "$FILE" "${defs_json%,}" "${mutants%,}" "$valid" "$killed" "$survived" "$invalid" "$timeouts" "$errors" "$uncovered" "$nosite" "$verdict" <<'PY'
import json, sys
p, f, defs, mutants, *rest = sys.argv[1:]
keys = ('valid', 'killed', 'survived', 'invalid', 'timeouts', 'errors', 'uncovered', 'nosite')
result = dict(zip(keys, map(int, rest[:-1])))
result.update(port=p, file=f, defs=json.loads('[' + defs + ']'), mutants=json.loads('[' + mutants + ']'), verdict=rest[-1])
print(json.dumps(result, separators=(',', ':')))
PY
case "$verdict" in STRONG) exit 0;; WEAK) exit 1;; *) exit 3;; esac
