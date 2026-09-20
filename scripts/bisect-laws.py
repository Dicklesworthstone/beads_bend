#!/usr/bin/env python3
"""bisect-laws: find which law makes `bend PROOF.bend` slow or hang. For every
`law <name>` in LAWS.bend, build a probe project in a temp dir holding the
port's other .bend files, a LAWS.bend with only that law, and a PROOF.bend
with the shared lemmas (every def that is not `Laws.*`) plus that law's
`def Laws.<name>`; check it under a wall-clock timeout and a memory cap and
report per law: OK (a successful final checker verdict), RED (a checker error),
TIMEOUT, or INCONCLUSIVE (a launcher/signal failure). A TIMEOUT law can become a
harness golden and a VOID ledger entry (LAWS-FROM-SPEC).

usage: bisect-laws.py <port-dir> [--timeout S] [--mem GiB] [--keep DIR] [--only NAME[,NAME]]
   <port-dir>   the directory with main.bend, LAWS.bend and PROOF.bend
   --timeout    seconds per law (default 90)
   --mem        address-space cap per check in GiB (default 6; 0 = none)
   --keep DIR   parent for a fresh retained probe directory (default: system temp)
   --only       check only these laws
Bend is `$BEND_CLI` (e.g. "bun /path/bend2/main.ts") or `bend` on PATH.
exit: 0 every selected law OK, 1 any failure, 2 usage. Artifacts are never removed.
The copy includes regular files in subdirectories; symlinks/special files are refused.
Absolute imports outside the port still need the original pinned dependencies.
"""
import argparse
import json
import math
import os
import re
import shlex
import shutil
import sys
import tempfile
from pathlib import Path

sys.dont_write_bytecode = True
from case_manifest import positive, regular_text, run


def items(text):
    """Split column-zero declarations; preserve intervening comments verbatim."""
    out, cur = [], []
    for ln in text.split("\n"):
        if ln and not ln[0].isspace() and not ln.startswith("#") and cur:
            content = [c for c in cur if c.strip() and not c.lstrip().startswith("#")]
            # @unsafe belongs to its following definition, including when the
            # annotation occupies its own line. Moving it into shared headers
            # would silently annotate another law in the isolated probe.
            annotated_def = len(content) == 1 and re.fullmatch(r"@unsafe\s*(?:#.*)?", content[0]) and re.match(r"def\s", ln)
            if content and not annotated_def:
                out.append("\n".join(cur)); cur = []
        cur.append(ln)
    if cur:
        out.append("\n".join(cur))
    return out


def head(item):
    content = [ln for ln in item.split("\n") if ln.strip() and not ln.lstrip().startswith("#")]
    if len(content) > 1 and re.fullmatch(r"@unsafe\s*(?:#.*)?", content[0]):
        return "@unsafe " + content[1]
    return content[0] if content else ""


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("port", type=Path)
    parser.add_argument("--timeout", type=positive, default=90.0)
    parser.add_argument("--mem", type=float, default=6.0)
    parser.add_argument("--keep", type=Path)
    parser.add_argument("--only")
    args = parser.parse_args()
    if not math.isfinite(args.mem) or args.mem < 0:
        parser.error("--mem must be finite and nonnegative")
    port = args.port.resolve()
    bend = shlex.split(os.environ.get("BEND_CLI", "bend"))
    if not bend:
        parser.error("BEND_CLI is empty")
    # Resolve launch operands before moving into each isolated probe directory.
    bend[0] = shutil.which(bend[0]) or str(Path(bend[0]).resolve())
    bend[1:] = [str(Path(word).resolve()) if Path(word).is_file() else word for word in bend[1:]]
    def declarations(filename, pattern):
        header, declared = [], {}
        for item in items(regular_text(port / filename)):
            match = re.match(pattern, head(item))
            if match:
                name = match[1]
                if name in declared:
                    raise ValueError(f"duplicate declaration {name} in {filename}")
                declared[name] = item
            else:
                header.append(item)
        return header, declared
    law_hdr, laws = declarations("LAWS.bend", r"law\s+([A-Za-z_][A-Za-z0-9_.]*)\b")
    proof_hdr, proofs = declarations("PROOF.bend", r"(?:@unsafe\s+)?def\s+Laws\.([A-Za-z_][A-Za-z0-9_.]*)\b")
    only = set(args.only.split(",")) if args.only is not None else set(laws)
    if not laws or not only or only - laws.keys():
        raise ValueError("no selected laws, or unknown --only names: " + ", ".join(sorted(only - laws.keys())))
    for directory, folders, files in os.walk(port):
        for name in folders + files:
            path = Path(directory) / name
            if path.is_symlink() or not (path.is_dir() or path.is_file()):
                raise ValueError(f"probe source must contain only regular files/directories: {path}")
    if args.keep:
        if args.keep.resolve() == port or port in args.keep.resolve().parents:
            raise ValueError("--keep must be outside the copied port directory")
        args.keep.mkdir(parents=True, exist_ok=True)
    base = Path(tempfile.mkdtemp(prefix="bisect-laws.", dir=args.keep))
    os.environ["BEND_NO_TELEMETRY"] = "1"
    results = {}
    # Set the address-space limit in a child launcher, before exec. The shared
    # runner owns the process group and also bounds pipe drain after timeout.
    launcher = [sys.executable, "-c", "import os,resource,sys; "
                "n=int(sys.argv[1]); "
                "resource.setrlimit(resource.RLIMIT_AS,(n,n)) if n else None; "
                "os.execvpe(sys.argv[2],sys.argv[2:],os.environ)", str(int(args.mem * (1 << 30))), *bend]
    for name, law in laws.items():
        if name not in only: continue
        d = base / name
        shutil.copytree(port, d)
        with open(os.path.join(d, "LAWS.bend"), "w", encoding="utf-8") as g: g.write("\n\n".join(law_hdr + [law]) + "\n")
        with open(os.path.join(d, "PROOF.bend"), "w", encoding="utf-8") as g:
            g.write("\n\n".join(proof_hdr + ([proofs[name]] if name in proofs else [])) + "\n")
        if name not in proofs:
            results[name] = ("RED", "no def Laws.%s in PROOF.bend" % name, 0.0); print(f"{name:32s} RED      no proof"); continue
        result = run(launcher, ["PROOF.bend"], cwd=d, timeout=args.timeout, merge_stderr=True)
        (d / "checker.log").write_bytes(result["out"])
        (d / "checker.exit").write_text(str(result["rc"]) + "\n")
        lines = result["out"].decode("utf-8", errors="replace").splitlines()
        last = lines[-1] if lines else ""
        kind = "TIMEOUT" if result["problem"] == "timeout" else "INCONCLUSIVE" if result["problem"] else "RED"
        if result["rc"] == 0 and re.fullmatch(r"All terms check(?:, with [0-9]+ unsafe annotations?)?\.", last):
            kind = "OK"
        detail = result["problem"] or last
        results[name] = (kind, detail, result["seconds"])
        print(f"{name:32s} {kind:12s} {result['seconds']:6.1f}s  {detail[:120]}")
    bad = [n for n, (k, _, _) in results.items() if k != "OK"]
    print(json.dumps({"laws": len(results), "ok": len(results) - len(bad), "not_ok": {n: results[n][0] for n in bad}, "probes": str(base), "verdict": "RED" if bad else "OK"}))
    return 1 if bad else 0


if __name__ == "__main__":
    try:
        sys.exit(main())
    except (OSError, ValueError) as exc:
        print(f"error: {exc}", file=sys.stderr)
        sys.exit(2)
