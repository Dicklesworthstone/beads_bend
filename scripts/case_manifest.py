#!/usr/bin/env python3
"""Shared case-manifest and bounded-process contract for the port harnesses.

TSV argv is a JSON array of strings, or legacy whitespace-separated words.
Neither form invokes a shell. JSON preserves spaces, empty strings and tabs.
Case names are filenames, not paths; duplicate names are rejected. Columns
after stdin are annotations and do not change whether a case runs.
"""
import argparse
import hashlib
import io
import json
import math
import os
import re
import shutil
import signal
import stat
import subprocess
import sys
import tempfile
import time
from contextlib import nullcontext
from datetime import datetime, timezone
from pathlib import Path


def argv(text):
    try:
        value = json.loads(text) if text.lstrip().startswith("[") else text.split()
    except json.JSONDecodeError as exc:
        raise ValueError(f"invalid JSON argv: {exc}") from exc
    if not isinstance(value, list) or any(not isinstance(x, str) or "\0" in x for x in value):
        raise ValueError("argv must be a JSON array of strings without NUL bytes")
    return value


def cases(path):
    result, seen = [], set()
    for line_no, raw in enumerate(regular_text(path).split("\n"), 1):
        if not raw.strip() or raw.startswith("#"):
            continue
        fields = raw.split("\t")
        name = fields[0]
        if not re.fullmatch(r"[A-Za-z0-9][A-Za-z0-9_.-]*", name) or name in seen:
            raise ValueError(f"{path}:{line_no}: invalid or duplicate case name {name!r}")
        seen.add(name)
        stdin = fields[2] if len(fields) > 2 else ""
        if "\0" in stdin:
            raise ValueError(f"{path}:{line_no}: stdin path contains NUL")
        result.append((name, argv(fields[1] if len(fields) > 1 else ""), "" if stdin == "-" else stdin))
    return result


def positive(text):
    value = float(text)
    if not math.isfinite(value) or value <= 0:
        raise argparse.ArgumentTypeError("must be finite and positive")
    return value


def regular_input(path):
    """Open a regular file without waiting for a FIFO writer, then check its fd."""
    fd = os.open(path, os.O_RDONLY | os.O_NONBLOCK)  # ubs:ignore -- binary fd is transferred to fdopen below; every exception closes it.
    try:
        if not stat.S_ISREG(os.fstat(fd).st_mode):
            raise OSError(f"not a regular input file: {path}")
        stream = os.fdopen(fd, "rb")
    except BaseException:
        os.close(fd)
        raise
    return stream


def reserved_exit(rc):
    # Shell wrappers encode signals as 128+signal. Reserve the whole upper
    # range, plus GNU timeout's own failure code (125), conservatively.
    return rc is None or rc < 0 or rc in (124, 125, 126, 127) or rc >= 128


def regular_bytes(path):
    with regular_input(path) as stream:
        return stream.read()


def regular_text(path):
    with regular_input(path) as stream, io.TextIOWrapper(stream, encoding="utf-8") as text:
        return text.read()


def writable_file(path):
    """An absent path or a regular file with no aliases that a write could damage."""
    return not path.is_symlink() and (not path.exists() or
           (path.is_file() and path.stat().st_nlink == 1))


