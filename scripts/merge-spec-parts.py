#!/usr/bin/env python3
"""merge-spec-parts: assemble docs/spec-parts/*.md into THE SPEC.

Phase 1 extraction ran in parallel with owned sections (SPEC-EXTRACTION
"Parallel extraction"): each extractor wrote one part file. This tool places
every owned section under its `## S<n>.` heading of
docs/EXISTING_BEADS_RUST_STRUCTURE.md, in section order, without rewording a
single clause. S3, S11 and S12 are the architect's and come from
docs/spec-parts/ARCHITECT_S3_S11_S12.md. Each part's `## Handover notes` and
`## OQ proposals` are gathered into two appendices so that nothing an
extractor said is lost. The part files are the provenance and are kept.

usage: merge-spec-parts.py [--check]
  --check   build in memory and report, write nothing
exit: 0 written (or check passed), 1 a part or a section is missing, 2 usage.
"""
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
PARTS = ROOT / "docs" / "spec-parts"
SPEC = ROOT / "docs" / "EXISTING_BEADS_RUST_STRUCTURE.md"

# (section number, title, [(part file, heading regex that opens the owned block)])
LAYOUT = [
    (1, "Command-line surface", [("S1_S9.md", r"^## S1\.")]),
    (2, "Inputs", [("S2_S5a.md", r"^## S2\.")]),
    (3, "Data model", [("ARCHITECT_S3_S11_S12.md", r"^## S3\.")]),
    (4, "Algorithms (behavioral)", [("S4a_S7.md", r"^## S4\."), ("S4b.md", r"^## S4\."), ("S4c.md", r"^## S4\.")]),
    (5, "Outputs", [("S2_S5a.md", r"^## S5\."), ("S5b.md", r"^## S5\.100")]),
    (6, "Order-leak inventory", [("S6_S8_S10.md", r"^## S6\.")]),
    (7, "Numeric inventory", [("S4a_S7.md", r"^## S7\.")]),
    (8, "Effect inventory", [("S6_S8_S10.md", r"^## S8\.")]),
    (9, "Error and edge behavior", [("S1_S9.md", r"^## S9\.")]),
    (10, "Known bugs and oddities (to be reproduced, not fixed)", [("S6_S8_S10.md", r"^## S10\.")]),
    (11, "Performance characteristics of the original", [("ARCHITECT_S3_S11_S12.md", r"^## S11\.")]),
    (12, "Provenance and coverage", [("ARCHITECT_S3_S11_S12.md", r"^## S12\.")]),
]
TAIL = re.compile(r"^## (Handover notes|OQ proposals)\s*$")
TOP = re.compile(r"^## ")


def block(lines, opener):
    """The lines from the heading matching `opener` up to the next block that is
    not part of it: another `## S<other>.` section or a tail section."""
    start = next((i for i, line in enumerate(lines) if re.match(opener, line)), None)
    if start is None:
        return None
    section = re.match(r"^## S(\d+)", lines[start]).group(1)
    end = len(lines)
    for i in range(start + 1, len(lines)):
        if TAIL.match(lines[i]):
            end = i
            break
        other = re.match(r"^## S(\d+)", lines[i])
        if other and other.group(1) != section:
            end = i
            break
    body = lines[start + 1:end]
    # a part's further `## S5.120–…` headings become subsections of the one section
    return [re.sub(r"^## (S\d+\.)", r"### \1", line) for line in body]


def tail(lines, title):
    start = next((i for i, line in enumerate(lines) if line.strip() == f"## {title}"), None)
    if start is None:
        return []
    end = next((i for i in range(start + 1, len(lines)) if TOP.match(lines[i])), len(lines))
    return lines[start + 1:end]


def main(argv):
    if argv and argv[0] in ("-h", "--help"):
        print(__doc__.strip())
        return 0
    check = argv == ["--check"]
    if argv and not check:
        print(__doc__.strip(), file=sys.stderr)
        return 2
    cache, missing = {}, []
    for _, _, sources in LAYOUT:
        for name, _ in sources:
            path = PARTS / name
            if name not in cache:
                cache[name] = path.read_text(encoding="utf-8").splitlines() if path.is_file() else None
            if cache[name] is None and name not in missing:
                missing.append(name)
    if missing:
        print("merge-spec-parts: missing part file(s): " + ", ".join(missing), file=sys.stderr)
        return 1
    header = SPEC.read_text(encoding="utf-8").splitlines()
    head_end = next(i for i, line in enumerate(header) if line.startswith("Provenance:"))
    out = header[:head_end]
    out += [
        "Provenance: the original's source pinned at tag `v0.6.0` (commit `b1cfebe05437463e91a353cf2bedafac27266f5b`, tree "
        "`45cc06f56529d614d2602a327f469a8478fea17e`), read from `legacy/BEADS_RUST_v0.6.0/`; behavior from the captured goldens "
        "(`goldens/MANIFEST.txt`) and from runs of the pinned `br 0.6.0` binary in the `scripts/ws-run.sh` sandbox. Extracted 2026-09-20 by "
        "seven section-owning extractors; assembled by `scripts/merge-spec-parts.py` from `docs/spec-parts/` (the part files are kept).",
        "Coverage: see §12.", "",
    ]
    clauses = 0
    for number, title, sources in LAYOUT:
        out += [f"## S{number}. {title}", ""]
        for name, opener in sources:
            body = block(cache[name], opener)
            if body is None:
                print(f"merge-spec-parts: {name} has no block matching {opener}", file=sys.stderr)
                return 1
            out += [f"<!-- from docs/spec-parts/{name} -->"] + body + [""]
            clauses += sum(1 for line in body if re.match(r"^\| S\d+\.\d+ ", line))
    for title, anchor in (("Handover notes", "Appendix A. Handover notes, as the extractors wrote them"),
                          ("OQ proposals", "Appendix B. OQ proposals, as the extractors wrote them (registered in docs/OPEN_QUESTIONS.md)")):
        out += [f"## {anchor}", ""]
        for name in sorted(cache):
            got = tail(cache[name], title)
            if got:
                out += [f"### from docs/spec-parts/{name}", ""] + got + [""]
    text = "\n".join(out).rstrip("\n") + "\n"
    print(f"merge-spec-parts: {clauses} clauses from {len(cache)} part files, {len(text.splitlines())} lines" + (" (check only)" if check else ""))
    if not check:
        SPEC.write_text(text, encoding="utf-8")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
