#!/usr/bin/env python3
"""merge-deltas: lint a set of port deltas (references/DELTAS.md: one JSON
object per file, the only accepted write into the compiled registers) and
compile them deterministically into the rows each register would gain. The
tool never rewrites a document: it prints, per target file, the rows to
append (or the row to replace for an EDIT) and a lint report; with --out it
writes those rows to <DIR>/<target>.append.md beside a lint.txt and a
merge.json. Replaying the same deltas produces byte-identical output.

usage: merge-deltas.py <port-root> [--deltas DIR] [--thread THREAD_ID] [--out DIR] [--partial] [--no-git]
  <port-root>  the port (docs/, goldens/, perf/, port/); ids are assigned after the registers' current maxima
  --deltas     a directory of *.json deltas, or of <thread_id>/ directories holding them (default <port-root>/.deltas)
  --thread     merge only deltas of this thread id
  --out        write <target>.append.md files, lint.txt and merge.json there (created; nothing else is touched)
  --partial    with --out, write the accepted deltas' rows even when others were rejected
  --no-git     skip git checks (historical deltas need an ancestor; gate/lane evidence needs current HEAD)
order   : (ts, sender, filename); ADD assigns the next id by section prefix (OQ-, DISC-, NE-, F-<round>-, R-, C-, B-)
sections: oq disc ne finding round gate board_row lane case law claim blocker
lint    : every rule prints as `<delta file>: <rule>`; a rejected delta emits nothing
exit    : 0 every delta applied, 1 any delta rejected (lint), 2 usage or no deltas found.
Last stdout line: {"applied","rejected","sections":{..},"targets":[..],"verdict":"MERGED|REJECTED"}
"""
import argparse
from datetime import datetime, timezone
import json
import math
import os
import pathlib
import re
import subprocess
import sys
sys.dont_write_bytecode = True
from case_manifest import argv as parse_argv, regular_text, run as run_process
from markdown_evidence import visible_lines, split_row

SECTIONS = ("oq", "disc", "ne", "finding", "round", "gate", "board_row", "lane", "case", "law", "claim", "blocker")
THREAD_RE = re.compile(r"^PORT-[A-Za-z0-9_.-]+-P(-1|[0-6])$")
SHA_RE = re.compile(r"^[0-9a-f]{7,40}$")
EVIDENCE_KINDS = {"json_line", "file_line", "golden", "proof_line", "manifest", "file_sha"}
REQUIRED_ADD = {
    "oq": ("question", "clause", "resolve_by_case"),
    "disc": ("title", "class", "clause", "original_behavior", "port_behavior", "why", "kill_switch", "affected_cases"),
    "ne": ("lever", "def", "hypothesis", "capture_line", "laws_line", "why", "retry_predicate", "kill_switch_state", "outcome"),
    "finding": ("class", "clause", "status", "severity", "text"),
    "round": ("lens", "author_is_lens_owner", "findings"),
    "gate": ("name", "command", "result_line", "sha", "date"),
    "board_row": ("feature", "original_ref", "port_def", "goldens", "laws", "status", "notes"),
    "lane": ("lane", "cases", "verdict", "date"),
    "case": ("name", "args", "class"),
    "law": ("name", "statement", "clause", "kind"),
    "claim": ("text", "tag", "artifacts"),
    "blocker": ("tool", "where", "resume_with"),
}
EDIT_ALLOWED = {
    "oq": {"resolution", "date"}, "disc": {"status", "approver", "impact_measured", "manifest_diff", "resolution"},
    "ne": {"outcome"}, "finding": {"fixed_by_sha"}, "round": {"fixed", "date"}, "gate": {"result_line", "date"},
    "board_row": {"status", "goldens", "laws", "notes"}, "lane": {"verdict", "reason", "date"},
    "case": set(), "law": set(), "claim": {"text"}, "blocker": {"resolved"},
}
KILL_ALLOWED = {"oq", "disc", "finding", "board_row", "claim"}
ENUMS = {
    ("finding", "class"): {"EXIT", "MESSAGE", "ORDER", "NUMERIC", "FORMAT", "MISSING", "EXTRA", "TEXT", "CLAIM", "PROOF", "MANIFEST"},
    ("finding", "status"): {"NEW", "DUP_OF_PRIOR", "RE_OPENED"},
    ("gate", "name"): {"lanes", "proofs", "parity", "floor", "incumbent", "law_coverage", "converge", "state_check", "claims_lint", "arch_lint", "cass"},
    ("board_row", "status"): {"present", "partial", "missing", "excluded", "n/a"},
    ("lane", "lane"): {"interpreter", "c-1t", "c-Nt", "js", "gpu"},
    ("lane", "verdict"): {"PASS", "FAIL", "MISSING"},
    ("law", "kind"): {"fast_is_spec", "roundtrip", "conservation", "order", "closed_golden"},
    ("claim", "tag"): {"proved", "golden_tested", "measured"},
    ("ne", "outcome"): {"NO_EVIDENCE", "VOID", "NEGATIVE(reverted)", "NEGATIVE(retained-for-proof)", "PROVISIONAL_LOCAL_WIN"},
    ("disc", "class"): {"NumericWidth", "OrderLeak", "ErrorText", "Platform", "Nondeterminism", "BugFix", "Excluded", "Performance"},
}
PREDICATE_STEMS = (r"retry when .+ ≥|retry when .+ >=", r"inside (a|the) .*redesign|inside <", r"when .*gate .*moves|when .+ moves",
                   r"not worth retrying standalone", r"do not retry from a cold read", r"structural,? not numerical",
                   r"workload-property", r"blocked until .+\(bead")
