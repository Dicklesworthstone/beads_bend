# Experiments

## EXP-001 — children counted in one pass (`Work.child_index`)   [CLOSED, backfilled]

| field | value |
|---|---|
| program / def | `port/main.bend` / `Work.children` (S4.190), via `Views.epic_status` and `Work.figures` |
| created (UTC) | 2026-09-22 |
| agent | Claude (Opus 5.5), session 5 |
| graveyard sweep | `rg -i 'parallel\|fork\|map\|table\|lookup' perf/NEGATIVE-EVIDENCE.md` → no entry for a keyed tally; NE-INH-9 (generic `Bool.pick` in hot code) noted, the table is built with `match` helpers |
| status | CLOSED (lever kept; the number below is exploratory, not an admitted ledger row) |
| precommitted | false: the lever was written before this card (backfilled → provisional pending a bench capture) |

Hypothesis: `stats` and `epic status` are quadratic in the store size because every epic (and, in `stats`, every issue) scans the whole store; a one-pass table makes them linear.
Motivation: exploratory wall times on a 5,000-record store (c-1t, commit `0bbac9e`): `stats` 35.4 s, `epic status` 45.0 s, against about 0.8 s for a bare load (`where`); 298 ms for `stats` at 512 records (about 120× for 10× the records).
Lever: `Work.child_index` builds `Map<&2, Children>` in one pass (`ByTable`); `BEADS_RUST_SPEC=1` keeps the per-epic scan (`ByScan`); `eligible_epics` looks children up only for a live epic.
Law: `run_epic_status_spec_switch` (closed, fixture `parents`). Kill-switch parity: `epic status --json` and `stats --json` byte-identical with and without the switch on `basic`, `parents`, `hierarchy`.
Exploratory result (NOT a capture: one run each, JS lane, 2,000 records): `epic status` 3.9 s with the table, 6.0 s with the scan, same stdout sha. The C-lane capture was stopped by the host for low memory before it printed.
Retry predicate: not a loss; re-measure under `scripts/incumbent-bench.sh` when a C build fits in memory.

## EXP-002 — parallel decode of the store (`Store.load_fast`)   [RUNNING, backfilled]

| field | value |
|---|---|
| program / def | `port/main.bend` / `Store.load` (S2.24–S2.27) |
| created (UTC) | 2026-09-22 |
| agent | Claude (Opus 5.5), session 5 |
| graveyard sweep | as EXP-001; NE-INH-13 (a second parallel let per def) respected: one per level; NE-INH-17 (skewed fork): the split is by record count, records vary in size |
| status | RUNNING |
| precommitted | false: written after the lever, before any measurement |

Hypothesis: the load dominates every command (about 0.8 s of about 0.8–1.1 s on 5,000 records at c-1t, where `where` costs as much as `count`); decoding the lines in 16 tasks lowers the load's wall time at `--threads 8` by at least 2× against `--threads 1` of the same binary, with byte-identical output.
Lever: `Store.load_fast` (a fork tree over the trimmed lines, then the spec's fold); `BEADS_RUST_SPEC=1` selects `Store.load`.
Laws: `store_load_fast_basic`, `store_load_fast_precision`, `store_load_fast_refusal` (closed).
Precommitted gate: `scripts/bench-speedup.sh`-style capture on the C binary, `--threads 1` vs `--threads 8`, interleaved, cv ≤ 5% both arms, identical stdout; and the JS lane no slower than before by more than 5% (JS runs a parallel let sequentially).
