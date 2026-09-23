#!/usr/bin/env python3
"""port-lint: scan a Bend 2 port's sources for the porting anti-patterns that the
checker does NOT refuse but that cost parity, lanes or proofs later. Each finding
names the file:line, a rule id, what to do, and the reference section to read.
Heuristic and line-based (Bend defs are one statement per line in this skill's
style); a finding is a question to answer, not a verdict.

Rules (E = error, W = warning, I = info; E/W fail the run, I only with --strict):
  PL-01 W quadratic-append       a self-recursive def passes `acc ++ ...` to itself
                                 (++ copies its left operand: O(n^2))      -> COST-MODEL "Strings"
  PL-02 I non-tail-recursion     a self-recursive def whose self-call is not the whole
                                 expression (JS-lane depth wall ~3-5e4)   -> COST-MODEL "Recursion depth"
  PL-03 E effect-under-bang      a def reachable from a bang `f!(..)` uses IO.  -> CORE-SHELL-SPLIT "seam"
  PL-04 W strict-comparator      a List.sort comparator family uses only strict <
                                 (equal keys REVERSE; must be a <=)        -> TRANSLATION-PATTERNS rule 9
  PL-05 W fast-twin-nat-unbounded a def commented "fast twin" does Nat arithmetic with no
                                 stated bound (2^48 / "bound" / "<=" in its comment) -> NUMERIC-FIDELITY
  PL-06 E unsafe-uncommented     @unsafe with no comment line directly above  -> LAWS-FROM-SPEC "unsafe count"
  PL-07 E clock-or-random-in-core IO.now / IO.random_u32 outside `main`      -> CORE-SHELL-SPLIT "Mapping"
  PL-08 W file-read-no-loop      File.read with a literal max in a non-recursive def and no
                                 File.size in the file (one read may be short) -> UNICODE-AND-ENCODINGS stdin
  PL-09 I argv-no-dashdash       IO.args() with flag literals but no "--" handling -> DECISION-TABLES "Effects"
  PL-10 W untagged-def           a def/type with no `# S<n>` clause tag above it -> RUNBOOK Phase 3 checklist
  PL-11 E fast-twin-without-law  a def named *_fast / commented "fast twin" that no law in
                                 LAWS.bend mentions                        -> LAWS-FROM-SPEC "fast == spec"
  PL-12 W length-in-loop         List.length / String.length / Map.size inside a self-recursive
                                 def (O(n^2), non-tail on JS)               -> COST-MODEL "Counts beside collections"
  PL-13 W io-try-errno           IO.try used: it exits with the errno and prints only strerror
                                 (the original's message and code are lost)  -> TRANSLATION-PATTERNS "Errors"
  PL-14 I f32-show               F32.show in a port (never for f64 output without a DISC) -> NUMERIC-FIDELITY
  PL-15 W checker-blowup-risk    U32.to_nat / Nat.read inside a law (LAWS.bend)  -> LAWS-FROM-SPEC "limit"
  PL-16 I key-order-render       Map.to_list / Map.keys / Set.to_list feeding output (key order, not
                                 insertion order)                            -> ORDER-AND-STATE
  PL-17 E clause-tag-unknown     a `# S<n>.<m>` tag names a clause the spec does not define (a def
                                 written for a behavior the spec never recorded)  -> SPEC-EXTRACTION

usage: port-lint.py <main.bend> [more .bend files] [--laws LAWS.bend] [--spec SPEC.md] [--strict] [--json-only]
  --laws     the LAWS.bend to check PL-11/PL-15 against (default: LAWS.bend beside the first file, if present)
  --spec     the spec whose clause rows (`| S<n>.<m> |`) PL-17 checks tags against (default: the one
             docs/EXISTING_*_STRUCTURE.md beside the first file's directory, if exactly one exists)
  --strict   info findings also fail the run
  --json-only  print only the JSON line
exit: 0 clean (or only infos), 1 findings, 2 usage / unreadable file.
Last stdout line: {"files","findings","errors","warnings","infos","by_rule":{..},"verdict"}
"""
import json
import os
import re
import sys
sys.dont_write_bytecode = True
from case_manifest import regular_text