def run(command, args=(), stdin="", timeout=5.0, cwd=None, *, merge_stderr=False):
    """Return fresh bytes even when input/open/exec fails. Bound the process group.

    124..255 are reserved as inconclusive harness/infrastructure results;
    a program using these as domain exits needs an explicit recorded wrapper.
    Relative stdin paths are relative to cwd, as they are for the child.
    Only regular-file stdin is supported. The deadline also bounds pipe drain
    after killing the process group; descendants that escape the group cannot
    be contained by this runner and must not be used for trusted measurements.
    merge_stderr=True preserves the combined pipe order in out and returns
    empty err; proof verdict checks use this instead of reordering streams.
    """
    if not math.isfinite(timeout) or timeout <= 0:
        raise ValueError("timeout must be finite and positive")
    if isinstance(command, (str, bytes)) or isinstance(args, (str, bytes)):
        raise ValueError("command and args must be argument sequences, not strings")
    command = list(command) + list(args)
    if not command or any(not isinstance(x, str) or "\0" in x for x in command):
        raise ValueError("command must be a nonempty string sequence without NUL")
    start = time.monotonic()
    try:
        path = Path(cwd or ".") / stdin if stdin else None
        with regular_input(path) if path is not None else nullcontext(subprocess.DEVNULL) as stream:
            # ubs:ignore[python.taint.command] Execute the caller's explicit argv; this is a CLI runner, with no shell expansion.
            p = subprocess.Popen(command, stdin=stream, shell=False,
                                 stdout=subprocess.PIPE,
                                 stderr=subprocess.STDOUT if merge_stderr else subprocess.PIPE,
                                 start_new_session=True, cwd=cwd)
            try:
                out, err = p.communicate(timeout=timeout)
            except subprocess.TimeoutExpired:
                try:
                    os.killpg(p.pid, signal.SIGKILL)
                except ProcessLookupError:
                    pass  # The process group finished at the timeout boundary.
                try:
                    out, err = p.communicate(timeout=0.2)
                except subprocess.TimeoutExpired as exc:
                    # An escaped descendant may still hold inherited pipes.
                    # Keep the partial bytes and stop waiting for its EOF.
                    out, err = exc.output or b"", exc.stderr or b""
                    p.stdout.close()
                    if p.stderr is not None:
                        p.stderr.close()
                    try:
                        p.wait(timeout=0.2)
                    except subprocess.TimeoutExpired:
                        pass  # Do not hang on an uninterruptible kernel wait.
                return {"out": out, "err": err or b"", "rc": 124, "problem": "timeout",
                        "seconds": time.monotonic() - start}
            rc = p.returncode
            problem = f"infrastructure/signal exit {rc}" if reserved_exit(rc) else ""
            return {"out": out, "err": err or b"", "rc": rc, "problem": problem,
                    "seconds": time.monotonic() - start}
    except OSError as exc:
        message = str(exc).encode()
        return {"out": message if merge_stderr else b"", "err": b"" if merge_stderr else message, "rc": None,
                "problem": str(exc), "seconds": time.monotonic() - start}


def identity(command):
    """Canonicalize executable and existing argument paths; retain flag boundaries."""
    result = list(command)
    if result:
        result[0] = str(Path(shutil.which(result[0]) or result[0]).resolve())
    normalized = []
    for item in result:
        try:
            normalized.append(str(Path(item).resolve()) if item and Path(item).exists() else item)
        except OSError:
            normalized.append(item)
    return normalized


def file_record(path):
    path = Path(path)
    digest = hashlib.sha256()
    with regular_input(path) as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(block)
    return {"path": str(path.resolve()), "sha256": digest.hexdigest()}


def standard_stream_operand(value):
    """Recognize standard descriptors before symlinks expose caller-owned files.

    Follow path components without reading stream contents. Resolving the whole
    path first would turn /dev/stdin into the harness caller's backing file,
    even though the case subprocess receives its own separately pinned stdin.
    """
    aliases = {"/dev/stdin", "/dev/stdout", "/dev/stderr"}
    aliases.update(f"{directory}/{fd}" for directory in
                   ("/dev/fd", "/proc/self/fd", "/proc/thread-self/fd") for fd in range(3))
    path = Path(value)
    current = Path(path.anchor) if path.is_absolute() else Path.cwd()
    pending = list(path.parts[1:] if path.is_absolute() else path.parts)
    links = 0
    while pending:
        if str(current.joinpath(*pending)) in aliases:
            return True
        part = pending.pop(0)
        if part == "..":
            current = current.parent
            continue
        entry = current / part
        if entry.is_symlink():
            links += 1
            if links > 40:
                return False  # An unresolved loop is not a regular operand.
            target = entry.readlink()
            if target.is_absolute():
                current = Path(target.anchor)
                pending = list(target.parts[1:]) + pending
            else:
                pending = list(target.parts) + pending
        else:
            current = entry
    return str(current) in aliases


