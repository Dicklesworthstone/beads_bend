#!/usr/bin/env python3
"""arch-lint: the Phase 2 gate as a script instead of prose. Reads the spec
(docs/EXISTING_<X>_STRUCTURE.md), the architecture (docs/PROPOSED_ARCHITECTURE.md),
the numeric plan (docs/NUMERIC_PLAN.md) and the laws draft (port/LAWS.bend)
and checks what "every clause has a def home and an evidence kind" means:
  - every spec clause S<n>.<m> in S1–S5, S8, S9 is named in an architecture
    table (exactly, by a range `S4.2–S4.3`, or by its bare section `S4`);
  - the module map's twin column is one of data | spec | fast | shell
    (a pure `dispatcher` counts as spec) and holds no `<placeholder>`;
  - every core/shell split row names an evidence kind (law / golden / proof);
  - every S6 clause has a carrier row in the order plan;
  - every S7 clause has a NUMERIC_PLAN inventory row with a Bend width
    (U32 / Nat / F32 / two-word / fixed) and a proof or a golden;
  - the loop-measures table has rows and every measure cell is filled
    (a finding when S4 reads like loops and the table is empty);
  - a seam is named (the word "seam") and a kill-switch is named;
  - every `fast` twin in the module map has a law in LAWS.bend whose
    comment or name mentions the twin's clause or def and says "fast"/"spec".
S10 (oddities), S11 (performance) and S12 (provenance) are not def-homed here:
S10 is judged by DISCREPANCIES.md, S7 by the numeric plan.

usage: arch-lint.py [--root DIR] [--spec F] [--arch F] [--numeric F] [--laws F] [--ignore S2.5,S9.3] [--json]
  --root    the port root (default: cwd); the four files are found under docs/ and port/
  --ignore  clause ids accepted as unhomed (an accepted gap: state the reason in PORT_STATE)
exit: 0 PASS, 1 findings (each printed), 2 usage or a file missing.
Last stdout line: {"clauses","homed","numeric_rows","s6_rows","fast_twins","missing":[..],"findings","verdict"}
"""
import argparse
import glob
import json
import os
import re
import sys
sys.dont_write_bytecode = True
from case_manifest import regular_text
from markdown_evidence import visible_lines, split_row

ID = re.compile(r"\bS(\d+)\.(\d+)\b")
RANGE = re.compile(r"\bS(\d+)\.(\d+)\s*[–\-]\s*S?(\d+)?\.?(\d+)\b")
BARE = re.compile(r"\bS(\d+)\b(?!\.)")
# a template placeholder is `<word>` not glued to an identifier (Bend generics `Map<&2, Nat>` are)
PLACEHOLDER = re.compile(r"(?<![A-Za-z0-9_])<[^<>`]{1,60}>")


def read_text(path: str) -> str:
    return regular_text(path)
HOMED_SECTIONS = {1, 2, 3, 4, 5, 8, 9}
WIDTH = re.compile(r"\b(U32|Nat|F32|two[- ]word|2\s*[×x]\s*U32|fixed[- ]point|pair)\b", re.I)
LOOPY = re.compile(r"\b(for each|for every|for [a-z_]+ (from|in)|while|until|repeat|times|iterat|per line|each (line|accepted|element)|loop)\b", re.I)


def tables(md: str):
    """Yield (heading, header_cells, rows) for every Markdown table, with the nearest preceding heading."""
    heading, cur = "", []
    for ln in list(visible_lines(md)) + [""]:
        cells = split_row(ln, unescape=True)
        if cells is not None:
            cur.append(cells); continue
        if cur:
            header = cur[0]; rows = [r for r in cur[1:] if not set("".join(r)) <= set("-: ")]
            yield heading, header, rows
            cur = []
        if ln.startswith("#"):
            heading = ln.strip("# ").strip()


def col(header, *names):
    for i, h in enumerate(header):
        hl = h.lower()
        if any(n in hl for n in names): return i
    return None


def covers(text: str, n: int, m: int) -> bool:
    for a, b in ID.findall(text):
        if int(a) == n and int(b) == m: return True
    for a, b, c, d in RANGE.findall(text):
        a, b, d = int(a), int(b), int(d); c = int(c) if c else a
        if a == n and c == n and b <= m <= d: return True
    for a in BARE.findall(text):
        if int(a) == n: return True
    return False