RULES = {
    "PL-01": ("W", "quadratic-append", "COST-MODEL-FOR-PORTERS 'Strings: prepend and reverse'"),
    "PL-02": ("I", "non-tail-recursion", "COST-MODEL-FOR-PORTERS 'Recursion depth'"),
    "PL-03": ("E", "effect-under-bang", "CORE-SHELL-SPLIT 'The seam before the bang'"),
    "PL-04": ("W", "strict-comparator", "TRANSLATION-PATTERNS 'Twelve rules' 9"),
    "PL-05": ("W", "fast-twin-nat-unbounded", "NUMERIC-FIDELITY (Nat below 2^48 with the bound stated)"),
    "PL-06": ("E", "unsafe-uncommented", "LAWS-FROM-SPEC 'The gate and the unsafe count'"),
    "PL-07": ("E", "clock-or-random-in-core", "CORE-SHELL-SPLIT 'Mapping the original' (clock / randomness)"),
    "PL-08": ("W", "file-read-no-loop", "UNICODE-AND-ENCODINGS stdin recipe; BASE-FOR-PORTERS B.10"),
    "PL-09": ("I", "argv-no-dashdash", "DECISION-TABLES 'Effects and the shell' (--)"),
    "PL-10": ("W", "untagged-def", "RUNBOOK 'Phase 3 checklist' (S-tags)"),
    "PL-11": ("E", "fast-twin-without-law", "LAWS-FROM-SPEC 'The fast == spec law'"),
    "PL-12": ("W", "length-in-loop", "COST-MODEL-FOR-PORTERS 'Counts beside collections'"),
    "PL-13": ("W", "io-try-errno", "TRANSLATION-PATTERNS 'Errors'"),
    "PL-14": ("I", "f32-show", "NUMERIC-FIDELITY (F32 as a budgeted class); DECISION-TABLES 'prints floats'"),
    "PL-15": ("W", "checker-blowup-risk", "LAWS-FROM-SPEC 'Closed goldens as laws (and their limit)'"),
    "PL-16": ("I", "key-order-render", "ORDER-AND-STATE (insertion order as a key list beside the Map)"),
    "PL-17": ("E", "clause-tag-unknown", "SPEC-EXTRACTION (every def cites a clause the spec defines; a new behavior is a new clause first)"),
}

DEF_RE = re.compile(r"^(@unsafe\s+)?(def|type|law)\s+([A-Za-z_][\w.]*)")


def code_only(text):
    """Mask Bend comments and quoted literals, preserving offsets and lines.

    Bend's parse_skip/parse_char in bend2/bend.ts use # line comments and
    backslash-escaped single/double quoted literals. Mentioning a call inside
    either is not a call-graph edge or law evidence.
    """
    output, quote, comment, escaped = [], None, False, False
    for char in text:
        if comment:
            if char == '\n': comment = False
            output.append('\n' if char == '\n' else ' ')
        elif quote:
            output.append('\n' if char == '\n' else ' ')
            if escaped: escaped = False
            elif char == '\\': escaped = True
            elif char == quote: quote = None
        elif char == '#':
            comment = True; output.append(' ')
        elif char in "'\"":
            quote = char; output.append(' ')
        else:
            output.append(char)
    return ''.join(output)


class Block:
    def __init__(self, kind, name, line, header, unsafe):
        self.kind = kind
        self.name = name
        self.line = line
        self.header = header
        self.unsafe = unsafe
        self.body = []  # (lineno, text)
        self.comments = []  # leading comment lines (text)

    def text(self):
        return "\n".join(t for _, t in self.body)

    def calls(self):
        return set(re.findall(r"\b([A-Za-z_][\w.]*)\(", self.text()))

    def self_calls(self):
        pat = re.compile(r"(?<![\w.])" + re.escape(self.name) + r"\(")
        return [(n, t) for n, t in self.body if pat.search(t)]

    def is_recursive(self):
        return bool(self.self_calls())

    def params(self):
        m = re.match(r"^(?:@unsafe\s+)?def\s+[\w.]+\((.*)\)", self.header)
        if not m:
            return []
        inner = m.group(1)
        out = []
        for part in split_top(inner):
            part = part.strip()
            if not part:
                continue
            nm = part.split(":")[0].strip().lstrip("+-~")
            if nm:
                out.append(nm)
        return out