def argument_files(arguments):
    """Yield existing literal file operands, including --option=path values.

    This cannot discover implicit dependencies such as imported modules or
    files named inside a configuration file; pin those separately. Standard
    stream aliases are invocation endpoints, not ordinary file dependencies;
    per-case stdin files are fingerprinted separately by provenance().
    """
    for operand in arguments:
        candidates = [operand]
        if operand.startswith("-") and "=" in operand:
            candidates.append(operand.split("=", 1)[1])
        for candidate in candidates:
            try:
                if candidate and not standard_stream_operand(candidate) and Path(candidate).is_file():
                    yield candidate
            except OSError:
                pass  # Arbitrary argument text need not be a filesystem path.


def command_provenance(command):
    """Fingerprint explicit executable/argument files, not implicit imports."""
    return {"cwd": str(Path.cwd()), "executable": file_record(shutil.which(command[0]) or command[0]),
            "command_files": [file_record(operand) for operand in argument_files(command[1:])]}


def provenance(command, manifest_path, manifest):
    case_files = set()
    for _, arguments, _ in manifest:
        case_files.update(str(Path(operand).resolve()) for operand in argument_files(arguments))
    return {**command_provenance(command), "case_manifest": file_record(manifest_path),
            "case_files": [file_record(path) for path in sorted(case_files)],
            "stdin_files": [file_record(path) for path in sorted({r[2] for r in manifest if r[2]})]}


def oracle_commands(gold, supplied=None):
    """Recognize captured absolute identity and the relocatable original argv."""
    records = [] if supplied is None else [supplied]
    manifest = Path(gold) / "MANIFEST.txt"
    if supplied is None and manifest.exists():
        lines = regular_text(manifest).splitlines()
        for key in ("original_identity: ", "original_argv: "):
            matches = [line[len(key):] for line in lines if line.startswith(key)]
            if len(matches) > 1:
                raise ValueError(f"duplicate {key.strip()} in golden manifest")
            records.extend(matches)
    commands = []
    for raw in records:
        try:
            value = json.loads(raw)
        except json.JSONDecodeError as exc:
            raise ValueError(f"invalid original-command JSON: {exc}") from exc
        if not isinstance(value, list) or not value or not all(isinstance(x, str) and "\0" not in x for x in value):
            raise ValueError("original command must be a nonempty JSON string array without NUL")
        commands.append(value)
    return commands


def golden(gold, name, check_err=True):
    root = Path(gold)
    out = regular_bytes(root / f"{name}.out")
    err = regular_bytes(root / f"{name}.err") if check_err else b""
    raw = regular_text(root / f"{name}.exit").strip()
    if not re.fullmatch(r"[0-9]+", raw) or not 0 <= int(raw) <= 255:
        raise ValueError(f"{name}: invalid golden exit {raw!r}")
    return {"out": out, "err": err, "rc": int(raw)}