def main() -> int:
    ap = argparse.ArgumentParser(add_help=False)
    ap.add_argument("--root", default="."); ap.add_argument("--spec"); ap.add_argument("--arch"); ap.add_argument("--numeric"); ap.add_argument("--laws")
    ap.add_argument("--ignore", default=""); ap.add_argument("--json", action="store_true"); ap.add_argument("-h", "--help", action="store_true")
    a = ap.parse_args()
    if a.help: print(__doc__.strip()); return 0
    root = a.root
    spec = a.spec or next(iter(sorted(glob.glob(os.path.join(root, "docs", "EXISTING_*STRUCTURE.md")))), None)
    arch = a.arch or os.path.join(root, "docs", "PROPOSED_ARCHITECTURE.md")
    numeric = a.numeric or os.path.join(root, "docs", "NUMERIC_PLAN.md")
    laws = a.laws or os.path.join(root, "port", "LAWS.bend")
    for label, p in (("spec", spec), ("architecture", arch), ("numeric plan", numeric), ("laws", laws)):
        if not p or not os.path.isfile(p):
            print(f"error: {label} file not found ({p})", file=sys.stderr); print(__doc__.strip().split("usage:")[1].split("\n")[0], file=sys.stderr); return 2
    S, A, N = ('\n'.join(visible_lines(read_text(p))) for p in (spec, arch, numeric))
    L = read_text(laws)
    ignore = {x.strip() for x in a.ignore.split(",") if x.strip()}
    f = []

    # spec clauses
    clauses = []
    for line in S.splitlines():
        cells = split_row(line, unescape=True)
        m = re.fullmatch(r'S(\d+)\.(\d+)', cells[0]) if cells else None
        if not m: continue
        cid, n, k, rest = cells[0], int(m.group(1)), int(m.group(2)), ' | '.join(cells[1:])
        if any(prior[0] == cid for prior in clauses): f.append(f'{cid}: duplicate spec clause')
        if re.search(r"\bwithdrawn\b", rest, re.I): continue
        clauses.append((cid, n, k, rest))
    if not clauses: f.append("spec: no clause rows `| S<n>.<m> |` found")
    arch_tables = list(tables(A))
    # A mention in a law-plan/status table is not a definition home.
    homes = []
    for heading, header, rows in arch_tables:
        if 'module map' in heading.lower(): ci, di = col(header, 'implements', 'clause'), 0
        elif 'split' in heading.lower(): ci, di = col(header, 'clause'), col(header, 'lives in')
        else: continue
        if ci is None or di is None: continue
        homes.extend(row[ci] for row in rows if len(row) == len(header) and row[di].strip() not in ('', '-', '—', 'none') and not PLACEHOLDER.search(row[di]))
    arch_cells = ' '.join(homes)
    homed, missing = 0, []
    for cid, n, k, _ in clauses:
        if n not in HOMED_SECTIONS: continue
        if covers(arch_cells, n, k): homed += 1
        elif cid in ignore: homed += 1
        else: missing.append(cid)
    need = sum(1 for _, n, _, _ in clauses if n in HOMED_SECTIONS)
    for cid in missing: f.append(f"{cid}: no def home in any PROPOSED_ARCHITECTURE table (name it in the split table or the module map)")

    # module map: twin kinds, placeholders, fast twins
    fast_rows = []
    mm = [(h, rows) for hd, h, rows in arch_tables if "module map" in hd.lower()]
    if not mm: f.append("architecture: no `Module map` table")
    for h, rows in mm:
        ti = col(h, "twin"); ii = col(h, "implements", "clause")
        if not rows: f.append('module map: no rows')
        if ti is None: f.append("module map: no `twin` column"); continue
        for r in rows:
            if len(r) != len(h): f.append('module map: malformed row'); continue
            if not r[0].strip(): f.append('module map: empty def/type home')
            name, twin = r[0], r[ti].lower()
            if PLACEHOLDER.search(name) or PLACEHOLDER.search(r[ti]) or (ii is not None and len(r) > ii and PLACEHOLDER.search(r[ii])):
                f.append(f"module map: template placeholder in row `{name}`"); continue
            if ii is not None and len(r) > ii and re.search(r"\bS\d+\.n\b", r[ii]): f.append(f"module map: row `{name}` implements `S<n>.n` (a template pattern, not a clause)")
            kinds = {k for k in ("data", "spec", "fast", "shell", "dispatcher") if re.search(rf"\b{k}\b", twin)}
            if not kinds: f.append(f"module map: row `{name}` twin kind `{r[ti]}` is none of data | spec | fast | shell")
            if "fast" in kinds:
                fast_rows.append((name, r[ii] if ii is not None and len(r) > ii else ""))
    # laws: every fast twin has a law
    blocks = re.split(r"\n(?=law\s+[A-Za-z_][\w.]*\s*:)", "\n" + L)
    law_blocks = []
    for i, b in enumerate(blocks):
        m = re.match(r"\s*law\s+([\w.]+)\s*:", b)
        if not m: continue
        pre = blocks[i - 1] if i else ""
        comment = "\n".join(ln for ln in pre.split("\n")[::-1][:12] if ln.startswith("#"))
        body = '\n'.join(line for line in b.splitlines()[1:] if line.strip() and not line.lstrip().startswith('#'))
        if body and '==' in b:
            law_blocks.append((m.group(1), comment + "\n" + b))
    for name, impl in fast_rows:
        defs = re.findall(r"`([^`]+)`", name) or [name]
        cids = [f"S{a_}.{b_}" for a_, b_ in ID.findall(impl)]
        ok = False
        for lname, text in law_blocks:
            if not re.search(r"fast|spec", text + lname, re.I): continue
            if any(c in text for c in cids) or any(re.search(rf"\b{re.escape(d.split('.')[0])}\b", text) for d in defs): ok = True; break
        if not ok: f.append(f"fast twin {name} ({', '.join(cids) or 'no clause'}) has no `fast == spec` law in LAWS.bend mentioning its clause or def")
    if re.search(r"\bS0\.1\b|core_fast", L) and fast_rows: f.append("LAWS.bend still carries the template's `S0.1` / `core_fast` law")

    # split table evidence kinds
    split = [(h, rows) for hd, h, rows in arch_tables if "split" in hd.lower()]
    if not split: f.append("architecture: no `Core / shell split` table")
    for h, rows in split:
        ei = col(h, "evidence")
        if not rows: f.append('split table: no rows')
        if ei is None: f.append("split table: no `evidence` column"); continue
        for r in rows:
            if len(r) != len(h): f.append('split table: malformed row'); continue
            if not re.search(r"law|golden|proof|closed", r[ei], re.I): f.append(f"split row `{r[0][:50]}`: evidence kind names neither law nor golden")

    # S6 carriers
    s6 = [cid for cid, n, _, _ in clauses if n == 6]
    order = [(h, rows) for hd, h, rows in arch_tables if "order" in hd.lower()]
    order_text = " ".join(c for _, rows in order for r in rows for c in r)
    s6_rows = sum(len(rows) for _, rows in order)
    for cid in s6:
        n, k = map(int, cid[1:].split('.'))
        if not covers(order_text, n, k) and not (cid in ignore): f.append(f"{cid}: no carrier row in the order plan (PROPOSED_ARCHITECTURE §6)")
    for _, rows in order:
        for r in rows:
            if any(PLACEHOLDER.search(c) for c in r): f.append(f"order plan: template placeholder in row `{r[0][:40]}`")

    # S7 numeric rows
    s7 = [cid for cid, n, _, _ in clauses if n == 7]
    inv = [(h, rows) for hd, h, rows in tables(N) if any("s7" in c.lower() for c in h)]
    numeric_rows = sum(len(rows) for _, rows in inv)
    if not inv: f.append("numeric plan: no inventory table with an `S7.n` column")
    for cid in s7:
        hit = None
        for h, rows in inv:
            for r in rows:
                if r and r[0].strip() == cid: hit = (h, r)
        if not hit: f.append(f"{cid}: no NUMERIC_PLAN inventory row"); continue
        h, r = hit
        ri = col(h, "bend rep", "rep"); pi = col(h, "proof"); gi = col(h, "golden")
        rep = r[ri] if ri is not None and len(r) > ri else ""
        if not WIDTH.search(rep): f.append(f"{cid}: Bend representation `{rep}` is none of U32 | Nat | F32 | two-word | fixed point")
        empty = lambda x: x.strip() in ("", "—", "-", "none", "n/a") or PLACEHOLDER.search(x)  # noqa: E731
        pv = r[pi] if pi is not None and len(r) > pi else ""; gv = r[gi] if gi is not None and len(r) > gi else ""
        if empty(pv) and empty(gv): f.append(f"{cid}: neither a proof nor a golden named")
    for hd, h, rows in tables(N):
        if "output class" in hd.lower():
            for r in rows:
                if any(PLACEHOLDER.search(c) for c in r): f.append(f"numeric plan: template placeholder in output classes row `{r[0][:30]}`")

    # loop measures
    loops = [(h, rows) for hd, h, rows in arch_tables if "measure" in hd.lower() or col(h, "measure") is not None]
    loop_rows = sum(len(rows) for _, rows in loops)
    s4_loopy = sum(1 for _, n, _, rest in clauses if n == 4 and LOOPY.search(rest))
    if loop_rows == 0 and s4_loopy: f.append(f"loop measures: {s4_loopy} S4 clause(s) read like loops and the measures table is empty")
    for h, rows in loops:
        mi = col(h, "measure")
        if mi is None: continue
        for r in rows:
            if len(r) <= mi or not r[mi].strip() or PLACEHOLDER.search(r[mi]): f.append(f"loop measures: row `{r[0][:40]}` has no measure")

    # seam and kill-switch
    if not re.search(r"\bseam\b", A, re.I): f.append("architecture: no seam named (§7: where the shell stops and the bang begins)")
    if not re.search(r"kill[- ]switch|_SPEC=1", A, re.I): f.append("architecture: no kill-switch named (§9)")

    summary = {"clauses": need, "homed": homed, "numeric_rows": numeric_rows, "s6_rows": s6_rows, "fast_twins": len(fast_rows),
               "missing": missing, "findings": len(f), "verdict": "PASS" if not f else "FAIL"}
    if not a.json:
        print(f"arch-lint: {len(f)} finding(s) — clauses {need}, homed {homed}, numeric rows {numeric_rows}, S6 rows {s6_rows}, fast twins {len(fast_rows)}")
        for x in f: print(f"  - {x}")
    print(json.dumps(summary))
    return 0 if not f else 1


if __name__ == "__main__":
    try:
        sys.exit(main())
    except (OSError, UnicodeError, ValueError) as exc:
        print(f'arch-lint: {exc}', file=sys.stderr)
        sys.exit(2)
