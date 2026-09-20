#!/usr/bin/env python3
"""state-json: emit a machine-readable twin of docs/PORT_STATE.md so agents and
tools read the phase, tier, gate lines, open items, rounds and the next action
without parsing Markdown. Nothing is inferred: every field is the cell text (JSON
cells are parsed into objects when they parse). The Markdown stays the human
document; the JSON is derived from it and never edited by hand.

Reads the template's sections by heading (case-insensitive prefix match):
  "Where we are"        -> phase, tier, last_updated        (| field | value | table)
  "Last gate outputs"   -> gates[{gate, command, result, result_json?, date}]
  "Open items"          -> open_items[{id, what, blocks, owner}]
  "Find-fix rounds"     -> rounds[{round, lens, new_genuine_findings, fixed, clean, date}]
  "Next action"         -> next_action (first non-blank, non-comment line after the heading)
Derived: phase_number (the leading digit of the phase cell, -1 for the fit screen),
gate_verdicts {gate: verdict} pulled from JSON results or "verdict=X"/"All terms check"
text, rounds_total, rounds_clean, missing (sections or cells not found).

usage: state-json.py [docs/PORT_STATE.md] [--out docs/PORT_STATE.json] [--check]
  --out    write the JSON there (pretty-printed) in addition to the summary line
  --check  do not write; exit 1 when --out exists and differs from what would be written,
           or when the state is MALFORMED (missing sections)
exit: 0 OK, 1 MALFORMED (a required section is missing), PLACEHOLDERS (a gate result or the
      next action is still a template `<...>`) or --check drift, 2 usage.
Last stdout line: {"file","phase","phase_number","tier","gates","rounds_total","rounds_clean",
                   "next_action","missing":[..],"placeholders":[..],"out","drift","verdict"}
"""
import json
import math
import os
import re
import sys
sys.dont_write_bytecode = True
from case_manifest import regular_text
from markdown_evidence import visible_lines, split_row

REQUIRED = ["Where we are", "Last gate outputs", "Next action"]
OPTIONAL = ["Open items", "Find-fix rounds"]


def sections(text):
    """heading -> list of lines until the next heading of the same or higher level"""
    out, active = [], []
    for line in visible_lines(text):
        m = re.match(r"^(#{1,6})\s+(.*)", line)
        if m:
            level = len(m.group(1))
            active = [(depth, body) for depth, body in active if depth < level]
            for _, body in active:
                body.append(line)
            body = []
            out.append((m.group(2).strip(), body))
            active.append((level, body))
            continue
        for _, body in active:
            body.append(line)
    return out


def find_section(secs, prefix):
    for h, body in secs:
        if h.lower().startswith(prefix.lower()):
            return h, body
    return None, None


def table(body):
    rows = []
    header = None
    for line in body:
        cells = split_row(line, unescape=True)
        if cells is None:
            if header is not None and rows:
                break
            continue
        if header is None:
            header = [c.lower() for c in cells]
            continue
        if all(re.fullmatch(r":?-{3,}:?", c) for c in cells):
            continue
        rows.append(cells)
    return header, rows


def strip_code(s):
    s = s.strip()
    if s.startswith("`") and s.endswith("`") and len(s) >= 2:
        return s[1:-1]
    return s


def try_json(s):
    s2 = s.strip()
    quoted = s2.startswith('`')
    if quoted: s2 = s2[1:]
    if not s2.startswith('{'):
        return None
    def no_constant(value):
        raise ValueError(f'non-finite JSON constant {value}')
    def unique(pairs):
        result = {}
        for key, value in pairs:
            if key in result: raise ValueError(f'duplicate JSON key {key}')
            result[key] = value
        return result
    def finite(value):
        number = float(value)
        if not math.isfinite(number): raise ValueError('non-finite JSON number')
        return number
    try:
        value, end = json.JSONDecoder(parse_constant=no_constant, parse_float=finite, object_pairs_hook=unique).raw_decode(s2)
        suffix = s2[end:]
        if quoted:
            if not suffix.startswith('`'): return None
            suffix = suffix[1:]
        if suffix.strip() and not re.fullmatch(r'\s*\(sha [0-9a-f]{7,40}\)\s*', suffix): return None
        return value if isinstance(value, dict) else None
    except ValueError:
        return None