def split_top(s):
    """split on commas not inside <> () {}"""
    depth = 0
    cur = []
    for ch in s:
        if ch in "<({[":
            depth += 1
        elif ch in ">)}]":
            depth -= 1
        if ch == "," and depth == 0:
            yield "".join(cur)
            cur = []
        else:
            cur.append(ch)
    yield "".join(cur)


def parse(path):
    source = regular_text(path)
    lines = source.split("\n")
    syntax = code_only(source).split('\n')
    blocks = []
    pending_comments = []
    cur = None
    for i, raw in enumerate(lines, 1):
        line = raw.rstrip()
        m = DEF_RE.match(syntax[i - 1])
        if m:
            cur = Block(m.group(2), m.group(3), i, syntax[i - 1], bool(m.group(1)))
            cur.comments = pending_comments
            pending_comments = []
            blocks.append(cur)
            continue
        if line.startswith("#"):
            if cur is not None and cur.body and line.startswith("#") and not line.startswith("#!"):
                # a comment between defs belongs to the next def
                pending_comments.append(line)
                cur = None
            else:
                pending_comments.append(line)
            continue
        if line.strip() == "":
            # a blank line ends a comment block: section banners separated from the
            # next def by a blank line are not that def's comment
            pending_comments = []
            continue
        if line.startswith("import ") or line.startswith("@unsafe"):
            pending_comments = []
            continue
        if cur is not None and (line.startswith(" ") or line.startswith("\t")):
            cur.body.append((i, syntax[i - 1]))
        else:
            pending_comments = []
    return lines, blocks


def leading_comment_text(block):
    return "\n".join(block.comments)


def is_fast_twin(block):
    if re.search(r"_fast(\.|$)", block.name):
        return True
    return bool(re.search(r"fast twin", leading_comment_text(block), re.I))


def tail_position(text, name):
    """True when the self-call is the whole expression on its line."""
    stripped = text.strip()
    return stripped.startswith(name + "(") and balanced_call_is_whole(stripped, name)


def balanced_call_is_whole(s, name):
    depth = 0
    for i, ch in enumerate(s):
        if ch in "([{":
            depth += 1
        elif ch in ")]}":
            depth -= 1
            if depth == 0:
                return i == len(s) - 1
    return False


def find_law_mentions(laws_path):
    if not laws_path or not os.path.isfile(laws_path):
        return None, []
    text = regular_text(laws_path)
    # Comments and unrelated defs are not evidence that a law names a twin.
    _, blocks = parse(laws_path)
    law_text = '\n'.join(b.header + '\n' + b.text() for b in blocks if b.kind == 'law')
    # A law names a def through its module's import alias (`L.f(`, `BN.div_pow10(`, `Run.outcome(`):
    # one leading capitalized segment is the alias, whatever its name.
    names = set(re.findall(r"\b(?:[A-Z][A-Za-z0-9]*\.)?([A-Za-z_][\w.]*)\(", law_text))
    law_lines = [(i, t) for i, t in enumerate(text.split("\n"), 1)]
    return names, law_lines


