#!/usr/bin/env python3
"""Compare BUDGETED float tokens using an absolute OR relative budget per token.

usage: budget-compare.py <golden.out> <port.out> [--abs A] [--rel R] [--measure]
Non-numeric tokens, integer tokens and whitespace remain byte-identical.
Finite decimal tokens are compared exactly, without rounding them to binary64
first. Values outside the finite, nonzero binary64 range are refused.
--measure reports deviations without accepting invalid or discrete values.
Exit: 0 PASS/MEASURED, 1 mismatch, 2 usage/input error. Last line: strict JSON.
"""
import argparse
import json
import math
import re
import sys
from decimal import Decimal, InvalidOperation
from fractions import Fraction
from case_manifest import regular_bytes

FLOAT = re.compile(rb"^[+-]?(\d+\.\d*|\.\d+|\d+)([eE][+-]?\d+)?$")
INT = re.compile(rb"^[+-]?\d+$")
NONFINITE = re.compile(rb"^[+-]?(nan|inf|infinity)$", re.IGNORECASE)


def budget(text):
    try:
        value = Decimal(text)
    except InvalidOperation as exc:
        raise argparse.ArgumentTypeError("budget must be a decimal number") from exc
    if not value.is_finite() or value < 0 or not math.isfinite(float(value)) or value and not float(value):
        raise argparse.ArgumentTypeError("budget must be finite and nonnegative")
    return value


def reported(value):
    """JSON diagnostics may round; pass/fail comparisons never do."""
    try:
        approximation = float(value)
    except OverflowError:
        approximation = math.inf
    underflow = approximation == 0 and value != 0
    overflow = not math.isfinite(approximation)
    return (None if underflow or overflow else approximation), overflow, underflow


def exact(value):
    return None if value == math.inf else f"{value.numerator}/{value.denominator}"


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("golden")
    parser.add_argument("port")
    parser.add_argument("--abs", dest="abs_b", type=budget, default=Decimal(0))
    parser.add_argument("--rel", dest="rel_b", type=budget, default=Decimal(0))
    parser.add_argument("--measure", action="store_true")
    args = parser.parse_args()
    gold, port = regular_bytes(args.golden).split(b"\n"), regular_bytes(args.port).split(b"\n")
    mismatches, over = [], []
    max_abs = max_rel = Fraction(0)
    abs_budget, rel_budget = Fraction(args.abs_b), Fraction(args.rel_b)
    worst, floats = None, 0
    if len(gold) != len(port):
        mismatches.append(f"line count: golden {len(gold)} port {len(port)}")
    for ln, (g, p) in enumerate(zip(gold, port), 1):
        gt, pt = re.findall(rb"\S+|\s+", g), re.findall(rb"\S+|\s+", p)
        if len(gt) != len(pt):
            mismatches.append(f"line {ln}: token count {len(gt)} vs {len(pt)}")
            continue
        for col, (g_tok, p_tok) in enumerate(zip(gt, pt), 1):
            label = f"line {ln}, token {col}: {g_tok!r} vs {p_tok!r}"
            if NONFINITE.fullmatch(g_tok) or NONFINITE.fullmatch(p_tok):
                mismatches.append(label + " (nonfinite float)")
                continue
            numeric = FLOAT.fullmatch(g_tok) and FLOAT.fullmatch(p_tok)
            if not numeric or INT.fullmatch(g_tok) or INT.fullmatch(p_tok):
                if g_tok != p_tok:
                    mismatches.append(label + " (discrete token)")
                continue
            try:
                gd, pd = Decimal(g_tok.decode()), Decimal(p_tok.decode())
            except InvalidOperation:
                mismatches.append(label + " (unsupported decimal exponent)")
                continue
            gf, pf = float(gd), float(pd)
            if (not math.isfinite(gf) or not math.isfinite(pf) or
                    gf == 0 and gd != 0 or pf == 0 and pd != 0):
                mismatches.append(label + " (not representable as a finite comparator float)")
                continue
            floats += 1
            gv, pv = Fraction(gd), Fraction(pd)
            delta = abs(pv - gv)
            rel = delta / abs(gv) if gv else (Fraction(0) if delta == 0 else math.inf)
            if delta > max_abs:
                max_abs, worst = delta, label
            max_rel = max(max_rel, rel)
            # Each token independently gets either budget; maxima may belong
            # to different tokens and must not be combined into one verdict.
            if delta > abs_budget and rel > rel_budget:
                over.append(label)
    verdict = "FAIL" if mismatches or (over and not args.measure) else "MEASURED" if args.measure else "PASS"
    for item in mismatches[:10]:
        print("DISCRETE " + item)
    for item in over[:10] if not args.measure else []:
        print("OVER " + item)
    abs_report, abs_overflow, abs_underflow = reported(max_abs)
    rel_report, rel_overflow, rel_underflow = reported(max_rel)
    print(f"floats compared: {floats}; max abs {abs_report}; max rel {rel_report}; {verdict}")
    print(json.dumps({"floats": floats, "max_abs": abs_report, "max_rel": rel_report,
                      "max_abs_exact": exact(max_abs), "max_rel_exact": exact(max_rel),
                      "unbounded_abs": abs_overflow, "unbounded_rel": rel_overflow,
                      "underflow_abs": abs_underflow, "underflow_rel": rel_underflow,
                      "worst": worst, "discrete_mismatches": len(mismatches), "over_budget_tokens": len(over),
                      "abs_budget": float(args.abs_b), "rel_budget": float(args.rel_b),
                      "abs_budget_exact": str(args.abs_b), "rel_budget_exact": str(args.rel_b),
                      "verdict": verdict}, allow_nan=False))
    return 0 if verdict in ("PASS", "MEASURED") else 1


if __name__ == "__main__":
    try:
        sys.exit(main())
    except (OSError, ValueError) as exc:
        print(f"error: {exc}", file=sys.stderr)
        sys.exit(2)
