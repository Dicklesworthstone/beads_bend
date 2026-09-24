#!/usr/bin/env python3
"""ws_inner: the in-sandbox half of ws-run.sh (see its header for the contract).

Runs inside bubblewrap with a fresh tmpfs at /mnt. Builds /mnt/proj from a
fixture, runs the inner command once (or once per scenario step) with the
pinned environment, passes stdout/stderr through untouched, and appends the
store's state to stdout ONLY when the run changed it. A read-only command
that rewrites the store therefore fails its golden.
"""
import calendar
import hashlib
import json
import os
import re
import shutil
import subprocess
import sys
import time
from pathlib import Path

WS = Path("/mnt/proj")
DEFAULT_TIME = "2026-01-02 03:04:05"
STATE_FILES = ("issues.jsonl", "last-touched")
FAKETIME_LIB = "toolchain/faketime/root/usr/lib/x86_64-linux-gnu/faketime/libfaketime.so.1"
PASSED_ENV = ("PATH", "HOME", "USER", "TZ", "NO_COLOR", "RUST_LOG", "BEND_NO_TELEMETRY", "BEND_BIN")
STEP_TIMEOUT = 600  # seconds per step; a fully frozen clock once hung `br` forever.
# 600, not the original 120: the interpreter lane type-checks the whole book on
# every case, which at this port's size is 2 min 28 s per run (measured
# 2026-09-20, `bend port/main.bend -- --help`), so a 120 s step budget killed
# every interpreter case as a sandbox failure (exit 125). The oracle's own
# steps take under a second, so the budget never reaches them: the re-capture
# that carries this change moved 0 of 1056 golden hashes.
AMBIGUOUS_INLINE = re.compile(rb"(Ambiguous ID '[^']*': matches \[)([^\]]*)(\])")
VERSION_REPORT = re.compile(rb"^[A-Za-z0-9_.-]+ version [0-9]+\.[0-9]+\.[0-9]+ .+$")
VERSION_FLAG = re.compile(rb"^[A-Za-z0-9_.-]+ [0-9]+\.[0-9]+\.[0-9]+$")


def die(message):
    print(f"ws-run: {message}", file=sys.stderr)
    sys.exit(125)


def epoch(stamp):
    # "<seconds>" or "<seconds>.<fraction>": the port's BEADS_BEND_NOW. A fraction is
    # passed to libfaketime as written, which parses it as a double, so a case pins
    # only fractions a double holds exactly (.25, .125, .5): .123456789 came back as
    # .123456788 from the original.
    whole, dot, fraction = stamp.partition(".")
    if dot and not (fraction.isdigit() and len(fraction) <= 9):
        die(f"bad @time {stamp!r} (want YYYY-MM-DD hh:mm:ss[.fraction], UTC)")
    try:
        seconds = calendar.timegm(time.strptime(whole, "%Y-%m-%d %H:%M:%S"))
    except ValueError:
        die(f"bad @time {stamp!r} (want YYYY-MM-DD hh:mm:ss[.fraction], UTC)")
    return f"{seconds}.{fraction}" if dot else str(seconds)


def snapshot():
    beads = WS / ".beads"
    state = {}
    for name in STATE_FILES:
        path = beads / name
        state[name] = hashlib.sha256(path.read_bytes()).hexdigest() if path.is_file() else None
    return state


def setup(root, fixture, store=None):
    (Path("/mnt/home")).mkdir(parents=True, exist_ok=True)
    WS.mkdir(parents=True, exist_ok=True)
    if fixture == "none" and store is None:
        return
    beads = WS / ".beads"
    beads.mkdir()
    if fixture == "nostore" and store is None:
        # @fx=nostore: a `.beads/` directory with nothing in it (OQ-011, OQ-103)
        return
    if store is not None:
        # @store=<absolute path>: an external store copied in as issues.jsonl (the
        # real-store sweep; a probe, never a golden). The root filesystem is bound
        # read-only, so the source cannot be changed from inside the sandbox.
        source = Path(store)
        if not source.is_absolute() or not source.is_file():
            die(f"@store wants an absolute path to a file, got {store!r}")
        shutil.copyfile(source, beads / "issues.jsonl")
        return
    source = root / "goldens" / "fixtures" / f"{fixture}.jsonl"
    if not source.is_file():
        die(f"no fixture {source}")
    shutil.copyfile(source, beads / "issues.jsonl")
    for extra in ("config.yaml", "last-touched", "redirect"):
        side = root / "goldens" / "fixtures" / f"{fixture}.{extra}"
        if side.is_file():
            shutil.copyfile(side, beads / extra)


