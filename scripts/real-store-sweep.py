#!/usr/bin/env python3
"""real-store-sweep.py: the original and the port on copies of the real .beads stores of this host (this port's own
probe, beads bb-acg / bb-wv5). A probe, never a golden: the stores are other projects' trackers and are not committed.

usage: real-store-sweep.py snapshot DIR          copy every .beads/issues.jsonl under /data/projects, /dp and
                                                  /home/ubuntu (depth 4) into DIR/stores/, never overwriting one
       real-store-sweep.py run DIR PORT_BIN [-j N] [--out FILE]
                                                  run `count`, `list --json`, `ready --json`, `blocked --json`,
                                                  `stats --json` and `show <first id> --json` on the original and on
                                                  the port (a C binary, absolute path) through scripts/ws-run.sh with
                                                  @store=<snapshot>; compare stdout, stderr and exit code
Writes DIR/<FILE> (default results.jsonl; one line per store and command, resumable) and prints each difference,
then one JSON summary line last: {"stores", "runs", "differences", "stores_with_difference"}.
Excluded: /dp/beads_rust (the live tree AGENTS.md forbids), legacy/, coding-agent-search. DIR is best outside the
repository (the snapshots are hundreds of MB).
exit: 0 ran (differences are data, not a failure), 2 usage.
"""
import concurrent.futures as cf
import hashlib
import json
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
ROOTS = ["/data/projects", "/dp", "/home/ubuntu"]
EXCLUDE = ("/dp/beads_rust", "/data/projects/beads_rust", "/legacy/", "coding-agent-search")
COMMANDS = [["count"], ["list", "--json"], ["ready", "--json"], ["blocked", "--json"], ["stats", "--json"]]
TIMEOUT = 900


def snapshot(out):
    stores = out / "stores"
    found = subprocess.run(["find", *ROOTS, "-maxdepth", "4", "-path", "*/.beads/issues.jsonl"],
                           capture_output=True, text=True).stdout.split("\n")
    stores.mkdir(parents=True, exist_ok=True)
    seen, n = set(), 0
    for p in sorted(filter(None, found)):
        real = str(Path(p).resolve())
        if real in seen or any(x in real for x in EXCLUDE) or real.startswith(str(out.resolve())):
            continue
        seen.add(real)
        name = Path(real).parent.parent.name + "-" + hashlib.sha256(real.encode()).hexdigest()[:8]
        dest = stores / f"{name}.jsonl"
        if dest.exists():
            continue  # never overwrite a snapshot: every run compares the same bytes
        dest.write_bytes(Path(real).read_bytes())
        n += 1
    print(f"snapshot: {n} new stores, {len(list(stores.glob('*.jsonl')))} in {stores}")


def first_id(path):
    for line in path.read_text(errors="replace").split("\n"):
        try:
            return json.loads(line)["id"]
        except Exception:
            continue
    return None


def one(inner, store, argv):
    cmd = [str(ROOT / "scripts" / "ws-run.sh"), *inner, "::", f"@store={store}", *argv]
    try:
        r = subprocess.run(cmd, capture_output=True, timeout=TIMEOUT, cwd=ROOT)
        return r.stdout, r.stderr, r.returncode
    except subprocess.TimeoutExpired:
        return b"", b"TIMEOUT", -1


def job(port_bin, store, argv):
    o = one(["--oracle", "br", "--no-db"], store, argv)
    p = one([port_bin, "--threads", "8", "--gpu", "off", "--"], store, argv)
    diff = [k for k, a, b in zip(("stdout", "stderr", "exit"), o, p) if a != b]
    return {"store": store.name, "bytes": store.stat().st_size, "argv": argv, "diff": diff,
            "oracle_exit": o[2], "port_exit": p[2],
            "oracle_err": o[1][:300].decode(errors="replace"), "port_err": p[1][:300].decode(errors="replace"),
            "oracle_sha": hashlib.sha256(o[0]).hexdigest()[:16], "port_sha": hashlib.sha256(p[0]).hexdigest()[:16]}


def run(out, port_bin, jobs, name):
    stores = sorted((out / "stores").glob("*.jsonl"), key=lambda s: s.stat().st_size)
    work = []
    for s in stores:
        fid = first_id(s)
        for argv in COMMANDS + ([["show", fid, "--json"]] if fid else []):
            work.append((s, argv))
    results = out / name
    done = {}
    if results.exists():
        for line in results.read_text().split("\n"):
            if line:
                r = json.loads(line)
                done[(r["store"], json.dumps(r["argv"]))] = r
    todo = [(s, a) for s, a in work if (s.name, json.dumps(a)) not in done]
    with open(results, "a") as f, cf.ThreadPoolExecutor(jobs) as ex:
        for r in ex.map(lambda sa: job(port_bin, *sa), todo):
            done[(r["store"], json.dumps(r["argv"]))] = r
            f.write(json.dumps(r) + "\n")
            f.flush()
            if r["diff"]:
                print(f"DIFF {r['store']} {' '.join(r['argv'][:2])} {r['diff']} oracle={r['oracle_exit']} port={r['port_exit']}", flush=True)
    rows = list(done.values())
    bad = [r for r in rows if r["diff"]]
    print(json.dumps({"stores": len({r['store'] for r in rows}), "runs": len(rows), "differences": len(bad),
                      "stores_with_difference": len({r['store'] for r in bad})}))


def main(argv):
    if argv[:1] in (["--help"], ["-h"]):
        print(__doc__.strip())
        return 0
    if argv[:1] == ["snapshot"] and len(argv) == 2:
        snapshot(Path(argv[1]))
        return 0
    if argv[:1] == ["run"] and len(argv) >= 3 and Path(argv[2]).is_absolute():
        j = int(argv[argv.index("-j") + 1]) if "-j" in argv else 2
        o = argv[argv.index("--out") + 1] if "--out" in argv else "results.jsonl"
        run(Path(argv[1]), argv[2], j, o)
        return 0
    print(__doc__.strip(), file=sys.stderr)
    return 2


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
