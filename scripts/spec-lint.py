#!/usr/bin/env python3
"""spec-lint: check a port's spec (docs/EXISTING_<X>_STRUCTURE.md) against
its corpus (goldens/cases.tsv) the way the self-containment review wants:
  - sections S1..S12 present (S6 order leaks, S7 numerics, S8 effects are
    the ones extraction forgets; each must have at least one row);
  - every clause row (`| S<n>.<m> | ...`) carries provenance (`:<line>` or
    `file:line`) and names at least one case that exists in cases.tsv, or
    says "(case to add" / "withdrawn";
  - every case in cases.tsv is cited by at least one clause (a case no
    clause explains is an unexplained behavior);
  - no clause contains code-shaped text (a `def `, `for `, `if ` with a
    colon) — the spec says WHAT, not HOW;
  - forbidden words in the spec ("probably", "should", "TODO" outside an OQ pointer).
usage: spec-lint.py <EXISTING_X_STRUCTURE.md> <cases.tsv>
exit: 0 clean, 1 findings (each printed with the clause id), 2 usage.
"""
import re
import sys
sys.dont_write_bytecode = True
from case_manifest import cases as read_cases, regular_text
from markdown_evidence import visible_lines, split_row


def main() -> int:
    if len(sys.argv) != 3 or sys.argv[1] in ("-h", "--help"):
        print(__doc__.strip())
        return 0 if len(sys.argv) == 2 and sys.argv[1] in ('-h', '--help') else 2
    spec_path, cases_path = sys.argv[1], sys.argv[2]
    spec = '\n'.join(visible_lines(regular_text(spec_path)))
    cases = [row[0] for row in read_cases(cases_path)]
    findings = []
    if not cases: findings.append('corpus: no cases found')
    # sections
    for n in range(1, 13):
        # ubs:ignore[py.security.ldap-injection] Python re.search over Markdown; no LDAP client or directory sink exists here.
        if not re.search(rf"^## S{n}\.", spec, re.M):
            findings.append(f"S{n}: section heading `## S{n}.` missing")
    for n, what in ((6, "order-leak inventory"), (7, "numeric inventory"), (8, "effect inventory")):
        # ubs:ignore[py.security.ldap-injection] Python regex with a fixed numeric section ID, not a directory query.
        sec = re.search(rf"^## S{n}\..*?(?=^## S|\Z)", spec, re.M | re.S)
        if sec and not any(re.fullmatch(rf'S{n}\.\d+', cells[0]) for line in sec.group(0).splitlines() if (cells := split_row(line))):
            findings.append(f"S{n}: the {what} has no rows (S{n}.1 …)")
    # clause rows
    clause_rows = [(cells[0], ' | '.join(cells[1:])) for line in spec.splitlines()
                   if (cells := split_row(line, unescape=True)) and re.fullmatch(r'S\d+\.\d+', cells[0])]
    if not clause_rows: findings.append('spec: no clause rows found')
    cited = set()
    seen = set()
    for cid, rest in clause_rows:
        if cid in seen: findings.append(f'{cid}: duplicate clause ID')
        seen.add(cid)
        text = rest
        if not re.search(r"(:\d+|\w+\.\w+:\d+|whole file|withdrawn)", text):
            findings.append(f"{cid}: no provenance (`file:line` or `:line`)")
        names = {c for c in cases if re.search(rf"(?<![\w-]){re.escape(c)}(?![\w-])", text)}
        if re.search(r'(?:^|\|)\s*all\s*(?:\||$)|\ball cases\b', text): names.update(cases)
        for prefix in re.findall(r'\b([A-Za-z0-9_]+)\*', text):
            names.update(c for c in cases if c.startswith(prefix))
        cited |= names
        if not names and not re.search(r"\(case to add|withdrawn", text):
            findings.append(f"{cid}: names no golden case (add one, or write '(case to add: <name>)')")
        if re.search(r"\b(def |for \w+ in |if \w.*:$|while .*:$)", text):
            findings.append(f"{cid}: code-shaped text in a clause (WHAT, not HOW)")
    for c in cases:
        if c not in cited:
            findings.append(f"case {c}: cited by no clause (an unexplained behavior)")
    for w in ("probably", "should be", "roughly"):
        for m in re.finditer(rf"\b{w}\b", spec, re.I):
            ln = spec.count("\n", 0, m.start()) + 1
            findings.append(f"line {ln}: forbidden word '{w}' in a spec")
    for m in re.finditer(r"\bTODO\b", spec):
        ln = spec.count("\n", 0, m.start()) + 1
        # ubs:ignore[py.security.ldap-injection] Search a Markdown substring for an OQ identifier; no LDAP API is invoked.
        if not re.search(r"OQ-\d+", spec[max(0, m.start() - 200): m.end() + 200]):
            findings.append(f"line {ln}: TODO without an OQ pointer")
    print(f"spec-lint: {len(clause_rows)} clauses, {len(cases)} cases, {len(cited)} cases cited, {len(findings)} finding(s)")
    for f_ in findings:
        print(f"  - {f_}")
    return 1 if findings else 0


if __name__ == "__main__":
    try:
        sys.exit(main())
    except (OSError, UnicodeError, ValueError) as exc:
        print(f'spec-lint: {exc}', file=sys.stderr)
        sys.exit(2)