def main(argv):
    if not argv or argv[0] in ("-h", "--help"):
        print(__doc__.strip())
        return 0 if argv else 2
    files, laws, spec, strict, json_only = [], None, None, False, False
    i = 0
    while i < len(argv):
        a = argv[i]
        if a in ("--laws", "--spec"):
            if i + 1 == len(argv) or argv[i + 1].startswith('--'):
                print(f'port-lint: {a} needs a path', file=sys.stderr)
                return 2
            if a == "--laws":
                laws = argv[i + 1]
            else:
                spec = argv[i + 1]
            i += 2
            continue
        if a == "--strict":
            strict = True
        elif a == "--json-only":
            json_only = True
        elif a.startswith("--"):
            print(f"port-lint: unknown option {a}", file=sys.stderr)
            return 2
        else:
            files.append(a)
        i += 1
    if not files:
        print("port-lint: no file given (see --help)", file=sys.stderr)
        return 2
    for f in files:
        if not os.path.isfile(f):
            print(f"port-lint: cannot read {f}", file=sys.stderr)
            return 2
    if laws is None:
        cand = os.path.join(os.path.dirname(os.path.abspath(files[0])), "LAWS.bend")
        if os.path.isfile(cand):
            laws = cand
    elif not os.path.isfile(laws):
        print(f'port-lint: cannot read laws file {laws}', file=sys.stderr)
        return 2
    law_names, law_lines = find_law_mentions(laws)
    if spec is None:
        docs = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(files[0]))), "docs")
        cands = sorted(f for f in (os.listdir(docs) if os.path.isdir(docs) else [])
                       if re.fullmatch(r"EXISTING_.+_STRUCTURE\.md", f))
        if len(cands) == 1:
            spec = os.path.join(docs, cands[0])
    elif not os.path.isfile(spec):
        print(f'port-lint: cannot read spec file {spec}', file=sys.stderr)
        return 2
    clauses = None
    if spec:
        clauses = set()
        for row in regular_text(spec).split("\n"):
            # a clause is a table row `| S<n>.<m> |` or a paragraph clause `**S<n>.<m> — …**`
            m = re.match(r"\|\s*(S\d+\.\d+)\s*\||\*\*(S\d+\.\d+)\b", row)
            if m:
                clauses.add(m.group(1) or m.group(2))

    findings = []

    def add(rule, path, line, msg):
        sev, short, ref = RULES[rule]
        findings.append({"rule": rule, "sev": sev, "name": short, "file": path, "line": line, "msg": msg, "read": ref})

    for path in files:
        lines, blocks = parse(path)
        text = "\n".join(lines)
        defs = {b.name: b for b in blocks if b.kind == "def"}
        # ---- PL-15 (laws only): checker blow-up risk
        if os.path.basename(path) == "LAWS.bend" or (laws and os.path.abspath(path) == os.path.abspath(laws)):
            for n, t in enumerate(lines, 1):
                if re.search(r"U32\.to_nat\(|Nat\.read\(", t) and not t.lstrip().startswith("#"):
                    add("PL-15", path, n, "U32.to_nat / Nat.read inside a law: the normalizer expands Peano Nats (minutes, then exit 137); keep closed laws in U32 or small Nats")
            continue

        # ---- PL-06 unsafe without comment
        for n, t in enumerate(lines, 1):
            if t.startswith("@unsafe"):
                prev = lines[n - 2] if n >= 2 else ""
                if not prev.startswith("#"):
                    add("PL-06", path, n, "@unsafe with no comment line directly above naming the missing measure and the bead")

        # ---- PL-13 IO.try
        for n, t in enumerate(lines, 1):
            if "IO.try(" in t and not t.lstrip().startswith("#"):
                add("PL-13", path, n, "IO.try exits with the errno and prints only strerror; match the Result and IO.die with the original's message and code")

        # ---- PL-14 F32.show
        for n, t in enumerate(lines, 1):
            if "F32.show(" in t and not t.lstrip().startswith("#"):
                add("PL-14", path, n, "F32.show prints 32-bit shortest digits; an original printing f64 needs a formatting def or a NumericWidth DISC (budget-compare.py)")

        # ---- PL-07 clock / random outside main
        for b in blocks:
            if b.kind != "def":
                continue
            for n, t in b.body:
                if re.search(r"IO\.now\(|IO\.random_u32\(", t) and b.name != "main":
                    add("PL-07", path, n, f"{b.name} reads the clock or entropy; read once in main and pass the value down (goldens cannot pin it)")

        # ---- PL-09 argv without --
        if "IO.args()" in text and re.search(r'String\.eq\([^,]+,\s*"-', text) and '"--"' not in text:
            n = next((k for k, t in enumerate(lines, 1) if "IO.args()" in t), 1)
            add("PL-09", path, n, "flags are parsed but no \"--\" handling: the original's `--` semantics (and the runtime's own --threads/--gpu) need a case")

        # ---- PL-10 untagged defs/types
        for b in blocks:
            if b.kind not in ("def", "type"):
                continue
            if b.name == "main":
                pass
            if not re.search(r"^#.*\bS\d+(\.\d+)?\b", leading_comment_text(block=b), re.M):
                add("PL-10", path, b.line, f"{b.kind} {b.name} has no `# S<n>.<m>` clause tag in the comment above it")

        # ---- per-def rules
        bangs = set(re.findall(r"\b([A-Za-z_][\w.]*)!\(", text))
        for b in blocks:
            if b.kind != "def":
                continue
            params = set(b.params())
            rec = b.is_recursive()
            if rec:
                for n, t in b.self_calls():
                    # PL-01: an argument of the self call is `<param> ++ ...` or `... ++ <param>`? left operand copy matters
                    call_args = t[t.find(b.name + "(") + len(b.name) + 1:]
                    for p in params:
                        if re.search(r"(?<![\w.])" + re.escape(p) + r"\s*\+\+", call_args):
                            add("PL-01", path, n, f"{b.name} passes `{p} ++ ...` to itself: ++ walks its left operand every iteration (quadratic); prepend and reverse once, or collect chunks and join")
                    # PL-02: non-tail
                    if not tail_position(t, b.name):
                        add("PL-02", path, n, f"{b.name} recurses in non-tail position: fine on C (2 GiB stack), a wall on the JS lane above ~3-5e4 frames; write an accumulate-then-reverse twin or record MISSING-js")
                # PL-12: length in a loop
                for n, t in b.body:
                    if re.search(r"\b(List\.length|String\.length|Map\.size|Set\.size)\(", t):
                        add("PL-12", path, n, f"{b.name} recomputes a length inside a recursive def: O(n^2) and non-tail on JS; carry the count beside the collection")
            # PL-05: fast twin with Nat arithmetic and no bound stated anywhere in the
            # file's comments (the bound usually lives on the dispatcher or the header)
            if is_fast_twin(b):
                body = b.text()
                if re.search(r"Nat\.(add|mul|sub)\(|U32\.to_nat\(", body) or re.search(r"\b1n\+", body):
                    all_comments = "\n".join(t for t in lines if t.lstrip().startswith("#"))
                    if not re.search(r"2\^48|2\*\*48|281474976710655|65536|\bbound", all_comments, re.I):
                        add("PL-05", path, b.line, f"fast twin {b.name} does Nat arithmetic and no comment in the file states the bound (2^48 / 65536 words / 'bound'): say why the sum stays below 2^48-1, near the dispatcher")
                # PL-11: no law mentions it, directly or through a fast-twin caller that a law names
                if law_names is not None:
                    covered = set()
                    def cover(name, seen):
                        if name in seen or name not in defs:
                            return
                        seen.add(name)
                        covered.add(name)
                        for c in defs[name].calls():
                            cover(c, seen)
                    for ln in law_names:
                        cover(ln, set())
                    if b.name not in covered:
                        add("PL-11", path, b.line, f"fast twin {b.name} is not named by any law in {os.path.basename(laws)} (nor called by one that is): every fast twin needs `{{fast == spec}}`")
                elif laws is None:
                    add("PL-11", path, b.line, f"fast twin {b.name}: no LAWS.bend found beside {os.path.basename(path)} (pass --laws) so no law binds it")
            # PL-08: File.read with literal max, no loop, no File.size anywhere
            for n, t in b.body:
                m = re.search(r"File\.read\(\s*\w+\s*,\s*(\d+)\s*\)", t)
                if m and not rec and "File.size(" not in text:
                    add("PL-08", path, n, f"{b.name} reads at most {m.group(1)} bytes once: a pipe or a big file returns less; loop with fuel until \"\" (stdin recipe) or File.size then File.read(size)")

        # ---- PL-03 IO under a bang (transitive)
        if bangs:
            def reaches_io(name, seen):
                if name in seen or name not in defs:
                    return None
                seen.add(name)
                b = defs[name]
                for n, t in b.body:
                    if re.search(r"\bIO\.[a-z_]+\(|\bFile\.[a-z_]+\(", t):
                        return (n, t.strip())
                for c in b.calls():
                    r = reaches_io(c, seen)
                    if r:
                        return r
                return None
            for bn in sorted(bangs):
                hit = reaches_io(bn, set())
                if hit:
                    add("PL-03", path, hit[0], f"`{bn}!(..)` reaches an effect ({hit[1][:60]}): the compiler does not refuse effects under a bang; move the seam up")

        # ---- PL-04 strict comparator in List.sort
        for m in re.finditer(r"List\.sort\(\s*~[\w.<>&, ]+,\s*~([A-Za-z_][\w.]*)", text):
            cmp_name = m.group(1)
            fam = [b for b in blocks if b.kind == "def" and (b.name == cmp_name or b.name.startswith(cmp_name + "."))]
            if not fam:
                continue
            fam_text = "\n".join(b.text() for b in fam)
            strict = bool(re.search(r"\bis_lt\(|\bis_gt\(|(?<![<>=!])\s<\s(?!=)|(?<![<>=!])\s>\s(?!=)|\bLT\{\}|\bGT\{\}", fam_text))
            nonstrict = bool(re.search(r"\bis_le\(|\bis_ge\(|\bis_eq\(|<=|>=|\bEQ\{\}", fam_text))
            if strict and not nonstrict:
                line = next((b.line for b in fam if b.name == cmp_name), fam[0].line)
                n_call = text[: m.start()].count("\n") + 1
                add("PL-04", path, line, f"comparator {cmp_name} (used by List.sort at line {n_call}) is a strict order: equal keys come out REVERSED; make it a <= and encode the original's tie-break")

        # ---- PL-17 a clause tag the spec does not define (once per tag per file)
        if clauses is not None:
            seen_tags = set()
            for n, t in enumerate(lines, 1):
                c = t.find("#")
                if c < 0:
                    continue
                for tag in re.findall(r"(?<![\w.])(S\d+\.\d+)(?![\d])", t[c:]):
                    if tag not in clauses and tag not in seen_tags:
                        seen_tags.add(tag)
                        add("PL-17", path, n, f"{tag} is not a clause of {os.path.basename(spec)}: write the clause (behavior, provenance, case) before the def that implements it, or fix the tag")

        # ---- PL-16 key-order render
        for n, t in enumerate(lines, 1):
            if re.search(r"\b(Map\.to_list|Map\.keys|Set\.to_list)\(", t) and not t.lstrip().startswith("#"):
                add("PL-16", path, n, "Map/Set iteration is key (code-point) order; if the original iterated a dict/JS Map in insertion order, carry a key list beside the Map")

    # ---- report
    order = {"E": 0, "W": 1, "I": 2}
    findings.sort(key=lambda f: (f["file"], f["line"], order[f["sev"]]))
    by_rule = {}
    for f in findings:
        by_rule[f["rule"]] = by_rule.get(f["rule"], 0) + 1
    errors = sum(1 for f in findings if f["sev"] == "E")
    warnings = sum(1 for f in findings if f["sev"] == "W")
    infos = sum(1 for f in findings if f["sev"] == "I")
    if not json_only:
        for f in findings:
            print(f"{f['file']}:{f['line']}: {f['rule']} {f['sev']} {f['name']}: {f['msg']}")
            print(f"    read: {f['read']}")
        print("--")
        print(f"port-lint: {len(files)} file(s), {len(findings)} finding(s): {errors} error(s), {warnings} warning(s), {infos} info(s)"
              + (f"; laws: {laws}" if laws else "; laws: none")
              + (f"; spec: {spec} ({len(clauses)} clauses)" if spec else "; spec: none (PL-17 off)"))
    fail = errors + warnings > 0 or (strict and infos > 0)
    verdict = "FINDINGS" if fail else "OK"
    print(json.dumps({"files": len(files), "findings": len(findings), "errors": errors, "warnings": warnings,
                      "infos": infos, "by_rule": by_rule, "laws": laws, "spec": spec, "verdict": verdict}))
    return 1 if fail else 0


if __name__ == "__main__":
    try:
        sys.exit(main(sys.argv[1:]))
    except (OSError, UnicodeError, ValueError) as exc:
        print(f'port-lint: {exc}', file=sys.stderr)
        sys.exit(2)