def score(manifest, gold, command, lane, check_err, timeout):
    rows = []
    for name, args, stdin in manifest:
        try:
            want = golden(gold, name, check_err)
        except (OSError, ValueError) as exc:
            rows.append({"name": name, "pass": False, "status": "FAIL", "stdout": "missing-or-invalid-golden",
                         "stderr": "missing-or-invalid-golden", "exit": str(exc)})
            print(f"FAIL {name:16} {exc}")
            continue
        actual = run(command, args, stdin, timeout)
        fields = {"stdout": "ok" if actual["out"] == want["out"] else "DIFF",
                  "stderr": ("ok" if actual["err"] == want["err"] else "DIFF") if check_err else "not-compared",
                  "exit": "ok" if actual["rc"] == want["rc"] else f"got {actual['rc']} want {want['rc']}"}
        status = "INCONCLUSIVE" if actual["problem"] or reserved_exit(want["rc"]) else (
            "PASS" if all(x in ("ok", "not-compared") for x in fields.values()) else "FAIL")
        row = dict(name=name, **fields, status=status, **{"pass": status == "PASS"})
        if status == "INCONCLUSIVE":
            row["reason"] = actual["problem"] or "reserved infrastructure exit in golden"
        rows.append(row)
        print(f"{'pass' if status == 'PASS' else status} {name:16} " +
              (row.get("reason", "") or " ".join(f"{k}={v}" for k, v in fields.items())))
    failed = sum(r["status"] == "FAIL" for r in rows)
    inconclusive = sum(r["status"] == "INCONCLUSIVE" for r in rows)
    return {"lane": lane, "cases": rows, "passed": sum(r["pass"] for r in rows),
            "failed": failed, "inconclusive": inconclusive, "stderr_compared": check_err,
            "verdict": "FAIL" if failed else "INCONCLUSIVE" if inconclusive else "PASS"}


def classify(actual, want):
    if actual["problem"]:
        return "INCONCLUSIVE", actual["problem"]
    if reserved_exit(want["rc"]):
        return "INCONCLUSIVE", "reserved infrastructure exit in golden"
    if actual["rc"] != want["rc"]:
        return "EXIT", f"port exit {actual['rc']}, golden exit {want['rc']}"
    if actual["err"] != want["err"]:
        return "MESSAGE", f"stderr: port={actual['err']!r} golden={want['err']!r}"
    po, go = actual["out"], want["out"]
    if po == go:
        return "NONE", "stdout, stderr and exit match"
    pl, gl = po.split(b"\n"), go.split(b"\n")
    if sorted(pl) == sorted(gl):
        return "ORDER", "same lines in different order"
    i = next((k for k, (a, b) in enumerate(zip(pl, gl)) if a != b), min(len(pl), len(gl)))
    a, b = pl[i] if i < len(pl) else b"", gl[i] if i < len(gl) else b""
    off = next((k for k, (x, y) in enumerate(zip(a, b)) if x != y), min(len(a), len(b)))
    kind = ("NUMERIC" if re.sub(rb"\d+", b"#", a) == re.sub(rb"\d+", b"#", b) else
            "FORMAT" if re.sub(rb"\s+", b"", a) == re.sub(rb"\s+", b"", b) else
            "MISSING" if len(pl) < len(gl) and all(x in gl for x in pl if x) else
            "EXTRA" if len(pl) > len(gl) and all(x in pl for x in gl if x) else "TEXT")
    return kind, f"line {i + 1}, byte {off}: port={a!r} golden={b!r}"


def validate_lanes(summary, threads, gpu=False, check_err=True, case_count=None):
    """Validate a complete successful lanes.sh result, not only its headline."""
    if type(threads) is not int or threads < 1:  # ubs:ignore[py.comparison.type-equality] JSON booleans must not pass as integer counts.
        raise ValueError("lane thread count must be a positive integer")
    if case_count is not None and (type(case_count) is not int or case_count < 1):  # ubs:ignore[py.comparison.type-equality] Reject bool as a corpus count.
        raise ValueError("lane case count must be positive")
    if not isinstance(summary, dict) or summary.get("verdict") != "PASS":
        raise ValueError("lanes did not report PASS")
    if summary.get("stderr_compared") is not check_err:
        raise ValueError("lane stderr comparison mode is missing or differs")
    rows = summary.get("lanes")
    if not isinstance(rows, list) or not rows:
        raise ValueError("no lane evidence")
    expected = {"interpreter", "c-1t", f"c-{threads}t", "js"}
    if gpu:
        expected.add("gpu")
    seen, counts = set(), set()
    for row in rows:
        if not isinstance(row, dict) or not isinstance(row.get("lane"), str):
            raise ValueError("invalid lane row")
        name = row["lane"]
        if name in seen or name not in expected:
            raise ValueError(f"duplicate or unexpected lane: {name}")
        seen.add(name)
        passed, failed, inconclusive = row.get("passed"), row.get("failed"), row.get("inconclusive", 0)
        if (row.get("verdict") != "PASS" or type(passed) is not int or passed < 1 or  # ubs:ignore[py.comparison.type-equality] Exact int excludes bool in JSON evidence.
                type(failed) is not int or failed != 0 or type(inconclusive) is not int or inconclusive != 0):  # ubs:ignore[py.comparison.type-equality] False is not a measured zero count.
            raise ValueError(f"lane lacks successful case evidence: {name}")
        if case_count is not None and passed != case_count:
            raise ValueError(f"lane case count differs from manifest: {name}")
        counts.add(passed)
    if seen != expected or len(counts) != 1:
        raise ValueError("missing lanes or inconsistent case counts")
    return summary


