#!/usr/bin/env bash
# state-check: lint docs/PORT_STATE.md the way the resume protocol needs it:
# a "Last gate outputs" table with proofs, lanes and parity rows whose result
# cells are non-empty and look like pasted output (a JSON object, "All terms
# check", or "rows=…verdict=…"); a "Next action" section whose first
# non-blank line is executable (starts with a command, a script path, a
# backtick, "STOPPED:" or an S<n>.<m> clause); a phase row; no forbidden
# words ("should", "later", "TODO", "probably", "roughly", "flaky",
# "usually passes") outside the round-history table.
#
# usage: state-check.sh [docs/PORT_STATE.md]
# exit: 0 OK, 1 findings (printed), 2 usage.
set -uo pipefail
usage() { sed -n '2,/^set -/p' "$0" | sed '$d' | sed 's/^# \{0,1\}//'; }
[[ "${1:-}" == "--help" || "${1:-}" == "-h" ]] && { usage; exit 0; }
F="${1:-docs/PORT_STATE.md}"
[[ $# -le 1 ]] || { usage >&2; exit 2; }
[[ -f "$F" ]] || { echo "error: $F not found" >&2; usage >&2; exit 2; }
python3 -B - "$F" "$(dirname "$0")" <<'PY'
import contextlib, importlib.util, io, json, re, sys
from pathlib import Path
sys.path.insert(0, sys.argv[2])
from markdown_evidence import visible_lines, split_row
p = sys.argv[1]; txt = '\n'.join(visible_lines(Path(p).read_text(encoding="utf-8"))); f = []
# The machine twin owns required-section/table validation, so the resume
# check cannot accept a malformed state that state-json rejects.
spec = importlib.util.spec_from_file_location('state_json', Path(sys.argv[2]) / 'state-json.py')
module = importlib.util.module_from_spec(spec); spec.loader.exec_module(module)
captured = io.StringIO()
with contextlib.redirect_stdout(captured):
    result = module.main([p])
if result:
    summary = json.loads(captured.getvalue().splitlines()[-1])
    f.append('state-json: ' + '; '.join(summary['missing'] + summary['placeholders']))
if not re.search(r"^\|\s*phase\s*\|\s*\S", txt, re.M | re.I): f.append("no `| phase | … |` row")
if not re.search(r"^\|\s*bend\s*\|\s*\S", txt, re.M | re.I): f.append("no `| bend | … |` row (the Bend version the gate lines were made under; VERSION-DRIFT)")
sec = re.search(r"^## Last gate outputs\b.*?(?=^## |\Z)", txt, re.M | re.S | re.I)
if not sec: f.append("no `## Last gate outputs` section")
else:
    body = sec.group(0)
    for gate in ("proofs", "lanes", "parity"):
        rows = [cells for line in body.splitlines() if (cells := split_row(line, unescape=True)) and cells[0].lower() == gate]
        if len(rows) != 1 or len(rows[0]) != 4: f.append(f"gate row `{gate}` missing or ambiguous"); continue
        res = rows[0][2].strip().strip('`')
        if not res or re.match(r"^`?<", res): f.append(f"gate `{gate}`: result cell empty or a template placeholder")
        elif not module.verdict_of(rows[0][2], module.try_json(rows[0][2])):
            f.append(f"gate `{gate}`: result does not look like pasted output: {res[:60]!r}")
na = re.search(r"^## Next action\b.*?\n(.*?)(?=^## |\Z)", txt, re.M | re.S | re.I)
if not na: f.append("no `## Next action` section")
else:
    first = next((l.strip() for l in na.group(1).split("\n") if l.strip()), "")
    if not first: f.append("next action is empty")
    elif re.match(r"^`?<", first): f.append("next action is still the template placeholder")
    elif not re.match(r"^(`|[./$]|scripts/|bend |STOPPED:|S\d+\.\d+|Create |Add |Run |rg |cd |bun |python3 |git )", first):
        f.append(f"next action is not executable-looking: {first[:70]!r}")
    if re.search(r"\b(should|later|probably|maybe)\b", first, re.I): f.append("next action contains an intention word")
rounds = re.search(r"^## Find-fix rounds\b.*?(?=^## |\Z)", txt, re.M | re.S | re.I)
scan = txt.replace(rounds.group(0), "") if rounds else txt
for w in ("should", "later", "TODO", "probably", "roughly", "flaky", "usually passes"):
    for m in re.finditer(rf"\b{re.escape(w)}\b", scan, re.I):
        ctx = scan[max(0, m.start()-40): m.end()+20].replace("\n", " ")
        if re.search(r"(never|forbidden|not|no \"|\"|`)", ctx, re.I) and w.lower() in ("should", "later"):  # quoted or negated mentions
            continue
        ln = scan.count("\n", 0, m.start()) + 1
        f.append(f"line {ln}: forbidden word '{w}': …{ctx.strip()}…")
print(f"state-check: {len(f)} finding(s)")
for x in f: print(f"  - {x}")
sys.exit(1 if f else 0)
PY
