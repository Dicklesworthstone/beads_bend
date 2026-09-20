#!/usr/bin/env bash
# pin-check: verify the port's contract before any gate is trusted. Reads
# docs/PIN.toml (PLAN §2 and §2b as data; template: assets/templates/PIN.toml)
# and checks, from the port root:
#   original_present     the pinned path exists                                   RED
#   original_gitignored  legacy/ (or the pinned path) is in .gitignore             YELLOW
#   original_version     [original].version_cmd prints [original].version_expect  RED    (skipped when version_cmd is empty)
#   manifest             goldens/MANIFEST.txt exists                              RED
#   manifest_command     captured original_argv equals [original].run_cmd argv RED
#   manifest_version     MANIFEST's `version:` line contains version_expect       YELLOW (skipped when empty)
#   case_count           cases.tsv rows == <name>.out goldens == MANIFEST's count RED
#   bend_version         `bend --version` equals [bend].version                   YELLOW -> scripts/version-drift.sh (VERSION-DRIFT)
#   bend_checkout        the checkout's short sha equals [bend].checkout_sha      YELLOW (only when the CLI is bun <dir>/bend2/main.ts)
#   lane_<name>          a tool per [lanes].required lane: clang for c-* (RED),
#                        bun for js (YELLOW), [lanes].gpu_host for gpu (YELLOW)
#   approver             [approver].disc is filled and not a <placeholder>        YELLOW
# GREEN: trust the gates. YELLOW: every claim made now carries the caveat the
# note names (both Bend versions; a MISSING lane). RED: stop and re-pin
# (PLAN §2, PIN.toml) or re-capture with --repin before any gate line is
# pasted (PORT-LOOP back-edge "the original changes" -> Phase 0). Nothing is
# fixed or written. BEND_CLI wins over [bend].cli; both fall back to `bend`.
#
# usage: pin-check.sh [docs/PIN.toml] [--root DIR]
# exit: 0 GREEN, 1 YELLOW, 2 RED or usage. Last stdout line:
#   {"schema":"p2b.pin-check.v1","sha","bend","host","checks":[{"check","status","note"}],"verdict"}
set -uo pipefail
export PYTHONDONTWRITEBYTECODE=1
usage() { sed -n '2,/^set -/p' "$0" | sed '$d' | sed 's/^# \{0,1\}//'; }
[[ "${1:-}" == "--help" || "${1:-}" == "-h" ]] && { usage; exit 0; }
P="docs/PIN.toml"; ROOT="$PWD"
while [[ $# -gt 0 ]]; do
  case "$1" in
    --root) [[ $# -ge 2 && -n "$2" ]] || { echo 'error: --root needs DIR' >&2; exit 2; }; ROOT="$2"; shift 2;;
    -*) echo "error: unknown option $1" >&2; usage >&2; exit 2;;
    *) P="$1"; shift;;
  esac
done
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)" || exit 2
cd "$ROOT" || { echo "error: no such root $ROOT" >&2; exit 2; }
[[ -f "$P" ]] || { echo "error: $P not found (copy assets/templates/PIN.toml to docs/PIN.toml and fill it at Phase 0)" >&2; echo '{"schema":"p2b.pin-check.v1","checks":[],"verdict":"RED","reason":"no PIN.toml"}'; exit 2; }
config="$(python3 - "$HERE" "$P" <<'PY'
import json,sys,tomllib
sys.path.insert(0,sys.argv[1])
from case_manifest import regular_text
try:
    data=tomllib.loads(regular_text(sys.argv[2]))
    for section in ('original','bend','lanes','approver'):
        if not isinstance(data.get(section),dict): raise ValueError('missing table '+section)
    for section,keys in {'original':('path','vcs','commit','version_cmd','version_expect','run_cmd'), 'bend':('version','checkout_sha','cli'), 'lanes':('gpu_host',), 'approver':('disc',)}.items():
        for key in keys:
            value=data[section].get(key,'')
            if section=='original' and key=='run_cmd' and isinstance(value,list):
                if not value or any(not isinstance(v,str) or '\0' in v for v in value): raise ValueError('run_cmd must contain string argv')
            elif not isinstance(value,str) or '\0' in value: raise ValueError(section+'.'+key+' must be a string without NUL')
    lanes=data['lanes'].get('required')
    if not isinstance(lanes,list) or not lanes or any(not isinstance(x,str) or x not in ('interpreter','c-1t','c-Nt','js','gpu') for x in lanes) or len(lanes)!=len(set(lanes)):
        raise ValueError('lanes.required must be a nonempty unique list of supported lanes')
    print(json.dumps(data))
