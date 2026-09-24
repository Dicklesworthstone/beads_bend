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

## EXP-003 — the duplicate-id check through an id table (`Store.Held`)   [CLOSED, backfilled]

| field | value |
|---|---|
| program / def | `port/main.bend` / `Store.accepted`, `Store.has_id` (S2.40), via `Store.load_fast` |
| created (UTC) | 2026-09-24 |
| agent | Claude (Opus 5.5), session 7 |
| graveyard sweep | `rg -i 'map\|table\|lookup\|trie' perf/NEGATIVE-EVIDENCE.md` → no entry; EXP-001 is the precedent (a `Map` beside a scan) |
| status | CLOSED (lever kept; the numbers are exploratory, not an admitted ledger row) |
| precommitted | false: written after the lever |

Hypothesis: every command's load is quadratic in the record count, because each record's id is compared with every record loaded before it (`has_id`).
Motivation (single runs, C of `b25ac04`, `count`): 500 records 0.74 s, 1,000 2.37 s, 2,000 8.62 s, 4,000 32.9 s (synthetic stores of one repeated `large` record); real store copies 967 records 4.65 s, 6,553 records 105.7 s.
Lever: the fast fold carries `Held{st, ids}`, `ids` a `Map<&2, Bool>` of the ids loaded so far; one `Map.has` per record. `Store.load` (the spec loop, `BEADS_RUST_SPEC=1`) keeps the scan.
Laws: `store_load_fast_duplicate` (closed, the `dup_id` store: both loaders refuse line 3), with `store_load_fast_basic`, `_precision`, `_refusal`.
Exploratory result (NOT a capture: one run each, JS lane): 1,000 records 2.50 → 1.54 s, 2,000 7.74 → 2.32 s, 4,000 → 4.25 s (linear).
Retry predicate: not a loss; capture under `scripts/incumbent-bench.sh` with the C binary when the pin is carried.

## EXP-004 — the BLOCKED relation's lookups through an id table (`Blocked.Index`, `Blocked.Keys`)   [CLOSED, backfilled]

| field | value |
|---|---|
| program / def | `port/main.bend` / `Blocked.lookup`, `Blocked.among` (S4.157) in `Blocked.relation`, `Work.rows`, `Work.candidates`, `Work.live_keys`, `Work.stored_blocked` |
| created (UTC) | 2026-09-24 |
| agent | Claude (Opus 5.5), session 7 |
| graveyard sweep | as EXP-003 |
| status | CLOSED (lever kept; the numbers are exploratory, not an admitted ledger row) |
| precommitted | false: written after the lever |

Hypothesis: `blocked`, `ready` and `stats` are dominated by scans of the store per edge and per record; ids sharing a long prefix (`historical_soldiers-`, 20 bytes) make each comparison long.
Motivation (JS lane, after EXP-003, a 967-record real store copy with 533 `blocks` and 75 `parent-child` edges): `count` 2.75 s, `list --json` 2.89 s, but `blocked --json` 10.88 s, `ready --json` 11.00 s, `stats --json` 12.57 s.
Lever: `Blocked.index(spec, all)` (a `Map` of the records by id, first record of an id wins as in `lookup`) and `Blocked.keyed(spec, ids)` (a `Map` set); `BEADS_RUST_SPEC=1` selects the scans (`ByList`, `KeyList`).
Laws: `work_blocked_rows_table`, `work_figures_table`, `work_ready_table` (closed, fixture `basic`). Kill-switch parity: the corpus on the JS lane gives 991/993 both with and without `BEADS_RUST_SPEC=1` (the same two DISC-010/011 draws), and the three commands give identical bytes both ways on the 967-record store.
Exploratory result (NOT a capture: one run each, JS lane, the same store): `blocked --json` 3.24 s, `ready --json` 3.14 s, `stats --json` 3.09 s.
Retry predicate: not a loss; capture under `scripts/incumbent-bench.sh` with the C binary.
