#!/usr/bin/env python3
"""case-gen: emit ONE generated input (bytes on stdout) for a seed and a class,
so scripts/diff-explore.sh can run the original and the port on it and compare.
Deterministic: the same (class, seed, size, lang) gives the same bytes on every
host, so a seed in explore.log or a MANIFEST comment reproduces the input.

Classes:
  lines   text lines: ASCII words, é, 😀, an empty line, leading/trailing
          spaces, a tab, one very long line; the newline style is chosen per
          seed (LF, CRLF, lone CR, or no final newline); a UTF-8 BOM prefix in
          one seed of ten (UNICODE-AND-ENCODINGS "Cases to add").
  csv     name,amount rows: names from a small alphabet (ties, duplicates, an
          empty name, leading/trailing spaces, é, 😀); amounts at the numeric
          boundaries 0 1 2 2^31-1 2^31 2^32-1 2^32 2^48-2 2^48-1 2^48 and the
          lenient-parsing shapes +5, " 5 ", 007, 1_000, 5.0, -0 (LANGUAGE-GUIDES
          parsing table); a blank line in one seed of five; newline style and
          BOM as for lines.
  ints    whitespace-separated integers at the same boundaries, one per line.
  argv    a JSON list: an argument vector of --size words drawn from none, one,
          extra, repeated flags, --flag=value, a huge N, 0, negative-looking,
          an empty string, a lone --, unicode (argv-explore.sh covers the
          systematic shapes; this covers the random combinations).
--lang adds the source language's own edges to the boundary set: python adds
fullwidth digits and 1_000; js adds 2^53-1, 2^53+1 and 0x1f; go and rust add
i32/i64 edges and +5; c adds 12px and " 7".

usage: case-gen.py --class lines|csv|ints|argv --seed S [--size N] [--lang python|js|go|rust|c]
exit: 0, 2 usage. Output: the input bytes on stdout (class argv: a JSON list).
"""
import argparse
import json
import random
import sys

BOUNDS_ANY = [0, 1, 2, 2**31 - 1, 2**31, 2**32 - 1, 2**32, 2**48 - 2, 2**48 - 1, 2**48]
BOUNDS_LANG = {
    "python": ["１２", "1_000", 12],
    "js": [2**53 - 1, 2**53 + 1, "0x1f"],
    "go": [-2**31, 2**63 - 1, "+5"],
    "rust": [-1, 2**63 - 1, "+5"],
    "c": ["12px", " 7", 2**31 - 1],
}
LENIENT = ["+5", " 5 ", "007", "1_000", "5.0", "-0", "５", "1e3", ""]
NAMES = ["a", "b", "aa", "A", "alice", "bob", "é", "😀", "", " x", "x ", "x\ty", "a,b"]
NEWLINES = ["\n", "\r\n", "\r"]
WORDS = ["alpha", "beta", "gamma", "é", "😀", "", " lead", "trail ", "tab\tsep", "-", "--", "0", "007"]
FLAGS = ["--top", "--top=2", "--top", "-n", "--verbose", "--threads", "--gpu", "--help", "--"]
DEFAULT_SIZE = {"lines": 12, "csv": 10, "ints": 12, "argv": 3}


def framed(rng, rows):
    """Join rows with one newline style; drop the final newline in one seed of five; BOM in one of ten."""
    nl = rng.choice(NEWLINES)
    text = nl.join(rows) + (nl if rng.random() < 0.8 else "")
    if rng.random() < 0.1:
        text = "﻿" + text
    return text.encode("utf-8")


def amounts(lang):
    return BOUNDS_ANY + BOUNDS_LANG.get(lang, [])


def gen_lines(rng, size, lang):
    rows = []
    for _ in range(size):
        r = rng.random()
        if r < 0.05:
            rows.append("x" * rng.choice([256, 4096, 70000]))
        elif r < 0.10:
            rows.append("")
        else:
            rows.append(" ".join(rng.choice(WORDS) for _ in range(rng.randint(1, 4))))
    return framed(rng, rows)


def gen_csv(rng, size, lang):
    rows = []
    for _ in range(size):
        name = rng.choice(NAMES)
        v = rng.choice(LENIENT) if rng.random() < 0.2 else rng.choice(amounts(lang))
        rows.append(f"{name},{v}")
    if rng.random() < 0.2:
        rows.insert(rng.randint(0, len(rows)), "")
    return framed(rng, rows)


def gen_ints(rng, size, lang):
    rows = [str(rng.choice(amounts(lang))) for _ in range(size)]
    if rows and rng.random() < 0.2:
        rows[rng.randrange(len(rows))] = rng.choice(LENIENT)
    return framed(rng, rows)


def gen_argv(rng, size, lang):
    pool = FLAGS + WORDS + [str(x) for x in amounts(lang)] + ["-1", "+1", "1e9", "99999999999999999999"]
    n = rng.choice([0, 1, size, size + 3])
    return (json.dumps([rng.choice(pool) for _ in range(n)], ensure_ascii=False) + "\n").encode("utf-8")


GEN = {"lines": gen_lines, "csv": gen_csv, "ints": gen_ints, "argv": gen_argv}


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--class", dest="cls", required=True, choices=sorted(GEN))
    ap.add_argument("--seed", type=int, required=True)
    ap.add_argument("--size", type=int, default=None, help="rows (lines/csv/ints) or words (argv); default per class")
    ap.add_argument("--lang", default="", choices=["", "python", "js", "go", "rust", "c"])
    if any(x in ("--help", "-h") for x in sys.argv[1:]):  # the contract, exit 0 (the try below maps every SystemExit to 2)
        ap.print_help(); raise SystemExit(0)
    try:
        a = ap.parse_args()
    except SystemExit:
        sys.exit(2)
    size = a.size if a.size is not None else DEFAULT_SIZE[a.cls]
    if size < 0:
        print("error: --size must be >= 0", file=sys.stderr)
        sys.exit(2)
    rng = random.Random(f"{a.cls}:{a.seed}:{size}:{a.lang}")
    sys.stdout.buffer.write(GEN[a.cls](rng, size, a.lang))
    sys.stdout.buffer.flush()


if __name__ == "__main__":
    main()