def run(inner, argv, stamp, oracle, root, extra_env=(), sub=""):
    # The child inherits this process's environment, which ws-run.sh built
    # with `bwrap --clearenv --setenv …`: that list is the one allowlist. Only
    # the pinned instant is added here (it can change between scenario steps),
    # and the case's own `@env=NAME=VALUE` directives, identically for the
    # original and the port (OQ-014, OQ-023, OQ-085, OQ-086, OQ-087).
    os.environ["BEADS_BEND_NOW"] = str(epoch(stamp))
    for name, value in extra_env:
        os.environ[name] = value
    if oracle:
        lib = root / FAKETIME_LIB
        if not lib.is_file():
            die(f"no libfaketime at {lib}")
        os.environ["LD_PRELOAD"] = str(lib)  # affects children only, never this interpreter
        os.environ["FAKETIME"] = stamp
        os.environ["DONT_FAKE_MONOTONIC"] = "1"
    sys.stdout.flush()
    sys.stderr.flush()
    # Running the command named on our own command line is this tool's
    # contract (as for env(1), timeout(1) and conform.sh): the caller is the
    # harness, argv is a list (no shell), the environment is cleared and the
    # run is time-bounded. UBS python.taint.command flags it by design.
    try:
        done = subprocess.run(inner + argv, cwd=WS / sub, timeout=STEP_TIMEOUT, check=False, capture_output=True)  # ubs:ignore[python.taint.command] Running the command named on our own command line is this wrapper's contract (as for env(1) and timeout(1)): list argv, no shell, cleared environment, bounded time. Accepted by the repository owner 2026-09-20.
    except subprocess.TimeoutExpired:
        die(f"step exceeded {STEP_TIMEOUT}s: {argv}")
    except OSError as exc:
        die(f"cannot run {inner[0]}: {exc}")
    shape = versions(argv)
    sys.stdout.buffer.write(canon_version(canon(done.stdout), shape))
    sys.stdout.buffer.flush()
    sys.stderr.buffer.write(canon_version(canon(done.stderr), shape))
    sys.stderr.buffer.flush()
    return done.returncode


def canon(data):
    """DISC-005 (OrderLeak), and nothing else: the original lists the
    candidates of an ambiguous partial id in hash-random order (it differs
    between two runs of one command). Sort those lists by byte order, in the
    inline message and in the pretty-printed `context.matches` block. Applied
    identically to the original and to the port; every other byte passes
    through untouched, and the exit code is never canonicalized."""
    if b"Ambiguous ID '" not in data:
        return data

    def inline(match):
        return match.group(1) + b", ".join(sorted(match.group(2).split(b", "))) + match.group(3)

    data = AMBIGUOUS_INLINE.sub(inline, data)
    if b'"AMBIGUOUS_ID"' not in data:
        return data
    lines, out, i = data.split(b"\n"), [], 0
    while i < len(lines):
        out.append(lines[i])
        if lines[i].strip() == b'"matches": [':
            j = i + 1
            while j < len(lines) and lines[j].strip() not in (b"]", b"],"):
                j += 1
            block = lines[i + 1:j]
            if j < len(lines) and block:
                indent = block[0][:len(block[0]) - len(block[0].lstrip())]
                items = sorted(line.strip().rstrip(b",") for line in block)
                out.extend(indent + item + (b"," if k < len(items) - 1 else b"") for k, item in enumerate(items))
                i = j
                continue
        i += 1
    return b"\n".join(out)


def versions(argv):
    """DISC-006: is this step the `version` command or the top-level version
    flag? Decided from argv alone, identically for the original and the port."""
    for word in argv:
        if word in ("--version", "-V"):
            return True
        if not word.startswith("-"):
            return word == "version"
    return False


def canon_version(data, shape):
    """DISC-006 (Platform), and nothing else: `br version` reports build
    metadata of a different program (its Rust toolchain, its target triple,
    its git branch), which the port cannot truthfully print, so the port
    reports its own name, version, Bend and the original it ports. Only for a
    version step, and identically on both sides, the report is reduced to its
    SHAPE: one line `<name> version <version> <details>`, one line
    `<name> <version>` for the flag, or one JSON object with a string member
    `version`. Anything else passes through and still fails its golden; the
    exit code is never canonicalized."""
    if not shape:
        return data
    body = data.strip()
    if not body:
        return data
    if body.startswith(b"{"):
        try:
            report = json.loads(body)
        except ValueError:
            return data
        if isinstance(report, dict) and isinstance(report.get("version"), str):
            return b'{"version": <string>}\n'
        return data
    if b"\n" in body:
        return data
    if VERSION_REPORT.match(body):
        return b"<name> version <version> <details>\n"
    if VERSION_FLAG.match(body):
        return b"<name> <version>\n"
    return data


def dump_changes(before):
    after = snapshot()
    for name in STATE_FILES:
        if after[name] != before[name]:
            path = WS / ".beads" / name
            sys.stdout.flush()
            sys.stdout.buffer.write(f"--- .beads/{name} ---\n".encode())
            sys.stdout.buffer.write(path.read_bytes() if path.is_file() else b"(absent)\n")
            sys.stdout.buffer.flush()
    return after


