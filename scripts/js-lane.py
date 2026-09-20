#!/usr/bin/env python3
"""Run emitted Bend JavaScript in Bun while preserving every application argument.

usage: js-lane.py FILE.js [--] [ARG ...]
The optional first -- belongs to this launcher; later -- values belong to the
program. Bun otherwise consumes an additional separator before Bend's IO.args
handles its own separator. Bun is retained for generated bun:ffi file effects.
"""
import json
import os
from pathlib import Path
import sys

if len(sys.argv) < 2 or sys.argv[1] in ("--help", "-h"):
    print(__doc__.strip())
    sys.exit(0 if len(sys.argv) > 1 else 2)
entry = Path(sys.argv[1]).resolve()
if not entry.is_file():
    sys.exit(f"js-lane: file not found: {entry}")
args = sys.argv[2:]
if args[:1] == ["--"]:
    args = args[1:]
env = dict(os.environ)
env["P2B_JS_ENTRY"] = str(entry)
env["P2B_JS_ARGV"] = json.dumps(["--", *args])
code = '''import { pathToFileURL } from "node:url";
const file = process.env.P2B_JS_ENTRY;
const args = JSON.parse(process.env.P2B_JS_ARGV);
delete process.env.P2B_JS_ENTRY; delete process.env.P2B_JS_ARGV;
process.argv = [process.argv[0], file, ...args];
await import(pathToFileURL(file).href);
'''
try:
    os.execvpe("bun", ["bun", "-e", code], env)
except OSError as exc:
    print(f"js-lane: {exc}", file=sys.stderr)
    sys.exit(127)
