#!/usr/bin/env bash
# parity-board: read docs/FEATURE_PARITY.md and report the surface parity
# the way a release gate must see it: counts per status, the rule that
# `partial` never rounds up and `excluded` is debt, and a verdict:
#   FULL      every feature present (goldens named, laws named or "none")
#   PARTIAL   some feature partial or missing
#   DEBT      no partial/missing, but excluded items exist (strict-100% not claimable)
# A present row needs named golden cases and laws (or explicit "none").
# Present rows require an available case manifest and golden files; named
# laws require an available law file. Those references are cross-checked;
# this structural gate does not run them. A row whose feature
# cell is still a template placeholder (`<…>`) counts as missing and is
# listed as PLACEHOLDER.
#
# usage: parity-board.sh [docs/FEATURE_PARITY.md]
#   Rows are `| feature | original ref | port def | goldens | laws | status | notes |`
#   with status one of present | partial | missing | excluded | n/a.
# exit: 0 FULL or DEBT (the two states the parity gate accepts; DEBT still
#   forbids a "100% parity" sentence), 1 PARTIAL or MALFORMED, 2 usage.
#   JSON on the last line.
set -uo pipefail
usage() { sed -n '2,/^set -/p' "$0" | sed '$d' | sed 's/^# \{0,1\}//'; }
[[ "${1:-}" == "--help" || "${1:-}" == "-h" ]] && { usage; exit 0; }
F="${1:-docs/FEATURE_PARITY.md}"
[[ $# -le 1 ]] || { usage >&2; exit 2; }
[[ -f "$F" ]] || { echo "error: $F not found" >&2; usage >&2; exit 2; }
python3 -B - "$F" "$(dirname "$0")" <<'PY'
import json, pathlib, re, sys
sys.path.insert(0, sys.argv[2])
from case_manifest import cases as read_cases, regular_text
from markdown_evidence import visible_lines, split_row
def cells_of(line):
    return [c.strip('`') for c in split_row(line, unescape=True)]
board = pathlib.Path(sys.argv[1]).resolve()
root = board.parent.parent
cases = root / 'goldens/cases.tsv'
laws = root / 'port/LAWS.bend'
known_cases = None; input_errors = []
if cases.exists():
    try: known_cases = {name for name, _, _ in read_cases(cases)}
    except (OSError, ValueError) as exc: input_errors.append(f'invalid cases manifest: {exc}')
known_laws = None
if laws.exists():
    try: known_laws = set(re.findall(r'^law\s+([\w.]+)', regular_text(laws), re.M))
    except (OSError, ValueError) as exc: input_errors.append(f'invalid laws file: {exc}')
inside = False; errors = input_errors; seen = set(); noev = 0
counts = dict(present=0, partial=0, missing=0, excluded=0, na=0)
for line in visible_lines(regular_text(board)):
    if not line.startswith('|'): inside = False; continue
    cells = cells_of(line)
    if cells[0].lower() == 'feature':
        inside = True
        if [c.lower() for c in cells] != ['feature', 'original ref', 'port def', 'goldens', 'laws', 'status', 'notes']:
            errors.append('unexpected feature table header')
        continue
    if not inside: continue
    if all(re.fullmatch(r':?-{3,}:?', c) for c in cells): continue
    if not line.rstrip().endswith('|') or len(cells) != 7:
        errors.append('feature row must have seven columns'); continue
    feature, ref, definition, gold, law, status, notes = cells
    if not feature or feature in seen:
        errors.append(f'empty or duplicate feature: {feature!r}'); continue
    seen.add(feature); status = status.lower()
    if feature.startswith('<'): status = 'missing'; print('PLACEHOLDER ' + feature)
    key = 'na' if status == 'n/a' else status
    if key not in counts:
        errors.append(f'{feature}: invalid status {status!r}'); continue
    counts[key] += 1
    if status == 'excluded' and not re.search(r'\b(infeasible-numeric|mutation-dependent|exception-dependent|external-dependency|platform|effect|nondeterministic|out-of-scope)\b', notes, re.I):
        errors.append(f'{feature}: excluded needs a named exclusion class in notes')
    if status != 'present':
        if status != 'n/a': print(f'{status.upper():12} {feature}: {notes}')
        continue
    if any(value.lower() in ('', '-', 'none', 'n/a') or value.startswith('<') for value in (ref, definition)):
        noev += 1; errors.append(f'{feature}: present requires an original reference and a concrete port definition')
    if gold.lower() in ('', '-', 'none') or law.lower() in ('', '-'):
        noev += 1; errors.append(f'{feature}: present requires named goldens and laws or explicit none')
    if known_cases is None:
        errors.append(f'{feature}: missing or invalid cases manifest')
    for name in [s.strip().strip('`') for s in cells[3].split(',') if s.strip()]:
        if known_cases is not None and (name not in known_cases or any(not (root / 'goldens' / (name + ext)).is_file() for ext in ('.out', '.err', '.exit'))):
            errors.append(f'{cells[0]}: missing golden evidence {name}')
    for name in [s.strip().strip('`') for s in cells[4].split(',') if s.strip() and s.strip().strip('`').lower() != 'none']:
        if known_laws is None or name not in known_laws: errors.append(f'{cells[0]}: missing or unknown law {name}')
if not seen: errors.append('no feature rows')
for error in errors: print('MALFORMED   ' + error)
verdict = 'MALFORMED' if errors else 'PARTIAL' if counts['partial'] or counts['missing'] else 'DEBT' if counts['excluded'] else 'FULL'
print(f"rows={len(seen)} present={counts['present']} partial={counts['partial']} missing={counts['missing']} excluded={counts['excluded']} n/a={counts['na']} no-evidence={noev} verdict={verdict}")
print(json.dumps(dict(rows=len(seen), **counts, no_evidence=noev, verdict=verdict)))
sys.exit(0 if verdict in ('FULL', 'DEBT') else 1)
PY
