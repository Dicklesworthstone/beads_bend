#!/usr/bin/env bash
# law-coverage: reconcile the three places a law lives. Every `law <name>`
# in LAWS.bend must have a `def Laws.<name>` in PROOF.bend (an unproved law
# is red); every `def Laws.<name>` must correspond to a law (a proof of
# nothing is a stale file); every law named in FEATURE_PARITY.md's `laws`
# column must exist (a board citing a ghost law is a lie); and every law
# should be cited by at least one board row (an uncited law is coverage
# nobody claims). Also counts `@unsafe` in main.bend and PROOF.bend.
#
# usage: law-coverage.sh [port/LAWS.bend] [port/PROOF.bend] [docs/FEATURE_PARITY.md] [port/main.bend]
# exit: 0 no unproved laws and no ghost citations (uncited laws are a warning), 1 otherwise, 2 usage.
# Last stdout line: {"laws","proofs","unproved","ghost_proofs","ghost_cited","uncited","unsafe","unsafe_annotations","verdict"}
# ("unsafe" == "unsafe_annotations": the @unsafe defs in the sources; the CLI's
# verdict on 2.0.16+ also counts template instances: see port-doctor.sh).
set -uo pipefail
export PYTHONDONTWRITEBYTECODE=1
usage() { sed -n '2,/^set -/p' "$0" | sed '$d' | sed 's/^# \{0,1\}//'; }
[[ "${1:-}" == "--help" || "${1:-}" == "-h" ]] && { usage; exit 0; }
[[ $# -le 4 ]] || { usage >&2; exit 2; }
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
python3 - "$HERE" "${1:-port/LAWS.bend}" "${2:-port/PROOF.bend}" "${3:-docs/FEATURE_PARITY.md}" "${4:-port/main.bend}" <<'PY'
import collections,json,re,sys
sys.path.insert(0,sys.argv[1])
from case_manifest import regular_text
from markdown_evidence import split_row,visible_lines
try:
    laws_text,proof_text,board,main=map(regular_text,sys.argv[2:])
    declarations=re.findall(r'^law\s+([A-Za-z_][A-Za-z0-9_.]*)\b',laws_text,re.M)
    definitions=re.findall(r'^def\s+Laws\.([A-Za-z_][A-Za-z0-9_.]*)\b',proof_text,re.M)
    duplicate_laws=sorted(k for k,n in collections.Counter(declarations).items() if n>1)
    duplicate_proofs=sorted(k for k,n in collections.Counter(definitions).items() if n>1)
    laws,proofs,cited=set(declarations),set(definitions),set()
    header=None; found=0; features=0
    for line in visible_lines(board):
        cells=split_row(line,unescape=True)
        if cells is None:
            header=None
            continue
        if cells and cells[0].lower()=='feature':
            if found or 'laws' not in [cell.lower() for cell in cells]: raise ValueError('missing/ambiguous feature laws column')
            header=[cell.lower() for cell in cells]; found+=1
            continue
        if header is None: continue
        if len(cells)!=len(header): raise ValueError('malformed feature table row')
        if all(re.fullmatch(r':?-{3,}:?',cell) for cell in cells): continue
        features+=1
        for raw in cells[header.index('laws')].split(','):
            name=raw.strip().strip('`').strip()
            if name.lower() in ('','none','-'): continue
            if not re.fullmatch(r'[A-Za-z_][A-Za-z0-9_.]*',name): raise ValueError('invalid law citation '+repr(name))
            cited.add(name)
    if found!=1 or not features: raise ValueError('missing or empty visible feature table')
    unsafe=len(re.findall(r'^\s*@unsafe\b',main+'\n'+proof_text,re.M))
    issues=dict(unproved=laws-proofs,ghost_proofs=proofs-laws,ghost_cited=cited-laws,uncited=laws-cited)
    for name,values in issues.items():
        print(('warn' if name=='uncited' else 'RED')+': '+name+': '+', '.join(sorted(values)) if values else 'ok: '+name)
    bad=any(issues[name] for name in ('unproved','ghost_proofs','ghost_cited')) or duplicate_laws or duplicate_proofs
    verdict='RED' if bad else 'OK'
    print(json.dumps(dict(laws=len(laws),proofs=len(proofs),**{name:' '.join(sorted(values)) for name,values in issues.items()},
                         duplicate_laws=duplicate_laws,duplicate_proofs=duplicate_proofs,
                         unsafe=unsafe,unsafe_annotations=unsafe,verdict=verdict)))
    sys.exit(1 if bad else 0)
except (OSError,ValueError) as exc:
    print('error: '+str(exc),file=sys.stderr)
    print(json.dumps(dict(verdict='RED',reason=str(exc))))
    sys.exit(2)
PY