HEDGES = ("should be", "probably", "roughly", "flaky", "usually passes")
DEFERRALS = ("if it seems important", "we should revisit", "tracked elsewhere", "todo")
LATER_RE = re.compile(r"(^|[^a-z-])later([.,;:)]|$)|(revisit|fix|handle|address|do (it|this|that)|save (it|this)|for|until|come back to it) later([^a-z-]|$)")
FREE_TEXT = ("question", "why", "rationale", "text", "notes", "hypothesis", "resolution", "title", "port_behavior", "retry_predicate", "statement")
TARGETS = {
    "oq": "docs/OPEN_QUESTIONS.md", "disc": "docs/DISCREPANCIES.md", "ne": "perf/NEGATIVE-EVIDENCE.md",
    "finding": "docs/PORT_STATE.md", "round": "docs/PORT_STATE.md", "gate": "docs/PORT_STATE.md", "blocker": "docs/PORT_STATE.md",
    "board_row": "docs/FEATURE_PARITY.md", "lane": "docs/FEATURE_PARITY.md", "case": "goldens/cases.tsv",
    "law": "port/LAWS.bend", "claim": "docs/PORT_REPORT.md",
}
ANCHORS = {
    "oq": "the `| OQ-` table (after its last row; GEN:oq END marker when present)",
    "disc": "`## Register` (after the last `### DISC-` entry; GEN:disc END marker when present)",
    "ne": "after the last `### NE-` entry (GEN:ne END marker when present)",
    "finding": "`## Find-fix rounds` — findings for the round row named below (GEN:round END marker when present)",
    "round": "`## Find-fix rounds` table, after its last row",
    "gate": "`## Last gate outputs` table (a row with the same gate name is REPLACED)",
    "blocker": "`## Open items` table, after its last row",
    "board_row": "the `| feature |` table, after its last row (GEN:board END marker when present)",
    "lane": "`## Lanes` table (a row with the same lane is REPLACED)",
    "case": "the end of goldens/cases.tsv, then `golden-capture.sh … --repin \"<reason>\"`",
    "law": "the `# PROPOSED` block at the bottom (created when absent); the human owner promotes",
    "claim": "`## Claims` under the tag's heading",
}


def usage_exit(msg):
    print(f"error: {msg}", file=sys.stderr); print(__doc__.strip(), file=sys.stderr); sys.exit(2)


def strict_json(text):
    def constant(value): raise ValueError(f'non-finite JSON constant {value}')
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
    # ubs:ignore[py.parsing.json-loads-no-try] ValueError deliberately propagates to each caller's lint-error handler.
    return json.loads(text, parse_constant=constant, parse_float=finite, object_pairs_hook=unique)


def load_deltas(root: pathlib.Path, thread: str):
    files = sorted(p for p in root.rglob("*.json") if not p.is_dir())
    out = []
    for p in files:
        try:
            obj = strict_json(regular_text(p))
        except Exception as e:  # noqa: BLE001 - a broken file is a lint error, reported below
            out.append((p, {"_broken": str(e)})); continue
        objs = obj if isinstance(obj, list) else [obj]
        for i, o in enumerate(objs):
            out.append((p if len(objs) == 1 else pathlib.Path(f"{p}#{i}"), o))
    if thread:
        out = [(p, o) for p, o in out if not isinstance(o, dict) or '_broken' in o or o.get("thread_id") == thread]
    def stamp(o):
        try: return timestamp(o.get('ts')).astimezone(timezone.utc).isoformat()
        except (ValueError, TypeError, AttributeError, OverflowError): return ''
    out.sort(key=lambda po: (stamp(po[1]), str(po[1].get("sender", "")) if isinstance(po[1], dict) else "", str(po[0])))
    return out


def timestamp(value):
    result = datetime.fromisoformat(value)
    if 'T' not in value or result.tzinfo is None: raise ValueError('timezone required')
    result.astimezone(timezone.utc)
    return result


def table_cells(line):
    return split_row(line) or []


def forbidden_words(text: str):
    l = text.lower(); hits = []
    for ph in HEDGES + DEFERRALS:
        if re.search(r"(^|[^a-z-])" + re.escape(ph) + r"([^a-z-]|$)", l): hits.append(ph)
    if LATER_RE.search(l): hits.append("later (deferral)")
    if "within noise" in l and "cv" not in l: hits.append("within noise (no cv)")
    if re.search(r"100 ?% parity", l): hits.append("100% parity")
    return hits


def register_max(text: str, prefix: str) -> int:
    nums = [int(n) for n in re.findall(re.escape(prefix) + r"(\d+)", text)]
    return max(nums) if nums else 0


def read(root: pathlib.Path, rel: str) -> str:
    p = root / rel
    text = regular_text(p) if p.exists() else ""
    return '\n'.join(visible_lines(text)) if p.suffix == '.md' and rel != TARGETS['claim'] else text


def writes_under(paths, directory, root):
    base = root / directory
    for item in paths:
        if not isinstance(item, str): continue
        path = pathlib.Path(item)
        if not path.is_absolute(): path = root / path
        if any(candidate.is_relative_to(parent) for candidate in (pathlib.Path(os.path.abspath(path)), path.resolve())
               for parent in (pathlib.Path(os.path.abspath(base)), base.resolve())):
            return True
    return False


def table_keys(text, header):
    inside, keys = False, set()
    for line in text.splitlines():
        if not line.startswith('|'): inside = False; continue
        cells = table_cells(line)
        if cells[0].lower() == header: inside = True; continue
        if inside and cells[0] and not re.fullmatch(r':?-+:?', cells[0]):
            keys.add(re.sub(r'\\(.)', r'\1', cells[0]))
    return keys


