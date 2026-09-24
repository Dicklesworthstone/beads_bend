# Proposed architecture — the Bend 2 port of BEADS_RUST

<!-- Phase 2 document. Written from the spec (docs/EXISTING_BEADS_RUST_STRUCTURE.md),
     never from the original's source. Every spec clause has a home def and an
     evidence kind here; `scripts/arch-lint.py` checks that. Amended, never
     rewritten, as Phase 3 learns. Pinned Bend: 2.0.20. -->

The whole program is one pure function and a thin shell around it:

```
run : Inputs -> Outcome
Inputs  = argv, the environment values S8 names, the working directory,
          the pinned-or-read instant, and the bytes of the files S8 says are read
Outcome = stdout text, stderr text, exit code, and the file effects to perform
          (write issues.jsonl, write or remove last-touched)
```

The shell gathers `Inputs` with one effect per S8 row, calls `run` once, and
performs the `Outcome`. Nothing in the core mentions `IO`.

## 1. Core / shell split

| clause group | lives in | kind | evidence |
|---|---|---|---|
| S1 argv grammar, usage and parse-error texts (S1.1–S1.92) | core `Cli.*` over the tables of `Surface.*`: argv → `Cli.Parsed` | spec twin | golden (every `usage_*` case); closed golden laws for the short texts (`cli_*` in `port/LAWS.bend`) |
| S2.A–S2.C discovery, prefix, `metadata.json`, `config.yaml` (S2.1–S2.23) | decision in the core (`Discover.*` consumes probe results); the probes themselves in the shell | spec twin + shell | golden (`where_*`, `error_no_workspace_*`) |
| S2.D JSONL grammar, S2.E validation (S2.24–S2.56) | core `Json.*`, `Model.*`, `Store.load`, `Validate.*` | spec twin | law (round trips) + golden (`edge_precision_*`, `error_conflict_markers*`, `error_malformed_jsonl*`) |
| S2.F the import check (S2.57–S2.58; added 2026-09-23 and 2026-09-24) | core `Store.imported`: `Store.records_rule` (S2.58, dependency edges), `Store.first_conflict` over `Store.differing` (S2.57); `Store.Ids` picks the scan (`load`) or the id set (`load_fast`) | spec twin + fast twin (the id set) | golden (`edge_empty_*`, `error_load_dep_*`, `edge_load_dep_*`) + law (`store_load_fast_dangling`) |
| S3 data model (S3.1–S3.15) | core types | data | golden (every `--json` case) |
| S4.1–S4.51 identifiers, S4.52–S4.79 time and value parsing | core `Sha.*`, `Id.*`, `Time.*`, `Parse.*` | spec twin | law (closed vectors, round trips) + golden |
| S4.100–S4.198 query semantics | core `Query.*`, `Blocked.*`, `Tree.*` | spec twin | law (conservation, order) + golden |
| S4.200–S4.393 mutation semantics | core `Mutate.*`: `Store` → `Verdict` | spec twin | golden (every mutating case: the store dump is compared) |
| S5.1–S5.19 store write-back, S5.20–S5.58 JSON shapes | core `Store.text`, `Render.json_*` | spec twin | law (`load(text(s))` fixpoint) + golden |
| S5.100–S5.252 plain and quiet text | core `Render.plain_*` | spec twin | golden (L2/L3) |
| S6 orders | core comparators, §6 | spec twin | golden + order laws |
| S7 numerics | `docs/NUMERIC_PLAN.md` | spec twin | law + golden |
| S8 effects (S8.1–S8.44) | shell `main` and `Shell.*`, one def per effect | shell | golden (L3, all lanes) |
| S9 errors and exit codes (S9.1–S9.38) | core builds the `Failure` record and both renderings; shell maps it to streams and `IO.die` | spec twin + shell | golden (every `error_*` case) |
| S10 oddities | the core, bug-compatibly; judged by `docs/DISCREPANCIES.md` | spec twin | golden |

## 2. Module map

