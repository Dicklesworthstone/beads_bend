# Experiment Card — EXP-<NNN>   (append to perf/EXPERIMENTS.md)

<!-- Write BEFORE the lever. Losses get cards too. A card written after the
     fact says so; its exploratory result stays provisional until a
     separately specified confirmation run succeeds on fresh data. -->

| field | value |
|---|---|
| experiment_id | EXP-<NNN> |
| program / def | `<x.bend>` / `<def>` |
| created (UTC) | <ts> |
| agent | <name> |
| graveyard sweep | `rg -i '<lever>' perf/NEGATIVE-EVIDENCE.md` → <no entry \| NE-<id>, predicate holds because …> |
| status | PROPOSED \| RUNNING \| CLOSED |
| precommitted | true \| false (backfilled → provisional pending fresh confirmation) |

## Hypothesis
<one falsifiable sentence: "balanced splitting exposes the same 2^d leaf
computations more evenly and lowers median wall time at 8 threads by 20%">

## Motivation
<the hotspot row (def, self time, axis, evidence path), the keep-audit
line, or the scaling-law shape that points here>

## Lever (one)
<the shape change; which twin stays as the kill-switch; the law that will
bind them>

## Precommitted gate
<e.g. "≥ 20% below the named prior artifact at the same 8T settings;
cv ≤ 5% both arms; A/A null ratio in [1/1.05, 1.05] (the helper's default
5% symmetric ratio gate); identical tested
outputs; relevant laws complete and trusted dependencies reviewed">

## One-line invocation
```bash
scripts/bench-speedup.sh <x.bend> --threads 1,8 --gpu off,on --runs 5 --aa --max-cv 5 --strict
```

This helper measures modes of one build. A before/after source experiment
needs an invocation that interleaves both retained artifacts at the same
runtime settings. Record that command instead when testing a source lever.

## Results inline
Choose one value in each choice field; the block below is an editable
template, not machine-ready YAML until those choices are filled.

```text
result_status: <WIN | PROVISIONAL_LOCAL_WIN | NEGATIVE(reverted) | NEGATIVE(retained-for-proof) | NO_EVIDENCE | VOID>
result_summary: "<before> → <after> ms at <arm>, cv <v>%, cksum <n>, laws green (unsafe <k>)"
route_attested: "<--gpu on or a positive span> plus <dispatch evidence> on <device>" | "CPU pool (--gpu off)"
evidence_dir: perf/<lever>/
closed_at_utc: <ts>
retry_condition_predicate: "<explicit arming condition; never 'later'>"
killing_metric: "wall on <hw>" | "keep count (proxy)" | "rounds (proxy)"
```

An OK capture is not a proof of a WIN. Review the paired samples/A/A drift,
compiler fingerprint, law coverage and actual route before promotion;
record `reverted` only after the source was actually reverted with authorization.

## Closure
<ledger row filed (which file), disposition landed (commit with the class
in the subject), follow-on issue for the retry predicate>