except (OSError,ValueError) as exc:
    sys.exit('invalid PIN.toml: '+str(exc))
PY
)" || { echo '{"schema":"p2b.pin-check.v1","checks":[],"verdict":"RED","reason":"invalid PIN.toml"}'; exit 2; }
kv() { python3 -c 'import json,sys; x=json.loads(sys.argv[1])[sys.argv[2]].get(sys.argv[3],""); print(json.dumps(x) if isinstance(x,list) else x)' "$config" "$1" "$2"; }
cli="${BEND_CLI:-$(kv bend cli)}"; [[ -n "$cli" ]] || cli=bend
BEND=()
while IFS= read -r -d '' word; do BEND+=("$word"); done < <(python3 -c 'import shlex,sys; [sys.stdout.buffer.write(x.encode()+b"\0") for x in shlex.split(sys.argv[1])]' "$cli")
[[ ${#BEND[@]} -gt 0 ]] || { echo 'error: invalid/empty Bend command' >&2; exit 2; }
export BEND_NO_TELEMETRY=1
run_to() {
  python3 - "$HERE" "$@" <<'PY'
import sys
sys.path.insert(0,sys.argv[1])
from case_manifest import run
result=run(sys.argv[2:],timeout=30)
sys.stdout.buffer.write(result['out'])
sys.stderr.buffer.write(result['err'])
rc=result['rc']
sys.exit(125 if rc is None else 128-rc if rc<0 else rc)
PY
}
red=0; yel=0; rows=""
j() { python3 -c 'import json,sys; print(json.dumps(sys.argv[1])[1:-1])' "$1"; }
add() {  # check status note
  rows+="{\"check\":\"$1\",\"status\":\"$2\",\"note\":\"$(j "$3")\"},"
  printf '%-7s %-20s %s\n' "$2" "$1" "$3"
  [[ "$2" == RED ]] && red=1; [[ "$2" == YELLOW ]] && yel=1
}

# the original
op="$(kv original path)"
if [[ -n "$op" && -e "$op" ]]; then add original_present GREEN "$op"; else add original_present RED "missing ${op:-<path>} (clone or symlink the pinned original under legacy/)"; fi
oc="$(kv original commit)"; ovcs="$(kv original vcs)"
oc_lower="$(printf '%s' "$oc" | tr A-F a-f)"
if [[ "$ovcs" == git ]]; then
  od="$op"; [[ -f "$od" ]] && od="$(dirname "$od")"
  have="$(git -C "$od" rev-parse HEAD 2>/dev/null)"
  # git searches parent directories. An ignored oracle inside the port must
  # not accidentally inherit the port's HEAD as its own source identity.
  tracked=""
  if [[ -f "$op" ]]; then tracked="$(git -C "$od" ls-files -- "$(basename "$op")" 2>/dev/null)"
  elif [[ -d "$op" ]]; then tracked="$(git -C "$od" ls-files -- . 2>/dev/null)"; fi
  if [[ -n "$tracked" && "$oc" =~ ^[0-9a-fA-F]{7,40}$ && "$have" == "$oc_lower"* ]]; then
    add original_commit GREEN "$have"
  else add original_commit RED "original source is not tracked, or HEAD ${have:-unknown} does not match pin ${oc:-unset}"; fi
  if [[ -n "$(git -C "$od" status --porcelain --untracked-files=normal 2>/dev/null)" ]]; then
    add original_tree RED "original worktree differs from its commit; pin the actual source before capture"
  fi
elif [[ "$ovcs" == none ]]; then
  add original_commit YELLOW "no VCS identity; preserve original source hashes with the capture"
else add original_commit YELLOW "fill original.vcs and original.commit"; fi
if [[ -n "$op" ]] && git check-ignore -q -- "$op" 2>/dev/null; then add original_gitignored GREEN "git check-ignore: $op"; else add original_gitignored YELLOW "the original path is not Git-ignored (the oracle is not part of the port)"; fi
vc="$(kv original version_cmd)"; ve="$(kv original version_expect)"
if [[ -n "$vc" && "$vc" != \<* ]]; then
  out="$(run_to bash -c "$vc" 2>&1)"; vrc=$?
  if [[ $vrc -eq 0 && -n "$ve" && "$ve" != \<* && "$out" == *"$ve"* ]]; then add original_version GREEN "$ve"
  else add original_version RED "want '$ve' in the output of '$vc', got '$(printf '%s' "$out" | head -1 | head -c 80)' (re-pin PLAN §2 + PIN.toml, then golden-capture --repin)"; fi
fi
# the manifest
rc_="$(kv original run_cmd)"; M="goldens/MANIFEST.txt"
if [[ -f "$M" ]]; then
  add manifest GREEN "$(head -1 "$M")"
  if hash_check="$(python3 - "$M" "$HERE" <<'PY'
import hashlib,json,pathlib,re,sys
sys.path.insert(0,sys.argv[2])
from case_manifest import cases,regular_text,regular_bytes,provenance
p=pathlib.Path(sys.argv[1]); text=regular_text(p)
rows=re.findall(r'^  ([0-9a-f]{64})  ([A-Za-z0-9][A-Za-z0-9_.-]*)$',text,re.M)
bad=[]
blocks=text.split('\nsha256:\n')
if len(blocks)!=2 or any(not re.fullmatch(r'  [0-9a-f]{64}  [A-Za-z0-9][A-Za-z0-9_.-]*',line) for line in blocks[-1].splitlines() if line.strip()):
    bad.append('malformed hash block')
for h,n in rows:
    f=p.parent/n
    if not f.is_file() or hashlib.sha256(regular_bytes(f)).hexdigest()!=h: bad.append(n)
listed={n for _,n in rows}
if len(listed)!=len(rows): bad.append('duplicate golden hashes')
casefile=p.parent/'cases.tsv'
manifest=cases(casefile)
expected={f'{n}.{ext}' for n,_,_ in manifest for ext in ('out','err','exit')}
if listed!=expected: bad.append('golden hash set differs from cases.tsv')
prov=re.findall(r'^provenance: (.+)$',text,re.M)
commands=re.findall(r'^original_argv: (.+)$',text,re.M)
if len(prov)==1 and len(commands)==1:
    data=json.loads(prov[0]); oldcwd=pathlib.Path(data['cwd'])
    command=json.loads(commands[0])
    if not isinstance(command,list) or not command or any(not isinstance(x,str) or '\0' in x for x in command): raise ValueError('invalid captured original_argv')
    def relocated(path):
        f=pathlib.Path(path)
        try: return str(pathlib.Path.cwd()/f.relative_to(oldcwd))
        except ValueError: return str(f)
    actual=dict(data,cwd=str(pathlib.Path.cwd()))
    for key in ('case_manifest','executable','command_files','case_files','stdin_files'):
        group=[data[key]] if key in ('case_manifest','executable') else data[key]
        if not isinstance(group,list): raise ValueError('invalid provenance '+key)
        mapped=[]
        for item in group:
            if set(item)!= {'path','sha256'} or not re.fullmatch('[0-9a-f]{64}',item['sha256']): raise ValueError('invalid captured file record')
            mapped.append(dict(item,path=relocated(item['path'])))
        actual[key]=mapped[0] if key in ('case_manifest','executable') else mapped
    for item in [actual['case_manifest'],actual['executable'],*actual['command_files'],*actual['case_files'],*actual['stdin_files']]:
        f=pathlib.Path(item['path'])
        if not f.is_file() or hashlib.sha256(regular_bytes(f)).hexdigest()!=item['sha256']: bad.append('changed input '+str(f))
    def command_word(word):
        flag,separator,value=word.partition('=')
        if separator and flag.startswith('-') and pathlib.Path(value).is_absolute(): return flag+'='+relocated(value)
        return relocated(word) if pathlib.Path(word).is_absolute() else word
    wanted=provenance([command_word(word) for word in command],str(casefile),manifest)
    if actual!=wanted: bad.append('captured provenance does not cover current command and case inputs')
else: bad.append('missing or duplicate captured source/input provenance or original_argv; recapture')
print(f'{len(rows)} hashes and capture inputs verified' if rows and not bad else 'capture integrity failed: '+'; '.join(bad))
sys.exit(0 if rows and not bad else 1)
PY
  )"; then add manifest_hashes GREEN "$hash_check"; else add manifest_hashes RED "$hash_check"; fi
  if mc="$(python3 - "$M" "$rc_" "$HERE" <<'PY'
import json,re,shlex,sys
sys.path.insert(0,sys.argv[3])
from case_manifest import regular_text
raw=sys.argv[2]
want=json.loads(raw) if raw.lstrip().startswith('[') else shlex.split(raw)
rows=re.findall(r'^original_argv: (.+)$',regular_text(sys.argv[1]),re.M)
if not want or len(rows)!=1 or json.loads(rows[0])!=want: sys.exit('captured original_argv differs from PIN run_cmd')
print(json.dumps(want))
PY
  )"; then add manifest_command GREEN "$mc"
  else add manifest_command RED "captured argv does not match PIN run_cmd: '$rc_'"; fi
  if [[ -n "$ve" && "$ve" != \<* ]]; then
    mv="$(sed -n 's/^version: *//p' "$M")"
    if [[ "$mv" == *"$ve"* ]]; then add manifest_version GREEN "$ve"; else add manifest_version YELLOW "MANIFEST version lacks the pinned version string '$ve' (the original does not answer --version, or the pin moved)"; fi
  fi
  nc="$(PYTHONPATH="$HERE${PYTHONPATH:+:$PYTHONPATH}" python3 -c 'from case_manifest import cases; print(len(cases("goldens/cases.tsv")))' 2>/dev/null)"; [[ "$nc" =~ ^[0-9]+$ ]] || nc=0
  ng="$(ls goldens/*.out 2>/dev/null | wc -l | tr -d ' ')"
  nm="$(sed -n 's/^cases:.*(\([0-9]*\) cases).*/\1/p' "$M" | head -1)"
  if [[ "$nc" -gt 0 && "$nc" == "$ng" && "$nm" == "$nc" ]]; then add case_count GREEN "$nc cases = $ng goldens = MANIFEST $nm"
  else add case_count RED "cases.tsv=$nc goldens=$ng MANIFEST=${nm:-?} (golden-capture --repin \"new cases\", or fix cases.tsv)"; fi
else
  add manifest RED "no goldens/MANIFEST.txt (Phase 0: golden-capture.sh first)"
fi
# bend
bvl="$(run_to "${BEND[@]}" --version 2>/dev/null | tail -1)"; brc=$?; bv="$(printf '%s' "$bvl" | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1)"
pin_version="$(kv bend version)"; pv="$(printf '%s' "$pin_version" | grep -oE '^[0-9]+\.[0-9]+\.[0-9]+$')"
if [[ -z "$bv" || $brc -ne 0 ]]; then add bend_version RED "no bend answers --version successfully (${BEND[*]}); set BEND_CLI or [bend].cli"
elif [[ -z "$pv" ]]; then add bend_version YELLOW "bend $bv here; PIN [bend].version is not filled"
elif [[ "$bv" == "$pv" ]]; then add bend_version GREEN "bend $bv"
else add bend_version YELLOW "bend $bv here, pinned $pv: unsafe counts, the verdict text and F32/Nat facts can differ with no source change; run scripts/version-drift.sh --old \"<pinned cli>\" --new \"${BEND[*]}\" and name both versions in every claim"; fi
cs="$(kv bend checkout_sha)"
cs_lower="$(printf '%s' "$cs" | tr A-F a-f)"
if [[ -n "$cs" && "$cs" != \<* ]]; then
  mt=""; for w in "${BEND[@]}"; do [[ "$w" == *bend2/main.ts ]] && mt="$w"; done
  if [[ -n "$mt" ]]; then
    checkout="$(dirname "$(dirname "$mt")")"
    have="$(git -C "$checkout" rev-parse HEAD 2>/dev/null)"
    if [[ "$cs" =~ ^[0-9a-fA-F]{7,40}$ && -n "$have" && "$have" == "$cs_lower"* ]] && git -C "$checkout" ls-files --error-unmatch bend2/main.ts >/dev/null 2>&1; then add bend_checkout GREEN "$have"; else add bend_checkout YELLOW "compiler entry is untracked, or checkout ${have:-?} differs from pin $cs (a checkout pin needs the sha: --version is a constant)"; fi
    if [[ -n "$(git -C "$(dirname "$(dirname "$mt")")" status --porcelain --untracked-files=normal 2>/dev/null)" ]]; then
      add bend_tree YELLOW "compiler checkout has changes beyond its pinned commit; record their hashes in evidence"
    fi
  else add bend_checkout YELLOW "PIN names a checkout sha but the CLI is not bun <dir>/bend2/main.ts"; fi
fi
# lanes
for lane in $(python3 -c 'import json,sys; print(" ".join(json.loads(sys.argv[1])["lanes"]["required"]))' "$config"); do
  case "$lane" in
    interpreter) if [[ -n "$bv" ]]; then add lane_interpreter GREEN "${BEND[*]}"; else add lane_interpreter RED "no bend answers --version"; fi;;
    c-*) if out="$(run_to clang --version 2>/dev/null)" && [[ -n "$out" ]]; then add "lane_$lane" GREEN "$(printf '%s\n' "$out" | head -1)"; else add "lane_$lane" RED "clang unavailable: the $lane lane is MISSING"; fi;;
    js) if out="$(run_to bun --version 2>/dev/null)" && [[ -n "$out" ]]; then add lane_js GREEN "bun $out"; else add lane_js YELLOW "bun unavailable: the js lane is MISSING"; fi;;
    gpu) gh="$(kv lanes gpu_host)"; if [[ -n "$gh" ]]; then add lane_gpu GREEN "device host $gh"; else add lane_gpu YELLOW "gpu lane required but [lanes].gpu_host is empty (name the host or record the lane MISSING with the reason)"; fi;;
    *) add "lane_$lane" YELLOW "unknown lane name (the five are interpreter, c-1t, c-Nt, js, gpu)";;
  esac
done
# approver
ad="$(kv approver disc)"
if [[ -n "$ad" && "$ad" != \<* ]]; then add approver GREEN "$ad"; else add approver YELLOW "[approver].disc is empty or a placeholder: no DISC can be accepted (self-signed is refused)"; fi

v=GREEN; [[ $yel -eq 1 ]] && v=YELLOW; [[ $red -eq 1 ]] && v=RED
sha="$(git rev-parse --short HEAD 2>/dev/null || echo none)"; host="$(uname -s -m 2>/dev/null | tr ' ' '-')"
echo "--"
echo "pin-check: $v"
printf '{"schema":"p2b.pin-check.v1","sha":"%s","bend":"%s","host":"%s","checks":[%s],"verdict":"%s"}\n' "$sha" "$(j "$bvl")" "$host" "${rows%,}" "$v"
case "$v" in GREEN) exit 0;; YELLOW) exit 1;; *) exit 2;; esac