def existing_targets(root, state, report):
    board = read(root, TARGETS['board_row'])
    rounds = re.search(r'^## Find-fix rounds.*?(?=^## |\Z)', state, re.M | re.S)
    return {
        'oq': set(re.findall(r'^\|\s*(OQ-\d+)\s*\|', read(root, TARGETS['oq']), re.M)),
        'disc': set(re.findall(r'^###\s+(DISC-\d+)\b', read(root, TARGETS['disc']), re.M)),
        'ne': set(re.findall(r'^###\s+(NE-\d+)\b', read(root, TARGETS['ne']), re.M)),
        'finding': set(re.findall(r'^-\s+(F-\d+-\d+)\b', state, re.M)),
        'round': {'R-' + n for n in re.findall(r'^\|\s*(\d+)\s*\|', rounds.group() if rounds else '', re.M)},
        'gate': table_keys(state, 'gate'), 'board_row': table_keys(board, 'feature'),
        'lane': table_keys(board, 'lane'),
        'case': {ln.split('\t', 1)[0] for ln in read(root, TARGETS['case']).splitlines() if ln.strip() and not ln.startswith('#')},
        'law': set(re.findall(r'^law\s+([\w.]+)', read(root, TARGETS['law']), re.M)),
        'claim': set(re.findall(r'<!--\s*(C-\d+)\s*-->', report)),
        'blocker': set(re.findall(r'^\|\s*(B-\d+)\s*\|', state, re.M)),
    }


def git_is_ancestor(root: pathlib.Path, sha: str):
    """Check the containing repository; unavailable Git evidence is not success."""
    r = run_process(['git', '-C', str(root), 'merge-base', '--is-ancestor', sha, 'HEAD'], timeout=20)
    return not r['problem'] and r['rc'] == 0


def git_is_current(root: pathlib.Path, sha: str, metadata_files):
    """Require the exact commit, unchanged tracked files and no untracked inputs.

    Submitted delta files are metadata, excluded from the untracked-input check.
    Generated build products belong in the project's .gitignore.
    """
    def git(*args): return run_process(['git', '-C', str(root), *args], timeout=20)
    head = git('rev-parse', 'HEAD')
    claimed = git('rev-parse', f'{sha}^{{commit}}')
    dirty = git('status', '--porcelain', '--untracked-files=no')
    others = git('ls-files', '--others', '--exclude-standard', '-z')
    if any(result['problem'] or result['rc'] != 0 for result in (head, claimed, dirty, others)): return False
    untracked = [name for name in os.fsdecode(others['out']).split('\0') if name and pathlib.Path(os.path.abspath(root / name)) not in metadata_files]
    return head['out'] == claimed['out'] and not dirty['out'].strip() and not untracked


def lint_envelope(o, errs):
    for k in ("thread_id", "sender", "ts", "sha", "operation", "section", "payload", "rationale", "attestation"):
        if k not in o: errs.append(f"missing field `{k}`")
    if errs: return
    for k in ('thread_id', 'sender', 'ts', 'sha', 'operation', 'section', 'rationale'):
        if not isinstance(o[k], str): errs.append(f'{k} must be a string')
    if o.get('target_id') is not None and not isinstance(o['target_id'], str): errs.append('target_id must be a string or null')
    if errs: return
    if not THREAD_RE.match(str(o["thread_id"])): errs.append(f"thread_id `{o['thread_id']}` is not PORT-<name>-P<phase> (phase -1..6; the role is the sender, not part of the id)")
    if not str(o["sender"]).strip(): errs.append("empty sender")
    try: timestamp(o['ts'])
    except (ValueError, TypeError, OverflowError): errs.append(f"ts `{o['ts']}` is not a valid ISO-8601 timestamp with timezone")
    if not SHA_RE.match(str(o["sha"])): errs.append(f"sha `{o['sha']}` is not 7–40 hex")
    if o["operation"] not in ("ADD", "EDIT", "KILL"): errs.append(f"operation `{o['operation']}` not in ADD|EDIT|KILL")
    if o["section"] not in SECTIONS: errs.append(f"section `{o['section']}` not in {'|'.join(SECTIONS)}")
    if not isinstance(o["payload"], dict): errs.append("payload is not an object")
    if not str(o["rationale"]).strip(): errs.append("empty rationale")
    ev = o.get("evidence", [])
    if not isinstance(ev, list): errs.append("evidence is not a list")
    else:
        for e in ev:
            if not isinstance(e, dict) or not isinstance(e.get('kind'), str) or e.get("kind") not in EVIDENCE_KINDS or not isinstance(e.get('ref'), str) or not e['ref'].strip():
                errs.append(f"evidence entry malformed: {json.dumps(e)[:80]} (kind ∈ {sorted(EVIDENCE_KINDS)}, ref non-empty)")
    at = o["attestation"]
    if not isinstance(at, dict) or not isinstance(at.get("files_written"), list) or not isinstance(at.get("goldens_touched"), bool) or not isinstance(at.get("ran_original"), bool):
        errs.append("attestation needs files_written (list), goldens_touched (bool), ran_original (bool)")
    elif any(not isinstance(path, str) or not path.strip() for path in at['files_written']):
        errs.append('attestation.files_written must contain nonempty strings')
    if o["operation"] == "ADD" and o.get("target_id") not in (None, ""): errs.append("ADD carries a target_id (ids are assigned by the merge)")
    if o["operation"] in ("EDIT", "KILL") and not str(o.get("target_id") or "").strip(): errs.append(f"{o['operation']} without target_id")