def listing():
    # @ls: every path under `.beads/` after the step, sorted, a directory with a
    # trailing `/`, a file with its size in bytes (OQ-005, OQ-008, OQ-084)
    beads = WS / ".beads"
    sys.stdout.flush()
    sys.stdout.buffer.write(b"--- ls .beads ---\n")
    if not beads.is_dir():
        sys.stdout.buffer.write(b"(absent)\n")
    else:
        for path in sorted(beads.rglob("*")):
            rel = path.relative_to(beads).as_posix()
            line = f"{rel}/" if path.is_dir() else f"{rel} {path.stat().st_size}"
            sys.stdout.buffer.write(line.encode() + b"\n")
    sys.stdout.buffer.flush()


def main():
    args = sys.argv[1:]
    oracle = bool(args) and args[0] == "--oracle"
    if oracle:
        args = args[1:]
    if "::" not in args:
        die("usage: ws-run.sh [--oracle] <inner command…> :: <case args…>")
    cut = args.index("::")
    inner, case = args[:cut], args[cut + 1:]
    if not inner:
        die("empty inner command")
    root = Path(os.environ.get("WS_ROOT", ""))
    if not (root / "goldens").is_dir():
        die("WS_ROOT does not name the port root")

    fixture, stamp, scenario, store = "empty", DEFAULT_TIME, None, None
    extra_env, sub, ls, staged = [], "", False, []
    while case and case[0].startswith("@"):
        key, _, value = case.pop(0)[1:].partition("=")
        if key == "fx":
            fixture = value
        elif key == "time":
            stamp = value
        elif key == "scn":
            scenario = value
        elif key == "store":
            store = value
        elif key == "env":
            name, eq, setting = value.partition("=")
            if not eq or not re.fullmatch(r"[A-Za-z_][A-Za-z0-9_]*", name) or name in PASSED_ENV or name == "BEADS_BEND_NOW":
                die(f"@env wants NAME=VALUE with a NAME not already set by the sandbox, got {value!r}")
            extra_env.append((name, setting))
        elif key == "cwd":
            if not re.fullmatch(r"[A-Za-z0-9_.-]+(/[A-Za-z0-9_.-]+)*", value) or ".." in value.split("/"):
                die(f"@cwd wants a relative path below the workspace, got {value!r}")
            sub = value
        elif key == "ls" and not value:
            ls = True
        elif key == "file":
            # @file=<name>: goldens/stdin/<name> staged as /mnt/proj/<name> (the markdown import of
            # `create -f`, OQ-051)
            if not re.fullmatch(r"[A-Za-z0-9_][A-Za-z0-9_.-]*", value) or not (root / "goldens" / "stdin" / value).is_file():
                die(f"@file wants the name of a file under goldens/stdin/, got {value!r}")
            staged.append(value)
        else:
            die(f"unknown directive @{key}")

    if scenario is None:
        setup(root, fixture, store)
        if sub:
            (WS / sub).mkdir(parents=True, exist_ok=True)
        for name in staged:
            shutil.copyfile(root / "goldens" / "stdin" / name, WS / name)
        before = snapshot()
        code = run(inner, case, stamp, oracle, root, extra_env, sub)
        dump_changes(before)
        if ls:
            listing()
        sys.exit(code)
    if extra_env or sub or ls or staged:
        die("@env, @cwd, @ls and @file apply to a single step, not to @scn")

    path = root / "goldens" / "scenarios" / f"{scenario}.scn"
    if not path.is_file():
        die(f"no scenario {path}")
    steps = []
    for number, line in enumerate(path.read_text().splitlines(), 1):
        line = line.strip()
        if not line or line.startswith("#"):
            continue
        if line.startswith("@fx="):
            fixture = line[4:]
        elif line.startswith("@time="):
            steps.append(("time", line[6:]))
        elif line.startswith("["):
            try:
                argv = json.loads(line)
            except ValueError as exc:
                die(f"{path}:{number}: {exc}")
            if not (isinstance(argv, list) and all(isinstance(item, str) for item in argv)):
                die(f"{path}:{number}: a step is a JSON array of strings")
            steps.append(("run", argv))
        else:
            die(f"{path}:{number}: expected @fx=, @time= or a JSON argv array")
    setup(root, fixture)
    state = snapshot()
    for kind, value in steps:
        if kind == "time":
            stamp = value
            continue
        header = "$ " + json.dumps(value, ensure_ascii=False) + "\n"
        sys.stdout.write(header)
        sys.stderr.write(header)
        code = run(inner, value, stamp, oracle, root)
        state = dump_changes(state)
        sys.stdout.write(f"[exit {code}]\n")
    sys.exit(0)


if __name__ == "__main__":
    main()