def validate_floor(summary, case_count, repeat=None):
    """Require a measured, identified original over the complete corpus."""
    if not isinstance(summary, dict) or summary.get("verdict") != "STABLE":
        raise ValueError("floor did not report STABLE")
    count, runs = summary.get("stable"), summary.get("repeat")
    if (type(count) is not int or type(runs) is not int or  # ubs:ignore[py.comparison.type-equality] Booleans are not measured counts.
            case_count < 1 or count != case_count or runs < 1 or (repeat is not None and runs != repeat)):
        raise ValueError("floor case/repetition counts differ from the request")
    if summary.get("unstable") != [] or summary.get("inconclusive") != []:
        raise ValueError("floor has missing or unsuccessful case evidence")
    if summary.get("oracle_identity_checked") is not True:
        raise ValueError("floor did not verify the captured original identity")
    return summary


WHERE = {"EXIT": "S1.4 / S9", "MESSAGE": "S1.2, S1.3, S9", "ORDER": "S6",
         "NUMERIC": "S4 / S7 / NUMERIC_PLAN", "FORMAT": "S5", "MISSING": "S5 / S2",
         "EXTRA": "S2.1", "TEXT": "the clause the case cites", "NO-GOLDEN": "Phase 0",
         "INCONCLUSIVE": "runner / environment", "NONE": "none"}