def lint_payload(o, errs, ctx):
    sec, op, p = o["section"], o["operation"], o["payload"]
    if op == "ADD":
        for k in REQUIRED_ADD[sec]:
            if k not in p or p[k] is None or (isinstance(p[k], str) and not p[k].strip() and (sec, k) not in (("case", "args"), ("board_row", "notes"))): errs.append(f"{sec} ADD lacks `{k}`")
        for (s, k), allowed in ENUMS.items():
            if s == sec and k in p and str(p[k]) not in allowed: errs.append(f"{sec}.{k} `{p[k]}` not in {sorted(allowed)}")
        flexible = {('round', 'findings'), ('round', 'author_is_lens_owner'), ('disc', 'original_behavior'),
                    ('disc', 'affected_cases'), ('board_row', 'goldens'), ('board_row', 'laws'), ('claim', 'artifacts')}
        for k in REQUIRED_ADD[sec]:
            if k in p and (sec, k) not in flexible and not isinstance(p[k], str): errs.append(f"{sec}.{k} must be a string")
        for k in ('goldens', 'laws') if sec == 'board_row' else ():
            if k in p and not isinstance(p[k], (str, list)): errs.append(f"board_row.{k} must be a string or array")
    elif op == "EDIT":
        if not p: errs.append('EDIT payload is empty')
        bad = set(p) - EDIT_ALLOWED[sec]
        if not EDIT_ALLOWED[sec]: errs.append(f"{sec} rows are never edited by agents" + (" (a case rename is refused)" if sec == "case" else ""))
        elif bad: errs.append(f"{sec} EDIT touches fields outside {sorted(EDIT_ALLOWED[sec])}: {sorted(bad)}")
        for (s, k), allowed in ENUMS.items():
            if s == sec and k in p and str(p[k]) not in (allowed | ({'WIN'} if sec == 'ne' else set())): errs.append(f"{sec}.{k} `{p[k]}` not in {sorted(allowed)}")
    elif op == "KILL":
        if sec not in KILL_ALLOWED: errs.append(f"{sec} entries are append-only; KILL refused")
        if not isinstance(p.get('reason'), str) or not p['reason'].strip(): errs.append("KILL without a nonempty string payload.reason")
        if sec == 'board_row' and p.get('status') != 'excluded': errs.append('board_row KILL needs status excluded and classified notes; the row remains as debt')
    # section rules
    for k, value in p.items():
        if isinstance(value, str) and '\0' in value: errs.append(f'{sec}.{k} contains NUL')
        if k in ('name', 'feature', 'date', 'title', 'lever', 'severity', 'clause', 'kind') and isinstance(value, str) and any(c in value for c in '\r\n\t'):
            errs.append(f'{sec}.{k} must stay on one line')
    for key in ('goldens', 'laws') if sec == 'board_row' else ('affected_cases',) if sec == 'disc' else ('artifacts',) if sec == 'claim' else ():
        if sec == 'board_row' and key in p and not isinstance(p[key], (str, list)):
            errs.append(f'board_row.{key} must be a string or array')
        if key in p and isinstance(p[key], list) and any(not isinstance(v, str) or not v.strip() for v in p[key]):
            errs.append(f'{sec}.{key} must contain nonempty strings')
    if op == 'EDIT':
        for key, value in p.items():
            if key not in ('goldens', 'laws') and not isinstance(value, str): errs.append(f'{sec}.{key} must be a string')
    if sec == 'disc' and op == 'EDIT' and 'status' in p and p['status'] not in ('OPEN', 'ACCEPTED', 'REVERTED', 'RESOLVED'):
        errs.append('disc.status must be OPEN, ACCEPTED, REVERTED or RESOLVED')
    if sec == 'disc' and op == 'EDIT' and p.get('status') == 'RESOLVED':
        resolution = p.get('resolution')
        if not isinstance(resolution, str) or not resolution.strip(' `\t\r\n') or resolution.strip(' `\t\r\n').startswith('<') or re.fullmatch(r'pending|none|n/a|-', resolution.strip(' `\t\r\n'), re.I):
            errs.append('DISC → RESOLVED needs payload.resolution describing restored fidelity and its regression evidence')
        if not o.get('evidence'): errs.append('DISC → RESOLVED needs regression evidence references')
    if sec == "finding" and op == "ADD":
        if not str(p.get("file_line", "")).strip() and not str(p.get("case", "")).strip(): errs.append("finding without file_line AND without case (dropped by rule)")
        if p.get('status') == 'DUP_OF_PRIOR' and (not isinstance(p.get('dup_of'), str) or p['dup_of'] not in ctx['finding_status']):
            errs.append('DUP_OF_PRIOR must name a known finding in dup_of')
        sig = f"{p.get('class')}:{p.get('clause')}:{p.get('case') or '-'}"
        # ubs:ignore[python.ctcompare.secret_eq] Public CLASS:CLAUSE:CASE dedup keys, not cryptographic signatures or secrets.
        if p.get('status') == 'DUP_OF_PRIOR' and (not isinstance(p.get('dup_of'), str) or ctx['finding_signatures'].get(p['dup_of']) != sig):
            errs.append('DUP_OF_PRIOR signature differs from the finding named in dup_of')
        if sig in ctx["signatures"] and p.get("status") not in ("DUP_OF_PRIOR", "RE_OPENED"): errs.append(f"duplicate finding signature {sig} not marked DUP_OF_PRIOR or RE_OPENED")
        if p.get('status') == 'RE_OPENED' and sig not in ctx['signatures']: errs.append('RE_OPENED needs a prior matching finding signature')
        if p.get("round") is not None and (not isinstance(p["round"], int) or isinstance(p["round"], bool) or p["round"] < 1):
            errs.append("finding.round must be a positive integer")
        elif p.get('round') is not None and p['round'] != ctx['next_round']:
            errs.append(f"finding.round must name the next unclosed round {ctx['next_round']}")
        for key in ('case', 'file_line', 'dup_of'):
            if key in p and (not isinstance(p[key], str) or any(c in p[key] for c in '\r\n\t')):
                errs.append(f'finding.{key} must be a single-line string')
    if sec == "round" and op == "ADD":
        if isinstance(p.get('lens'), str) and re.search(r'\((?:non-)?author\)|[\r\n\t]', p['lens'], re.I):
            errs.append('round.lens must be one line without reserved (author)/(non-author) markers; attribution comes from author_is_lens_owner')
        if not isinstance(p.get("author_is_lens_owner"), bool): errs.append("round.author_is_lens_owner must be boolean")
        fids = p.get("findings")
        if not isinstance(fids, list) or any(not isinstance(f, str) for f in fids): errs.append("round.findings must be an array of finding IDs")
        elif len(set(fids)) != len(fids): errs.append("round.findings repeats an ID")
        else:
            unknown = [f for f in fids if f not in ctx["finding_status"]]
            if unknown: errs.append("round references unknown findings: " + ", ".join(unknown))
            if any(not f.startswith(f"F-{ctx['next_round']}-") for f in fids):
                errs.append('round.findings must belong to this round; prior findings are referenced through DUP_OF_PRIOR/RE_OPENED entries')
            omitted = {f for f in ctx['finding_status'] if f.startswith(f"F-{ctx['next_round']}-")} - set(fids)
            if omitted: errs.append('round omits registered findings: ' + ', '.join(sorted(omitted)))
    if sec == "round" and "clean" in p: errs.append("round.clean is COMPUTED by the merge (< 3 NEW findings), never asserted by the sender")
    if sec == "gate" and op in ("ADD", "EDIT") and "result_line" in p:
        r = str(p["result_line"]).strip()
        structured = False
        if r.startswith('{'):
            try:
                obj = strict_json(r)
                structured = isinstance(obj, dict) and isinstance(obj.get('verdict'), str) and bool(obj['verdict'].strip())
            except ValueError: pass
        if not (structured or re.fullmatch(r'All terms check(?:, with [0-9]+ unsafe annotations?)?\.', r) or (r.startswith('rows=') and 'verdict=' in r) or r.startswith("BLOCKER:")):
            errs.append("gate.result_line is not a pasted JSON object / `All terms check…` / `rows=… verdict=…` / `BLOCKER: …`")
        if op == "ADD" and p.get("sha") != o["sha"]: errs.append("gate.sha differs from envelope sha")
    if sec == "case" and op == "ADD":
        if not re.fullmatch(r"[A-Za-z0-9][A-Za-z0-9_.-]*", str(p.get("name", ""))): errs.append("case.name must be a safe basename")
        for key in ("args", "stdin_file", "class"):
            if key in p and (not isinstance(p[key], str) or any(c in p[key] for c in "\t\r\n")):
                errs.append(f"case.{key} must be a single TSV cell")
        if isinstance(p.get('args'), str):
            try: parse_argv(p['args'])
            except ValueError as exc: errs.append(f'case.args: {exc}')
    if sec == "disc" and op == "ADD":
        if not isinstance(p.get("affected_cases"), list): errs.append("disc.affected_cases must be an array")
        ob = p.get('original_behavior')
        if not isinstance(ob, dict) or not isinstance(ob.get('golden'), str) or not ob['golden'].strip() or not isinstance(ob.get('verbatim'), str) or not re.fullmatch(r'[1-9]\d*', str(ob.get('line', ''))):
            errs.append('disc.original_behavior needs golden, positive line and verbatim evidence')
    if sec == "claim" and op == "ADD" and not isinstance(p.get("artifacts"), list): errs.append("claim.artifacts must be an array")
    if sec == "ne" and op == "ADD":
        rp = str(p.get("retry_predicate", "")).lower()
        if not any(re.search(st, rp) for st in PREDICATE_STEMS): errs.append("ne.retry_predicate matches none of the eight stems (NEGATIVE-EVIDENCE template)")
        if not re.search(r"\d", str(p.get("why", ""))): errs.append("ne.why carries no number (C6: a null result states its counts)")
    if sec == "claim" and op == "ADD" and not p.get("artifacts"): errs.append("claim without artifacts[]")
    if sec == 'board_row' and op == 'ADD' and p.get('status') == 'present':
        if not p.get('goldens') or p.get('goldens') in ('-', 'none') or not p.get('laws') or p.get('laws') == '-':
            errs.append('board_row present needs named goldens and named laws or explicit "none"')
    if sec == "board_row" and str(p.get("status", "")).lower() == "excluded" and not re.search(r"\b(infeasible-numeric|mutation-dependent|exception-dependent|external-dependency|platform|effect|nondeterministic|out-of-scope)\b", str(p.get("notes", "")), re.I):
        errs.append("board_row → excluded needs a class in notes")
    if sec == "lane" and str(p.get("verdict", "")) == "MISSING" and not str(p.get("reason", "")).strip(): errs.append("lane MISSING without reason")
    if sec == "disc" and op == "EDIT" and str(p.get("status", "")).upper() == "ACCEPTED":
        appr = str(p.get("approver", "")).strip()
        if not appr: errs.append("DISC → ACCEPTED without approver")
        elif appr in ctx["implementers"] or (o["sender"] in ctx["implementers"]): errs.append(f"DISC → ACCEPTED by an implementer of this thread (`{appr or o['sender']}` wrote port/*)")
    if o["attestation"].get("goldens_touched") is True and "harness" not in str(o["sender"]).lower():
        errs.append(f"goldens_touched: true from `{o['sender']}` (only the harness keeper writes goldens; C8)")
    if not o["attestation"].get("goldens_touched") and writes_under(o["attestation"]["files_written"], 'goldens', ctx['root']):
        errs.append("files_written names goldens/* but goldens_touched is false")
    for k in FREE_TEXT:
        if k in p and isinstance(p[k], str):
            for w in forbidden_words(p[k]): errs.append(f"forbidden word in payload.{k}: `{w}` (claims-lint family)")
    for w in forbidden_words(str(o["rationale"])): errs.append(f"forbidden word in rationale: `{w}`")