One file per module under `port/`; `port/main.bend` is the shell and the only
file that reaches a foreign def, so `port/PROOF.bend` (which imports the core
through `port/LAWS.bend`) keeps the plain verdict `All terms check.` (OQ-009).

| def / type | implements | twin kind | input owner | notes |
|---|---|---|---|---|
| `type Issue`, `type Dependency`, `type Comment`, `type Status`, `type Instant`, `type Store` (`core/model.bend`) | S3.1–S3.15 | data | | 44 members in S3.1's order; open-set strings stay `String`; `Instant{neg, secs, nanos}` per NUMERIC_PLAN |
| `type Opt`, `type Pos`, `type Clash`, `type Name`, `type Cmd`, `type Check`; `Surface.globals`, `Surface.cmd_at` (`core/surface.bend`) | S1.3, S1.16, S1.31–S1.54, S1.71, S1.72, S1.74, S1.78 | data | | amended 2026-09-20 (as built): the surface is DATA, one `Cmd` per level (36 levels: the top, 31 commands, 4 groups), built only when asked for by index; the 52 top-level words keep the original's order because the similarity tip ranks over all of them |
| `type Parsed`, `type Occ`, `type St` (`core/cli.bend`) | S1.1–S1.30, S1.68–S1.92 | data | | amended 2026-09-20 (as built): `Parsed` is `Refused` / `Helped` / `GroupHelp` / `Versioned` / `Outside` / `Command{path, opts, words}`; a command is its path, its option occurrences in argv order and its positionals, not one constructor per command form (the first plan), so one table-driven loop serves every command |
| `Cli.parse` and its helpers; `Cli.given`, `Cli.value`, `Cli.values` | S1.1–S1.30, S1.68–S1.92 | spec | consumes the argv list | one structural loop over argv driving `St`, sticky stop; refusal texts verbatim from S1; similarity (S1.80) in exact `Nat` fractions |
| `Help.text` (`core/help.bend`, generated by `scripts/gen-help-bend.py` from the spec appendix `docs/spec-parts/HELP_TEXTS.md`, clause S1.89) | S1.25–S1.29, S1.89 | data | | six verbatim texts; every other level answers "" (PLAN §3) |
| `Mode.pick` | S1, S5.100–S5.109 | spec | `+flags`, `+env` | Plain / JSON / Quiet from flags and the environment values (S8.5, S8.7) |
| `Utf8.encode`, `Utf8.decode`, `Bytes.*` (`core/bytes.bend`) | S2.24–S2.42, S4.1–S4.18 | spec | consumes the byte list | total: a malformed sequence is a verdict |
| `Json.parse`, `Json.text` (`core/json.bend`) | S2.24–S2.42, S5.1–S5.25 | spec | consumes the text; fuel = its length | value type with ordered members; escaping exactly as S5.A states |
| `Model.of_json`, `Model.to_json`, `Model.normalize` | S2.24–S2.42, S3.1–S3.15, S5.1–S5.19 | spec | consumes the value | the load-side and write-side normalizations of S2.D and S5.A, including the `""` asymmetry (S5.9) |
| `Validate.issue`, `Validate.label`, `Validate.comment`, `Validate.dep` | S2.43–S2.56 | spec | borrows the record | messages verbatim |
| `Store.load`, `Store.text` (`core/store.bend`) | S2.24–S2.42, S5.1–S5.19 | spec | consumes the file text | conflict markers and malformed lines are `Failure`s (exit 7, S9) |
| `Store.load_fast` (`core/store.bend`) | S2.24, S2.27 | fast | consumes the file text | amended 2026-09-22 (Phase 5, EXP-002): the trimmed lines decoded in a fork tree of 16 tasks (`steps_par`, one parallel let per level), then the spec's sticky fold; bound by the closed laws `store_load_fast_basic`, `store_load_fast_precision`, `store_load_fast_refusal`; `BEADS_RUST_SPEC=1` selects `Store.load` |
| `Work.child_index` / `Work.children_in` (`core/work.bend`) | S4.190 | fast | reads the model | amended 2026-09-22 (Phase 5, EXP-001): children per parent counted in one pass into a `Map` (`ByTable`) instead of one scan of the store per epic (`ByScan`, the spec twin `Work.children`); bound by the closed law `run_epic_status_spec_switch`; `BEADS_RUST_SPEC=1` selects the scan |
| `Discover.decide`, `Prefix.of` | S2.1–S2.23 | spec | consumes the probe results | the walk order and the prefix rules; the shell only probes |
| `Sha.digest`, `Sha.words`, `Sha.pad` (`core/sha256.bend`) | S4.1–S4.18, S4.50–S4.51 | spec | `+bytes` | from `port/probes/sha256/`; stack-safe word building in the port |
| `Id.seed`, `Id.hash36`, `Id.length_for`, `Id.ladder`, `Id.slug`, `Id.child`, `Id.parse`, `Id.resolve` (`core/id.bend`) | S4.1–S4.49 | spec | | `q` seeds with an empty creator (S4.16); `Id.resolve` lists ambiguous candidates in byte order (DISC-005) |
| `Time.parse`, `Time.print`, `Time.cmp`, `Time.civil`, `Time.relative`, `Parse.priority`, `Parse.labels`, `Parse.estimate`, `Parse.status` (`core/time.bend`, `core/parse.bend`) | S4.52–S4.79 | spec | | fraction 0/3/6/9; the `+00:00` suffix of S4.64 is a formatter argument |
| `Query.build` (a `Filter` or the first refusal), `Query.keeps`/`kept`, `Query.ordered` (rows with precomputed keys under one of six `le` comparators), `Query.page`, `Query.has_more`, `Query.dependents`, `Query.grouped`; planned: `Query.search`, `Query.stats` (`core/query.bend`) | S4.100–S4.156 | spec | `+store` | comparators are §6's; amended 2026-09-20 (as built): `List.sort` takes a CLOSED comparator, so the sort key and `--reverse` choose among six named `le` defs over `Query.Row` instead of one parameterized comparator |
| `Blocked.direct`, `Blocked.propagate`, `Blocked.epics`, `Blocked.map`, `Query.ready`, `Query.blocked` (`core/blocked.bend`) | S4.157–S4.178 | spec | `+store` | the three ordered steps of S4.157–S4.166 |
| `Tree.list`, `Tree.walk`, `Tree.cycles`, `Epic.status`, `Show.gather` (`core/graph.bend`) | S4.179–S4.198 | spec | `+store` | `Show.gather` reads the raw records (S10: `show` disagrees with `list`) |
| `Mutate.create`, `Mutate.q`, `Mutate.update`, `Mutate.close`, `Mutate.reopen`, `Mutate.defer`, `Mutate.undefer`, `Mutate.delete`, `Mutate.dep_add`, `Mutate.dep_remove`, `Mutate.label_*`, `Mutate.comment_add`, `Mutate.epic_close` (`core/mutate.bend`) | S4.200–S4.393 | spec | consumes the `Store`, returns `Verdict` | `Verdict{store, dirty, touched, report, warnings, failure}`; per-id skip and partial-success rules of S4.200–S4.219 |
| `Render.json_*` (one per command), `Render.error_json` | S5.20–S5.58, S9.1–S9.5 | spec | | compact success JSON, pretty error envelope |
| `Render.plain_*` (one per command), `Render.error_plain`, `Render.quiet` | S5.100–S5.252, S9.1–S9.5 | spec | | glyphs and padding verbatim |
| `Failure.*` constructors, `Failure.exit` | S9.6–S9.38 | spec | | the error table as data: code, message, hint, retryable, context, exit |
| `Run.dispatch`, `Run.command`, `Run.outcome` (`core/run.bend`) | S1, S4, S5, S9 | spec (dispatcher) | consumes `Inputs` | the single entry the shell calls |
| `main`, `Shell.args`, `Shell.env`, `Shell.cwd`, `Shell.probe`, `Shell.read_all`, `Shell.now`, `Shell.write`, `Shell.remove`, `Shell.emit`, `Shell.exit` (`main.bend`) | S8.1–S8.44 | shell | | one def per effect; `Shell.read_all` loops `File.read` with fuel from `File.size` |
| `Clock.wall`, `Sys.cwd`, `Sys.remove`, `Sys.rename`, `Sys.exit` (`main.bend` + `effs/*.c`, `effs/*.js`) | S8.12, S8.24–S8.26, S8.30–S8.31, S8.34–S8.36 | shell | | custom effects (OQ-009 shows they load on the interpreter, C and JS engines). `Sys.rename` makes the write-back a temp file plus rename. `Sys.exit` is the only exit path: `IO.die` always writes a line to stderr, which the original's `--json` errors do not (probe `port/probes/exit/`) |