def main():
    if len(sys.argv) < 2 or sys.argv[1] in ("--help", "-h"):
        print(__doc__.strip())
        print("\nInternal modes: conform, capture, floor, first; use their .sh entry points for help.")
        return 0 if len(sys.argv) > 1 else 2
    mode, raw = sys.argv[1], sys.argv[2:]
    if "--" not in raw:
        raise ValueError("a -- separator before the program command is required")
    split = raw.index("--")
    options, command = raw[:split], raw[split + 1:]
    if not command:
        raise ValueError("program command is empty")
    parser = argparse.ArgumentParser()
    if mode == "first":
        parser.add_argument("case")
    parser.add_argument("cases")
    parser.add_argument("gold")
    parser.add_argument("--timeout", type=positive, default=5.0)
    if mode in ("conform", "floor"):
        parser.add_argument("--no-stderr", action="store_true")
    if mode == "conform":
        parser.add_argument("--lane", default="port")
        parser.add_argument("--oracle-command", help="original command as a JSON string array")
    if mode == "floor":
        parser.add_argument("--repeat", type=int, default=3)
    if mode == "capture":
        reason = parser.add_mutually_exclusive_group()
        reason.add_argument("--repin")
        reason.add_argument("--disc")
    args = parser.parse_args(options)
    manifest = cases(args.cases)
    if not manifest:
        if mode == "conform":
            print("EMPTY: no cases; a lane with nothing to check is not green")
            print(json.dumps({"lane": args.lane, "cases": [], "passed": 0, "failed": 1, "inconclusive": 0,
                              "stderr_compared": not args.no_stderr, "verdict": "FAIL"}, separators=(",", ":")))
            return 1
        if mode == "floor":
            print(json.dumps({"repeat": args.repeat, "stable": 0, "unstable": [], "inconclusive": [], "verdict": "UNSTABLE"}))
            return 1
        raise ValueError("manifest has no cases")
    if mode == "conform":
        originals = oracle_commands(args.gold, args.oracle_command)
        if any(identity(command) == identity(original) for original in originals):
            raise ValueError("oracle-on-oracle conformance is refused; use floor.sh to measure original stability")
        result = score(manifest, args.gold, command, args.lane, not args.no_stderr, args.timeout)
        if not originals:
            print("note: original identity unavailable; oracle-on-oracle guard unverified (supply --oracle-command)", file=sys.stderr)
        result["oracle_identity_checked"] = bool(originals)
        print(json.dumps(result, separators=(",", ":"), allow_nan=False))
        return 0 if result["verdict"] == "PASS" else 1
    if mode == "floor":
        if args.repeat < 1:
            raise ValueError("--repeat must be positive")
        originals = oracle_commands(args.gold)
        if originals and not any(identity(command) == identity(original) for original in originals):
            raise ValueError("floor command differs from the captured original; use the captured command or explicitly recapture")
        if not originals:
            print("note: original identity unavailable; floor command unverified", file=sys.stderr)
        try:
            before = provenance(command, args.cases, manifest)
        except OSError as exc:
            before = None
            print(f"INCONCLUSIVE: cannot fingerprint before floor measurement: {exc}", file=sys.stderr)
        unstable, inconclusive = set(), set()
        for n in range(args.repeat):
            result = score(manifest, args.gold, command, f"original-{n + 1}", not args.no_stderr, args.timeout)
            unstable.update(r["name"] for r in result["cases"] if r["status"] == "FAIL" and r["stdout"] != "missing-or-invalid-golden")
            inconclusive.update(r["name"] for r in result["cases"] if r["status"] == "INCONCLUSIVE" or r["stdout"] == "missing-or-invalid-golden")
        try:
            unchanged = before is not None and before == provenance(command, args.cases, cases(args.cases))
        except (OSError, ValueError) as exc:
            unchanged = False
            print(f"INCONCLUSIVE: cannot fingerprint after floor measurement: {exc}", file=sys.stderr)
        if not unchanged:
            inconclusive.update(name for name, _, _ in manifest)
            print("INCONCLUSIVE: original/source/input fingerprint unavailable or changed during floor measurement")
        result = {"repeat": args.repeat, "stable": len(manifest) - len(unstable | inconclusive),
                  "unstable": sorted(unstable), "inconclusive": sorted(inconclusive),
                  "oracle_identity_checked": bool(originals),
                  "verdict": "INCONCLUSIVE" if inconclusive else "UNSTABLE" if unstable else "STABLE"}
        print(json.dumps(result, separators=(",", ":")))
        return 0 if result["verdict"] == "STABLE" else 1
    if mode == "first":
        found = [row for row in manifest if row[0] == args.case]
        if not found:
            raise ValueError(f"unknown case {args.case}")
        try:
            want = golden(args.gold, args.case)
            if reserved_exit(want["rc"]):
                kind, detail = "INCONCLUSIVE", "reserved infrastructure exit in golden"
            else:
                kind, detail = classify(run(command, found[0][1], found[0][2], args.timeout), want)
        except (OSError, ValueError) as exc:
            kind, detail = "NO-GOLDEN", str(exc)
        print(f"{args.case}: {kind} -> open {WHERE[kind]}\n  {detail}")
        print(json.dumps({"case": args.case, "class": kind, "open": WHERE[kind], "detail": detail}))
        return 0 if kind == "NONE" else 1
    if mode == "capture":
        out = Path(args.gold)
        if out.is_symlink() or (out.exists() and not out.is_dir()):
            raise ValueError("golden destination must be a directory, not a symlink or special file")
        reason = f"repin: {args.repin}" if args.repin else f"disc: {args.disc}" if args.disc else ""
        if not reason and ((out.exists() and any(p.suffix in (".out", ".err", ".exit") for p in out.iterdir())) or (out / "MANIFEST.txt").exists()):
            print("refused: goldens exist; a recapture needs --repin <reason> or --disc DISC-nnn", file=sys.stderr)
            return 3
        if (args.repin is not None and not args.repin.strip()) or (args.disc is not None and not re.fullmatch(r"DISC-\d+", args.disc)):
            raise ValueError("recapture requires a nonblank reason or DISC-nnn")
        targets = [out / f"{name}.{suffix}" for name, _, _ in manifest for suffix in ("out", "err", "exit")]
        targets += [out / "MANIFEST.txt", out / "MANIFEST.prev.txt"]
        if any(not writable_file(p) for p in targets):
            raise ValueError("golden destinations must be regular files without symlinks or hardlinks")
        # Complete every run before writing any golden: one broken fixture cannot
        # leave a partly replaced oracle. Keep scratch artifacts for diagnosis.
        captured = []
        try:
            before = provenance(command, args.cases, manifest)
        except OSError as exc:
            print(f"INCONCLUSIVE: cannot fingerprint executable/input: {exc}; goldens unchanged", file=sys.stderr)
            return 1
        for name, arguments, stdin in manifest:
            result = run(command, arguments, stdin, args.timeout)
            if result["problem"]:
                print(f"INCONCLUSIVE {name}: {result['problem']}; goldens unchanged", file=sys.stderr)
                return 1
            captured.append((name, result))
        lines = ["captured: " + datetime.now(timezone.utc).isoformat(),
                 "original: " + " ".join(command), "original_argv: " + json.dumps(command),
                 "original_identity: " + json.dumps(identity(command)),
                 f"cases: {args.cases} ({len(manifest)} cases)"]
        try:
            after = provenance(command, args.cases, manifest)
        except OSError as exc:
            print(f"INCONCLUSIVE: cannot fingerprint after capture: {exc}; goldens unchanged", file=sys.stderr)
            return 1
        if after != before:
            print("INCONCLUSIVE: executable/source/input changed during capture; goldens unchanged", file=sys.stderr)
            return 1
        if out.is_symlink() or any(not writable_file(p) for p in targets):
            raise ValueError("golden destinations changed to links or special files during capture")
        lines.append("provenance: " + json.dumps(before, separators=(",", ":")))
        out.mkdir(parents=True, exist_ok=True)
        if reason:
            backup = Path(tempfile.mkdtemp(prefix="goldens-before-repin."))
            for path in out.iterdir():
                if path.is_file():
                    shutil.copy2(path, backup / path.name)
            print(f"previous goldens preserved at {backup}")
            if (out / "MANIFEST.txt").exists():
                shutil.copy2(out / "MANIFEST.txt", out / "MANIFEST.prev.txt")
        if reason:
            lines.append("recapture: " + reason)
        lines.append("sha256:")
        for name, result in captured:
            for suffix, content in (("out", result["out"]), ("err", result["err"]), ("exit", f"{result['rc']}\n".encode())):
                filename = f"{name}.{suffix}"
                (out / filename).write_bytes(content)
                lines.append(f"  {hashlib.sha256(content).hexdigest()}  {filename}")
            print(f"{name:16} exit {result['rc']} stdout {len(result['out'])} bytes")
        (out / "MANIFEST.txt").write_text("\n".join(lines) + "\n", encoding="utf-8")
        print(f"wrote {len(captured)} cases to {out}")
        return 0
    raise ValueError(f"unknown harness mode {mode}")


if __name__ == "__main__":
    try:
        sys.exit(main())
    except (OSError, ValueError, json.JSONDecodeError) as exc:
        print(f"error: {exc}", file=sys.stderr)
        sys.exit(2)