def cell(s) -> str:
    return str(s).replace('\\', '\\\\').replace("|", "\\|").replace("\t", "\\t").replace("\r", " ").replace("\n", " ").replace('<!--', '&lt;!--')


def date_of(o) -> str:
    return str(o["payload"].get("date") or str(o["ts"])[:10])


def emit(o, ids, ctx, root):
    """Return (target, text) for an accepted delta."""
    sec, op, p = o["section"], o["operation"], o["payload"]
    t = TARGETS[sec]; d = date_of(o)
    # EDIT payloads are partial updates. They must never enter ADD emitters,
    # allocate a new round, or blank columns omitted from a lane/gate update.
    if op != "ADD" and sec != "oq":
        note = ' (WIN: move the row to perf/PERF-LEDGER.md)' if sec == 'ne' and p.get('outcome') == 'WIN' else ''
        return t, f"{op} {o['target_id']}: " + "; ".join(f"{k} = {cell(v)}" for k, v in sorted(p.items())) + note, o["target_id"]
    if sec == "oq":
        if op == "ADD":
            i = ids["OQ"] = ids["OQ"] + 1; oid = f"OQ-{i:03d}"
            return t, f"| {oid} | {cell(p['question'])} | {cell(p['clause'])} | `{cell(p['resolve_by_case'])}` | OPEN | {cell(d)} |", oid
        cells = table_cells(ctx['oq_rows'][o['target_id']])
        if op == "EDIT":
            if "resolution" in p: cells[4] = cell(p["resolution"])
            if "date" in p: cells[5] = cell(p["date"])
        else:
            cells[4] = f"WITHDRAWN: {cell(p['reason'])}"; cells[5] = cell(d)
        return t, f"REPLACE row {o['target_id']}:\n| " + " | ".join(cells) + " |", o["target_id"]
    if sec == "disc":
        if op == "ADD":
            i = ids["DISC"] = ids["DISC"] + 1; did = f"DISC-{i:03d}"
            ob = p["original_behavior"]
            lines = [f"### {did} — {cell(p['title'])}   [{cell(d)} | {p['class']} | OPEN]",
                     f"- Spec clause: {cell(p['clause'])}",
                     f"- Original behavior (cite the golden): `{cell(ob['golden'])}` line `{cell(ob['line'])}`: `{cell(ob['verbatim'])}`",
                     f"- Port behavior: `{cell(p['port_behavior'])}`", f"- Why: {cell(p['why'])}", f"- Kill-switch: {cell(p['kill_switch'])}",
                     f"- Affected cases: {', '.join(map(cell, p['affected_cases']))}",
                     "- Impact measured: (pending)", "- Approver: (pending; not the implementer)"]
            return t, "\n".join(lines), did
        return t, f"EDIT {o['target_id']}: " + "; ".join(f"{k} = {cell(v)}" for k, v in sorted(p.items())), o["target_id"]
    if sec == "ne":
        if op == "ADD":
            i = ids["NE"] = ids["NE"] + 1; nid = f"NE-{i:03d}"
            lines = [f"### {nid} — {cell(p['lever'])}   [{cell(d)} | {p['outcome']}]",
                     f"- Program / def: `port/main.bend` / `{cell(p['def'])}`", f"- Hypothesis: {cell(p['hypothesis'])}",
                     f"- Capture: `{cell(p['capture_line'])}`; laws: `{cell(p['laws_line'])}`", f"- Why it lost / could not be measured: {cell(p['why'])}",
                     f"- Retry predicate: {cell(p['retry_predicate'])}", f"- Kill-switch state: {cell(p['kill_switch_state'])}"]
            return t, "\n".join(lines), nid
        return t, f"EDIT {o['target_id']}: outcome = {cell(p.get('outcome', ''))}" + (" (WIN: the row moves to perf/PERF-LEDGER.md)" if p.get("outcome") == "WIN" else ""), o["target_id"]
    if sec == "finding":
        if op == "ADD":
            rnd = int(p.get("round") or ids["R"] + 1); ids["F"][rnd] = ids["F"].get(rnd, 0) + 1
            fid = f"F-{rnd}-{ids['F'][rnd]}"; ctx["finding_status"][fid] = p["status"]
            ctx["signatures"].add(f"{p.get('class')}:{p.get('clause')}:{p.get('case') or '-'}")
            ctx['finding_signatures'][fid] = f"{p.get('class')}:{p.get('clause')}:{p.get('case') or '-'}"
            fl = p.get("file_line", ""); fl = f"{fl}@{o['sha']}" if fl else "no file:line"
            return t, f"- {fid} {p['class']}:{cell(p['clause'])}:{cell(p.get('case') or '-')} [{p['status']}, {cell(p['severity'])}] {cell(fl)} — {cell(p['text'])}" + (f" (dup of {cell(p['dup_of'])})" if p.get("dup_of") else ""), fid
        return t, f"EDIT {o['target_id']}: " + "; ".join(f"{k} = {cell(v)}" for k, v in sorted(p.items())), o["target_id"]
    if sec == "round":
        i = ids["R"] = ids["R"] + 1
        ctx['next_round'] = i + 1
        fids = [str(f) for f in p["findings"]]
        new = [f for f in fids if ctx["finding_status"][f] in ("NEW", "RE_OPENED")]
        reopened = any(ctx["finding_status"][f] == "RE_OPENED" for f in fids)
        clean = "yes" if len(new) < 3 and not reopened else "no"
        lens = p["lens"] + (" (author)" if p.get("author_is_lens_owner") else " (non-author)")
        note = " (RE_OPENED resets the clean counter)" if reopened else ""
        return t, f"| {i} | {cell(lens)} | {len(new)}: {', '.join(fids) or 'none'}{note} | {cell(p.get('fixed', ''))} | {clean} | {cell(d)} |", f"R-{i}"
    if sec == "gate":
        return t, f"| {p['name']} | `{cell(p['command'])}` | `{cell(p['result_line'])}` (sha {p['sha']}) | {cell(d)} |", p["name"]
    if sec == "blocker":
        if op == "ADD":
            i = ids["B"] = ids["B"] + 1; bid = f"B-{i}"
            return t, f"| {bid} | BLOCKER: {cell(p['tool'])} at {cell(p['where'])} | resume with `{cell(p['resume_with'])}` | {cell(o['sender'])} |", bid
        return t, f"EDIT {o['target_id']}: resolved = {cell(p.get('resolved', ''))}", o["target_id"]
    if sec == "board_row":
        if op == "ADD":
            g = p["goldens"]; g = ", ".join(map(str, g)) if isinstance(g, list) else str(g)
            l = p["laws"]; l = ", ".join(map(str, l)) if isinstance(l, list) else str(l)
            return t, f"| {cell(p['feature'])} | {cell(p['original_ref'])} | {cell(p['port_def'])} | {cell(g or '-')} | {cell(l or 'none')} | {p['status']} | {cell(p['notes'])} |", p["feature"]
        return t, f"{op} row `{o['target_id']}`: " + "; ".join(f"{k} = {cell(v)}" for k, v in sorted(p.items())), o["target_id"]
    if sec == "lane":
        v = p.get("verdict", ""); reason = f": {p['reason']}" if p.get("reason") else ""
        return t, f"| {p.get('lane', o.get('target_id'))} | {cell(p.get('cases', ''))} | {cell(v + reason)} | {cell(d)} |", p.get("lane", o.get("target_id"))
    if sec == "case":
        return t, f"{p['name']}\t{p['args']}\t{p.get('stdin_file') or '-'}\t{p['class']}", p["name"]
    if sec == "law":
        statement = '\n'.join('#   ' + line for line in p['statement'].splitlines())
        return t, f"# PROPOSED by {cell(o['sender'])} ({cell(d)}, {o['thread_id']}): {p['kind']} for {p['clause']}\n# law {p['name']}:\n{statement}", p["name"]
    if sec == "claim":
        if op == "ADD":
            i = ids["C"] = ids["C"] + 1; cid = f"C-{i}"
            return t, f"- ({p['tag']}) {cell(p['text'])} — artifacts: {', '.join(map(cell, p['artifacts']))}   <!-- {cid} -->", cid
        return t, f"{op} {o['target_id']}: " + "; ".join(f"{k} = {cell(v)}" for k, v in sorted(p.items())), o["target_id"]
    return t, f"<!-- {op} {sec}: unhandled -->", "?"


