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
STEP_TIMEOUT = 120  # seconds per step; a fully frozen clock once hung `br` forever
AMBIGUOUS_INLINE = re.compile(rb"(Ambiguous ID '[^']*': matches \[)([^\]]*)(\])")


def die(message):
    print(f"ws-run: {message}", file=sys.stderr)
    sys.exit(125)


def epoch(stamp):
    try:
        return calendar.timegm(time.strptime(stamp, "%Y-%m-%d %H:%M:%S"))
    except ValueError:
        die(f"bad @time {stamp!r} (want YYYY-MM-DD hh:mm:ss, UTC)")


def snapshot():
    beads = WS / ".beads"
    state = {}
    for name in STATE_FILES:
        path = beads / name
        state[name] = hashlib.sha256(path.read_bytes()).hexdigest() if path.is_file() else None
    return state


def setup(root, fixture):
    (Path("/mnt/home")).mkdir(parents=True, exist_ok=True)
    WS.mkdir(parents=True, exist_ok=True)
    if fixture == "none":
        return
    beads = WS / ".beads"
    beads.mkdir()
    source = root / "goldens" / "fixtures" / f"{fixture}.jsonl"
    if not source.is_file():
        die(f"no fixture {source}")
    shutil.copyfile(source, beads / "issues.jsonl")
    for extra in ("config.yaml", "last-touched"):
        side = root / "goldens" / "fixtures" / f"{fixture}.{extra}"
        if side.is_file():
            shutil.copyfile(side, beads / extra)


def run(inner, argv, stamp, oracle, root):
    # The child inherits this process's environment, which ws-run.sh built
    # with `bwrap --clearenv --setenv …`: that list is the one allowlist. Only
    # the pinned instant is added here (it can change between scenario steps).
    os.environ["BEADS_BEND_NOW"] = str(epoch(stamp))
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
        done = subprocess.run(inner + argv, cwd=WS, timeout=STEP_TIMEOUT, check=False, capture_output=True)
    except subprocess.TimeoutExpired:
        die(f"step exceeded {STEP_TIMEOUT}s: {argv}")
    except OSError as exc:
        die(f"cannot run {inner[0]}: {exc}")
    sys.stdout.buffer.write(canon(done.stdout))
    sys.stdout.buffer.flush()
    sys.stderr.buffer.write(canon(done.stderr))
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

    fixture, stamp, scenario = "empty", DEFAULT_TIME, None
    while case and case[0].startswith("@"):
        key, _, value = case.pop(0)[1:].partition("=")
        if key == "fx":
            fixture = value
        elif key == "time":
            stamp = value
        elif key == "scn":
            scenario = value
        else:
            die(f"unknown directive @{key}")

    if scenario is None:
        setup(root, fixture)
        before = snapshot()
        code = run(inner, case, stamp, oracle, root)
        dump_changes(before)
        sys.exit(code)

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