def verdict_of(result_text, result_json):
    if isinstance(result_json, dict):
        value = result_json.get('verdict')
        return value if isinstance(value, str) and value.strip() else None
    m = re.fullmatch(r'`?rows=\d+\s+[^\n]*\bverdict=([A-Z_]+)`?(?:\s*\([^\n]*\))?', result_text.strip())
    if m:
        return m.group(1)
    plain = strip_code(result_text).strip()
    if plain.startswith('BLOCKER:') and plain[len('BLOCKER:'):].strip():
        return 'BLOCKED'
    if re.match(r'^`?All terms check(?:, with [0-9]+ unsafe annotations?)?\.(?:`?(?:\s*\([^\n]*\))?\s*)$', plain):
        m2 = re.search(r"with (\d+) unsafe", result_text)
        return "GREEN" if not m2 else f"GREEN_UNSAFE_{m2.group(1)}"
    direct = re.fullmatch(r'(PASS|FAIL|MISSING|RED|GREEN|FULL|PARTIAL|DEBT|STABLE|UNSTABLE|SAME|DRIFT|INCONCLUSIVE|NOT_RUN)(?::\s+[^\n]+|\s+\([^\n]*\))?', plain)
    if direct:
        return direct.group(1)
    return None


def main(argv):
    if argv and argv[0] in ("-h", "--help"):
        print(__doc__.strip())
        return 0
    path = "docs/PORT_STATE.md"
    out = None
    check = False
    i = 0
    while i < len(argv):
        a = argv[i]
        if a == "--out":
            out = argv[i + 1] if i + 1 < len(argv) else None
            if out is None or out.startswith('--'):
                print("state-json: --out needs a path", file=sys.stderr)
                return 2
            i += 2
            continue
        if a == "--check":
            check = True
        elif a.startswith("--"):
            print(f"state-json: unknown option {a}", file=sys.stderr)
            return 2
        else:
            path = a
        i += 1
    if not os.path.isfile(path):
        print(f"state-json: cannot read {path}", file=sys.stderr)
        return 2
    if out and (os.path.realpath(out) == os.path.realpath(path) or
                (os.path.exists(out) and os.path.samefile(out, path))):
        print('state-json: --out must differ from the Markdown source', file=sys.stderr)
        return 2
    if out and (os.path.islink(out) or (os.path.exists(out) and
                (not os.path.isfile(out) or os.stat(out).st_nlink != 1))):
        print('state-json: --out must be a single-link regular file or a new path, not a symlink or special file', file=sys.stderr)
        return 2
    text = regular_text(path)
    secs = sections(text)
    missing = [f'ambiguous section: {prefix}' for prefix in REQUIRED + OPTIONAL
               if sum(h.lower().startswith(prefix.lower()) for h, _ in secs) > 1]
    state = {"source": path}

    # where we are
    h, body = find_section(secs, "Where we are")
    phase = tier = updated = None
    if body is None:
        missing.append("Where we are")
    else:
        header, rows = table(body)
        if header != ['field', 'value']:
            missing.append('Where we are: expected field/value table')
        fields_seen = set()
        for r in rows:
            if len(r) != 2:
                missing.append('Where we are: malformed row')
                continue
            if len(r) >= 2:
                k = r[0].lower()
                if k in fields_seen:
                    missing.append(f'Where we are: duplicate {k}')
                fields_seen.add(k)
                if k == "phase":
                    phase = r[1]
                elif k == "tier":
                    tier = r[1]
                elif k.startswith("last updated"):
                    updated = strip_code(r[1])
        if phase is None:
            missing.append("Where we are: phase")
        if tier is None:
            missing.append("Where we are: tier")
    state["phase"] = phase
    pm = re.match(r"\s*(−1|-1|[0-6])(?=\s|$)", strip_code(phase or ""))
    state["phase_number"] = (-1 if pm and pm.group(1) in ("−1", "-1") else int(pm.group(1))) if pm else None
    state["tier"] = tier
    tm = re.fullmatch(r"T([123])", strip_code(tier or ""))
    state["tier_number"] = int(tm.group(1)) if tm else None
    state["last_updated"] = updated
    if pm is None:
        missing.append('Where we are: phase must start with -1 or 0..6')
    if tm is None:
        missing.append('Where we are: tier must be T1, T2 or T3')

    # gates
    h, body = find_section(secs, "Last gate outputs")
    gates = []
    if body is None:
        missing.append("Last gate outputs")
    else:
        header, rows = table(body)
        if header != ['gate', 'command', 'result', 'date']:
            missing.append('Last gate outputs: expected gate/command/result/date table')
        gate_names = set()
        for r in rows:
            if len(r) != 4 or not all(r[:3]):
                missing.append('Last gate outputs: malformed or empty row')
                continue
            name = r[0].lower()
            if name in gate_names:
                missing.append(f'Last gate outputs: duplicate {name}')
            gate_names.add(name)
            g = {"gate": name, "command": strip_code(r[1]), "result": r[2], "date": r[3]}
            j = try_json(r[2])
            if j is not None:
                g["result_json"] = j
            elif strip_code(r[2]).lstrip('`').startswith('{'):
                missing.append(f'Last gate outputs: invalid JSON for {name}')
            v = verdict_of(r[2], j)
            if v:
                g["verdict"] = v
            else:
                missing.append(f'Last gate outputs: no recognized verdict for {name}')
            if re.fullmatch(r"<[^>]*>|", strip_code(r[2])):
                g["placeholder"] = True
            gates.append(g)
        for name in ('proofs', 'lanes', 'parity'):
            if name not in gate_names:
                missing.append(f'Last gate outputs: missing {name}')
    state["gates"] = gates
    state["gate_verdicts"] = {g["gate"]: g.get("verdict") for g in gates}

    # open items
    h, body = find_section(secs, "Open items")
    items = []
    if body is not None:
        header, rows = table(body)
        for r in rows:
            if len(r) >= 2 and r[0].strip() and not re.fullmatch(r"[A-Z]+-`?<n>`?.*", r[0]):
                items.append({"id": strip_code(r[0]), "what": r[1], "blocks": r[2] if len(r) > 2 else "", "owner": r[3] if len(r) > 3 else ""})
    state["open_items"] = items

    # rounds
    h, body = find_section(secs, "Find-fix rounds")
    rounds = []
    if body is not None:
        header, rows = table(body)
        for r in rows:
            if len(r) >= 5 and r[0].strip():
                clean_cell = r[4].strip().lower()
                clean_value = re.fullmatch(r'yes(?:\s*\([^\n]*\))?', clean_cell)
                rounds.append({"round": r[0], "lens": r[1], "new_genuine_findings": r[2], "fixed": r[3],
                               "clean": bool(clean_value), "clean_cell": r[4], "date": r[5] if len(r) > 5 else ""})
    state["rounds"] = rounds
    state["rounds_total"] = len(rounds)
    state["rounds_clean"] = sum(1 for r in rounds if r["clean"])

    # next action
    h, body = find_section(secs, "Next action")
    nxt = None
    if body is None:
        missing.append("Next action")
    else:
        for line in body:
            s = line.strip()
            if s and not s.startswith("<!--"):
                nxt = strip_code(s)
                break
        if nxt is None:
            missing.append("Next action: empty")
    state["next_action"] = nxt
    state["next_action_is_stopped"] = bool(nxt and nxt.startswith("STOPPED:"))
    # template placeholders (`<...>`) left in a gate result or the next action: the
    # state was never filled (state-check.sh says the same; tools get it as a verdict)
    placeholders = [g["gate"] for g in gates if g.get("placeholder")]
    if nxt and re.fullmatch(r"<[^>]*>", nxt.strip()):
        placeholders.append("next_action")
    state["placeholders"] = placeholders
    state["missing"] = missing
    state["verdict"] = "MALFORMED" if missing else ("PLACEHOLDERS" if placeholders else "OK")

    rendered = json.dumps(state, indent=2, ensure_ascii=False) + "\n"
    drift = False
    if out:
        if check:
            if os.path.exists(out):
                drift = regular_text(out) != rendered
            else:
                drift = True
        else:
            with open(out, "w", encoding="utf-8") as fh:
                fh.write(rendered)
    summary = {"file": path, "phase": phase, "phase_number": state["phase_number"], "tier": state["tier_number"],
               "gates": {g["gate"]: g.get("verdict") for g in gates}, "rounds_total": len(rounds),
               "rounds_clean": state["rounds_clean"], "next_action": (nxt or "")[:80], "missing": missing,
               "placeholders": placeholders, "out": out, "drift": drift,
               "verdict": state["verdict"] if not drift else "DRIFT"}
    if not out:
        print(rendered, end="")
    print(json.dumps(summary, ensure_ascii=False))
    return 0 if (state["verdict"] == "OK" and not drift) else 1


if __name__ == "__main__":
    try:
        sys.exit(main(sys.argv[1:]))
    except (OSError, UnicodeError, ValueError) as exc:
        print(f'state-json: {exc}', file=sys.stderr)
        sys.exit(2)