## 3. State threading and failure

The store is a value. A mutating command is `Store -> Verdict`; the verdict
carries the new store, whether it is dirty (S8.42: the file is written exactly
when a record changed), the id for `last-touched` (or its removal, S8.26), the
report to render, the warnings for stderr and at most one `Failure`. A refused
command returns the incoming store untouched (S8.43). Failure is data, never a
default: `Json.parse`, `Time.parse`, `Id.parse` and every fuel-bounded def
return `Result`, and an exhausted fuel is its own `Failure` (internal, exit 1),
never a silent value. The shell has one `match` on `Outcome`.

The clock is read once by the shell (or taken from `BEADS_BEND_NOW`) and passed
down as an `Instant`. The original reads it several times per invocation
(S8.31); under one reading the port's timestamps within one invocation are
equal, as they are in every captured case. That difference is unobservable in
the harness and is recorded as a DISC when the clock lands.

## 4. Loop measures

| original loop | measure | Bend shape |
|---|---|---|
| over argv, lines, records, labels, edges, comments | the list | structural recursion with an accumulator (tail calls), then one reverse |
| JSON value parsing (nesting) | fuel = the text's length: every step consumes at least one character | `case 1n+f:`; exhausted fuel is a `Failure` |
| SHA-256 rounds and blocks | the 64-element constant list; the word list in 16-word steps | structural (probe `port/probes/sha256/`) |
| the id nonce ladder (S4.10–S4.15) | fuel 10 per length, lengths 3..8, then 2000 on the 12-character rung | nested counted loops; exhaustion is the original's id-collision error |
| base-36 digits | the requested length (at most 12) | counted |
| the upward workspace walk (S2.1–S2.9, S8.12) | fuel = the number of path components of the working directory | counted over the component list |
| `redirect` following (S8.16) | fuel 10 (the original's limit) | counted |
| BLOCKED propagation over parent-child edges (S4.160–S4.163) | fuel = the number of issues: a level adds at least one new blocked issue or stops | counted rounds over the whole edge list |
| `dep tree` walk and `dep cycles` (S4.179–S4.188) | fuel = the number of issues on a path; visited set as a `Map` | counted; a revisit is rendered as S4 states, never looped |
| `delete --cascade` closure (S4.330–S4.341) | fuel = the number of issues | counted rounds |
| child-number search (S7.9) | fuel 100 (the original stops 100 past) | counted |
| reading a file to its end (S8.13) | fuel = `File.size` / chunk + 1 | counted in the shell |
| sorting | `List.sort` (Base, stable merge) with the §6 comparators | template instance |

## 5. Numeric plan

See `docs/NUMERIC_PLAN.md`: one row per S7 clause; no `F32`; no budgeted class.

## 6. Order plan

Every order is a comparator def `le : A -> A -> Bool` that includes its full
tie-break, fed to the stable `List.sort`; byte order is code-point order of
the UTF-8 bytes (`Text.byte_le`). The store is a `List<Issue>` in file order;
a `Map` is used only for lookup and never iterated to produce output.

| S6 clause | Bend carrier | proof / golden |
|---|---|---|
| S6.1 | the store is a `List<Issue>` in line order; no output iterates a `Map` | golden: `list_json` |
| S6.2 | `Store.text` sorts by `Text.byte_le` on `id` | law: output lines are sorted; golden: `edge_precision_rewrite` |
| S6.3 | `Model.normalize`: `List.sort` by bytes, then adjacent dedup | law: idempotent; golden: `edge_precision_rewrite` |
| S6.4 | `Order.dep_export_le`: the seven keys in S6.4's order | golden: `dep_add_json`, the `basic` fixture build |
| S6.5 | `Order.comment_export_le`: `issue_id`, `created_at`, `author`, `body`, `id` | golden: `comments_add_second` |
| S6.6, S6.7 | `Order.list_default_le`: priority ↑, `created_at` ↓, `id` ↑ | golden: `list_plain`, `list_json` |
| S6.8 | `Order.created_desc_le` with `id` ↑ | golden: `list_sort_created`, `edge_precision_sort_created` |
| S6.9 | `Order.updated_desc_le` with `id` ↑ | golden: `list_sort_updated` |
| S6.10 | `Order.title_nocase_le`: ASCII-only fold, then `id` ↑ | golden: `list_sort_title`, `edge_precision_sort_title` |
| S6.11 | `Order.reversed`: primary and secondary flipped, `id` still ↑ | golden: `list_reverse` |
| S6.12 | `Order.ready_hybrid_le`: bucket (priority ≤ 1), `created_at` ↑, `id` ↑ | golden: `ready_plain`, `edge_precision_ready` |
| S6.13 | `Order.ready_priority_le` | golden: `ready_sort_priority` |
| S6.14 | `Order.ready_oldest_le` | golden: `ready_sort_oldest` |
| S6.15 | `Order.blocked_le`: priority ↑, blocker count ↓, `created_at` ↓, `id` ↑ | golden: `blocked_plain`, `blocked_json` |
| S6.16 | blocker refs sorted by bytes, deduplicated | golden: `blocked_json` |
| S6.17 | `search` reuses `Order.list_default_le` and the `--sort` comparators | golden: `search_plain`, `search_json` |
| S6.18, S6.19 | group keys sorted by bytes (`P0`…`P4` as strings) | golden: `count_by_status`, `count_by_priority_json`, `count_by_label` |
| S6.20, S6.21 | labels sorted by bytes | golden: `label_list`, `label_list_all_json` |
| S6.22 | `Order.comment_list_le`: `created_at` ↑, `id` ↑ | golden: `comments_list_json` |
| S6.23 | epics in `Order.list_default_le` | golden: `epic_status_json` |
| S6.24 | `Order.dep_list_plain_le` | golden: `dep_list` |
| S6.25 | `Order.dep_list_json_le` (a different order from S6.24) | golden: `dep_list_json` |
| S6.26, S6.27 | `Order.show_edges_le` with its four-key tie-break | golden: `show_json`, `show_plain` |
| S6.28 | `Order.tree_sibling_le` | golden: `dep_tree`, `dep_tree_json`, `scn_child_ids` |
| S6.29 | cycles start at their lowest member; cycles sorted | golden: `dep_cycles_json`; (case to add: a real cycle fixture, OQ register) |
| S6.30 | cascade ids sorted by bytes | golden: `delete_cascade` |
| S6.31 | ambiguous candidates sorted by bytes (DISC-005) | golden: `show_partial_ambiguous`, `error_show_ambiguous_json` |
| S6.32 | JSON members are emitted from ordered lists in each record's declared order; no `Map` | golden: every `--json` case |
| S6.33 | new comment id = successor of the largest id in the store (digit strings) | golden: `comments_add_json`, `comments_add_second` |
| S6.34 | lead times are whole hours, so their sum is order-independent | law: sum is permutation-invariant in `Nat`; golden: `stats_json` |
| S6.35 | results follow the argv order of the ids | golden: `show_two`, `update_two_ids`, `close_two` |
| S6.36 | harness order (`scripts/ws_inner.py`), not a port concern | golden: `scn_lifecycle` |
| S6.37 | paging slices the fully sorted list: the bucketed fetch of the original is unobservable | golden: `list_limit_one`, `list_limit_offset` |
| S6.38 | `Show.gather` keeps the raw label order of the file | golden: `edge_precision_show_json` |
| S6.39, S6.40 | filters are order-preserving `List.filter`s applied before or after the sort | law: `filter` commutes with `sort` for a stable sort; golden: every `list_*`, `ready_*` filter case |
| S6.41 | `Render.plain_show` emits sections in S6.41's fixed order | golden: `show_plain`, `show_comments`, `show_closed` |

## 7. Parallel shape plan (Phase 5, planned now)

The work that scales with the store is per-record and independent: decoding N
lines, normalizing and encoding N records, SHA-256 per id candidate. The
**seam** is `Run.outcome`: every effect (args, environment, files, clock)
happens in the shell before it, and nothing effectful happens under it. Below
the seam, Phase 5 may give `Store.load` and `Store.text` fast twins that split
the line list into balanced halves with a parallel let and concatenate the
results, each bound to its sequential spec twin by a `fast == spec` law.
No fast twin exists before Phase 5 and none is listed in the module map. There
is no bang in the program: this host has no device, and the work is
string-shaped and divergent, the kind `bend guide` assigns to the CPU lanes
("divergent work like n-queens"). Whether a fork helps at all is a Phase 5
measurement, not a claim made here.

## 8. Law plan (drafts LAWS.bend)

| law | kind | clause | when provable |
|---|---|---|---|
| `sha_empty`, `sha_abc`, `sha_two_blocks` | closed golden (FIPS 180-4 vectors) | S4.1–S4.18 | Phase 3 |
| `id_fyw`, `id_mta`, `id_170`, `id_b75` | closed golden (captured ids from their seeds) | S4.1–S4.18, S7.4, S7.5 | Phase 3 |
| `id_length_table` | closed facts at each band edge | S4.9, S7.8 | Phase 3 (edges past 163/164 stay `[inference]` until OQ-006) |
| `time_roundtrip` | round trip `parse(print(t)) == t` on canonical instants | S4.52–S4.64, S7.14 | Phase 3 |
| `time_precision_spellings` | closed goldens: the five spellings of fixture `precision` | S4.54 | Phase 3 |
| `utf8_roundtrip` | round trip `decode(encode(s)) == s` | S2.24 | Phase 3 |
| `json_string_roundtrip` | round trip on the escaping def | S5.1–S5.19 | Phase 3 |
| `labels_normalize_idempotent` | idempotence | S6.3 | Phase 3 |
| `digits_succ_is_nat_succ` | bridge on small values | S7.12 | Phase 3 |
| `counts_sum_to_total` | conservation | S4.144–S4.150, S7.17–S7.19 | Phase 3 |
| `store_text_fixpoint_basic` | closed golden: `text(load(basic)) == basic` | S5.1–S5.19 | Phase 3, if the checker's evaluator carries a 3 KB value; otherwise golden only |
| `load_fast_is_spec`, `text_fast_is_spec` | equivalence | S5.A, S2.D | Phase 5 |

## 9. Lanes and kill-switches

Lanes: interpreter, c-1t, c-8t, js; gpu MISSING (no device on this host and no
bang in the program). Every lane runs inside `scripts/ws-run.sh` through
`LANE_WRAP`. Kill-switches are read once in the shell and passed down as
values: `BEADS_BEND_NOW` (DISC-001: the pinned instant; unset = `Clock.wall`)
and `BEADS_BEND_SPEC=1` (Phase 5: select the spec twins). The core never reads
the environment.

## 10. What is proved vs golden-tested (summary the README will repeat)

Proved (laws, when Phase 3 lands them): hashing against published vectors,
id derivation on captured seeds, timestamp and UTF-8 and string-escaping round
trips, normalization idempotence, count conservation. Golden-tested: everything
else, which is most of the program: argv parsing, every message, every
rendering, the mutation semantics, the shell. Neither establishes that the
custom effects behave, that compiled intermediates fit `Nat`, or that the
backends are correct; the four lanes agreeing on 235 cases is the evidence for
those.