def main() -> int:
    ap = argparse.ArgumentParser(add_help=False)
    ap.add_argument("port_root", nargs="?")
    ap.add_argument("--deltas"); ap.add_argument("--thread"); ap.add_argument("--out")
    ap.add_argument("--partial", action="store_true"); ap.add_argument("--no-git", action="store_true")
    ap.add_argument("-h", "--help", action="store_true")
    a = ap.parse_args()
    if a.help or not a.port_root:
        print(__doc__.strip()); return 0 if a.help else 2
    root = pathlib.Path(a.port_root).resolve()
    if not root.is_dir(): usage_exit(f"{root} is not a directory")
    droot = pathlib.Path(a.deltas) if a.deltas else root / ".deltas"
    if not droot.is_dir(): usage_exit(f"deltas directory {droot} not found")
    if a.out:
        output = pathlib.Path(a.out)
        if output.is_symlink() or (output.exists() and (not output.is_dir() or any(output.iterdir()))):
            usage_exit('--out must be a new or empty directory; previous append files are never overwritten or reused')
    deltas = load_deltas(droot, a.thread)
    if not deltas: usage_exit(f"no *.json deltas under {droot}")
    # Only well-formed envelope files are metadata. Never exempt an entire
    # --deltas subtree (which may also contain untracked source or inputs).
    metadata_files = set()
    for path in droot.rglob('*.json'):
        try:
            objs = strict_json(regular_text(path))
            objs = objs if isinstance(objs, list) else [objs]
            valid = bool(objs)
            for obj in objs:
                errors = []
                if not isinstance(obj, dict): valid = False; break
                lint_envelope(obj, errors)
                if errors or (a.thread and obj.get('thread_id') != a.thread): valid = False; break
            if valid: metadata_files.add(pathlib.Path(os.path.abspath(path)))
        except (OSError, UnicodeError, ValueError): pass

    # current register maxima (ids are assigned after them; never reused)
    state = read(root, "docs/PORT_STATE.md"); report = read(root, "docs/PORT_REPORT.md")
    ids = {"OQ": register_max(read(root, "docs/OPEN_QUESTIONS.md"), "OQ-"), "DISC": register_max(read(root, "docs/DISCREPANCIES.md"), "DISC-"),
           "NE": register_max(read(root, "perf/NEGATIVE-EVIDENCE.md"), "NE-"), "R": 0, "F": {}, "C": register_max(report, "C-"), "B": register_max(state, "B-")}
    sec = re.search(r"^## Find-fix rounds.*?(?=^## |\Z)", state, re.M | re.S)
    if sec: ids["R"] = max([int(m) for m in re.findall(r"^\|\s*(\d+)\s*\|", sec.group(0), re.M)] or [0])
    for rnd, num in re.findall(r"\bF-(\d+)-(\d+)\b", state):
        ids["F"][int(rnd)] = max(ids["F"].get(int(rnd), 0), int(num))
    existing_sigs = set(re.findall(r"^-\s+F-\d+-\d+\s+([A-Z]+:[^\s:]+:[^\s]+)\s+\[", state, re.M))

    ctx = {"signatures": set(existing_sigs), "finding_status": {}, "implementers": set(), 'oq_rows': {},
           'finding_signatures': dict(re.findall(r'^-\s+(F-\d+-\d+)\s+([A-Z]+:[^\s:]+:[^\s]+)\s+\[', state, re.M)),
           'next_round': ids['R'] + 1, 'root': root}
    known = existing_targets(root, state, report)
    for line in read(root, TARGETS['oq']).splitlines():
        if re.match(r'^\|\s*OQ-', line): ctx['oq_rows'][table_cells(line)[0]] = line
    for fid, status in re.findall(r"\b(F-\d+-\d+)\s+[^\n\[]+\[(NEW|DUP_OF_PRIOR|RE_OPENED)\b", state):
        ctx["finding_status"][fid] = status
    for _, o in deltas:
        if isinstance(o, dict) and isinstance(o.get("attestation"), dict):
            files = o['attestation'].get('files_written')
            if isinstance(files, list) and writes_under(files, 'port', root): ctx["implementers"].add(str(o.get("sender")))
    # phase-overlap rule (MULTI-AGENT "What never runs in parallel"): P4 gate/finding and P5 ne/claim on one sha
    by_sha = {}
    for p, o in deltas:
        if isinstance(o, dict) and isinstance(o.get('thread_id'), str) and THREAD_RE.match(o['thread_id']):
            ph = o["thread_id"].rsplit("-P", 1)[1]
            if (ph == "4" and o.get("section") in ("gate", "finding")) or (ph == "5" and o.get("section") in ("ne", "claim")):
                by_sha.setdefault(str(o.get("sha")), set()).add(ph)
    overlap_shas = {s for s, phs in by_sha.items() if phs >= {"4", "5"}}

    lint, applied, rejected, sections, targets, emitted = [], 0, 0, {}, {}, []
    git_note = None
    updates = {}
    for p, o in deltas:
        rel = str(p.relative_to(droot)) if str(p).startswith(str(droot)) else str(p)
        errs = []
        if not isinstance(o, dict): errs.append("not a JSON object")
        elif "_broken" in o: errs.append(f"unreadable JSON: {o['_broken']}")
        else:
            lint_envelope(o, errs)
            if not errs:
                lint_payload(o, errs, ctx)
                sec, op, target = o['section'], o['operation'], o.get('target_id')
                if op != 'ADD':
                    if target not in known[sec]: errs.append(f'{op} targets unknown {sec} entry {target}')
                    if sec == 'oq' and target in ctx['oq_rows'] and len(table_cells(ctx['oq_rows'][target])) != 6:
                        errs.append(f'{target} has a malformed OQ row')
                    prior = updates.get((sec, target), {})
                    if prior.get('_operation') == 'KILL' or (op == 'KILL' and prior) or any(k in prior and prior[k] != v for k, v in o['payload'].items()):
                        errs.append(f'conflicting updates to {sec} {target} in this batch')
                elif sec in ('board_row', 'case', 'law'):
                    key = o['payload'].get('feature' if sec == 'board_row' else 'name')
                    if isinstance(key, str) and key in known[sec]: errs.append(f'duplicate {sec} ADD: {key}')
                if str(o.get("sha")) in overlap_shas: errs.append(f"phase overlap on sha {o['sha']}: P4 gate/finding and P5 ne/claim deltas on the same tree (MULTI-AGENT: never in parallel)")
                if not a.no_git:
                    anc = git_is_ancestor(root, str(o["sha"]))
                    if anc is False: errs.append(f"sha {o['sha']} is not an ancestor of HEAD (stale or unknown evidence)")
                    elif anc is None and git_note is None: git_note = f"note: sha ancestry not checked ({root} is not a repository root, or git is absent)"
                    if o["section"] in ("gate", "lane") and git_is_current(root, str(o["sha"]), metadata_files) is False:
                        errs.append("gate/lane evidence is not for the current clean HEAD; rerun the gate on the committed tree")
        if errs:
            rejected += 1
            for e in errs: lint.append(f"{rel}: {e}")
            continue
        t, text, new_id = emit(o, ids, ctx, root)
        known[o['section']].add(new_id)
        if o['section'] == 'oq': ctx['oq_rows'][new_id] = text.splitlines()[-1]
        if o['operation'] != 'ADD': updates.setdefault((o['section'], new_id), {}).update(dict(o['payload'], _operation=o['operation']))
        applied += 1; sections[o["section"]] = sections.get(o["section"], 0) + 1
        targets.setdefault(t, []).append((o["section"], text)); emitted.append((rel, o["section"], o["operation"], new_id, t))

    verdict = "MERGED" if rejected == 0 else "REJECTED"
    print(f"merge-deltas: {len(deltas)} delta(s) under {droot}; applied {applied}, rejected {rejected}")
    if git_note: print(git_note)
    for rel, s, op, nid, t in emitted: print(f"  {op} {s} → {nid} ({t})  [{rel}]")
    if lint:
        print("lint:")
        for l in lint: print(f"  {l}")
    for t in sorted(targets):
        print(f"\n## → {t} (append after {ANCHORS[[s for s in TARGETS if TARGETS[s] == t and any(sec_ == s for sec_, _ in targets[t])][0]]})")
        for _, text in targets[t]: print(text)
    if a.out and (verdict == "MERGED" or a.partial):
        od = pathlib.Path(a.out); od.mkdir(parents=True, exist_ok=True)
        for t in sorted(targets):
            (od / (t.replace("/", "__") + ".append.md")).write_text("\n".join(text for _, text in targets[t]) + "\n", encoding="utf-8")
        (od / "lint.txt").write_text("\n".join(lint) + ("\n" if lint else ""), encoding="utf-8")
        (od / "merge.json").write_text(json.dumps({"applied": applied, "rejected": rejected, "sections": sections, "targets": sorted(targets), "emitted": emitted, "lint": lint, "verdict": verdict}, indent=1) + "\n", encoding="utf-8")
        print(f"\nwrote {len(targets)} append file(s), lint.txt and merge.json under {od}")
    elif a.out:
        print(f"\nnothing written under {a.out}: {rejected} delta(s) rejected (use --partial to write the accepted rows anyway)")
    print(json.dumps({"applied": applied, "rejected": rejected, "sections": sections, "targets": sorted(targets), "verdict": verdict}))
    return 0 if verdict == "MERGED" else 1


if __name__ == "__main__":
    sys.exit(main())
