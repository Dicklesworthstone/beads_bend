# Port state — BEADS_RUST → Bend 2

<!-- Read FIRST on every resume; rewritten at the END of every session.
     Facts only, each with the command that produced it. No "should",
     no "later". -->

## Where we are

| field | value |
|---|---|
| phase | 3 reference port, at its exit gate. Done: −1 fit screen; 0 truth pack (414 goldens, floor STABLE); 1 spec, first pass (899 clauses, spec-lint 0 findings, blind self-containment review 10/10); 2 architecture (arch-lint PASS, NUMERIC_PLAN, parity skeleton). Phase 1's second and third extraction passes and the capture of the extractors' remaining proposed cases have NOT run (S12.4). Of the port: twenty-eight core modules under `port/core/` and the IO shell `port/main.bend` with three custom effects (`Sys.exit`, `Sys.cwd`, `Sys.remove`). **Every command the corpus exercises runs, reads and writes the store.** This session closed the last declared read-path gap: **`dep tree` now performs the traversal of S4.182–S4.185** (`Views.tree_walk`) instead of answering the port's own failure whenever the root had a neighbour. **414 of 414 cases pass on c-1t, on c-8t and on js (the same 414)** |
| tier | T3 |
| bend | `bend 2.0.20` (release binary from the official installer, sha256 `fab9e564c578a0a1…`; run through `scripts/bend-cli.sh`); drift vs the skills' 2.0.16: DRIFT, itemized in PLAN §2b and §8. Hit again this session: a bare `1n + depth` is refused (`a type for this operator (write (a + b : Nat))`) |
| original | `br 0.6.0`, tag `v0.6.0`, commit `b1cfebe`, release binary sha256 `21b967c1ae68df1a…`, run as `scripts/ws-run.sh --oracle br --no-db ::` |
| last updated | 2026-09-22 by Claude (Opus 5, 1M context), session 4 |
| remote | `origin` = https://github.com/Dicklesworthstone/beads_bend (public); sessions end with `main` pushed. The granular backlog is `docs/BACKLOG.md` |

Every command below assumes: `cd /data/projects/beads_bend; export BEND_NO_TELEMETRY=1 BEND_CLI=$PWD/scripts/bend-cli.sh LANE_WRAP=$PWD/scripts/ws-run.sh`

## Last gate outputs (paste, do not paraphrase)

| gate | command | result | date |
|---|---|---|---|
| c-1t | `./scripts/conform.sh goldens/cases.tsv goldens --lane c-1t --timeout 120 -- scripts/ws-run.sh <out>/bn --threads 1 --gpu off -- ::` (binary from `(cd port && $BEND_CLI main.bend -o <out>/bn)`, 6 min 55 s, 12 MB) | `{"lane": "c-1t", "passed": 414, "failed": 0, "inconclusive": 0, "stderr_compared": true, "verdict": "PASS", "oracle_identity_checked": true}` | 2026-09-21 |
| c-8t | the same binary, `--lane c-8t --timeout 120 … --threads 8` | `{"lane": "c-8t", "passed": 414, "failed": 0, "inconclusive": 0, "stderr_compared": true, "verdict": "PASS", "oracle_identity_checked": true}` | 2026-09-21 |
| js | `./scripts/conform.sh … --lane js --timeout 120 -- scripts/ws-run.sh python3 $PWD/scripts/js-lane.py <out>/bn.js -- ::` (bundle from `(cd port && $BEND_CLI main.bend -o <out>/bn.js)`, 1 min 08 s) | `{"lane": "js", "passed": 414, "failed": 0, "inconclusive": 0, "stderr_compared": true, "verdict": "PASS", "oracle_identity_checked": true}` | 2026-09-21 |
| interpreter | `./scripts/conform.sh <sample>.tsv goldens --lane interpreter --timeout 900 -- $PWD/scripts/ws-run.sh bash -c 'exec 3>> "$1" \|\| exit 125; shift; exec "$@"' bend-interpreter <note> $PWD/scripts/interp-lane.sh $PWD/scripts/bend-cli.sh $PWD/port/main.bend -- ::` over `create_min`, `list_plain`, `dep_tree_diamond`, `dep_tree_repeat`, `dep_tree_max_depth`, `dep_tree_both` | `{"lane": "interpreter", "passed": 6, "failed": 0, "inconclusive": 0, "stderr_compared": true, "verdict": "PASS", "oracle_identity_checked": true}` | 2026-09-21 |
| lanes | `LANE_WRAP=$PWD/scripts/ws-run.sh ./scripts/lanes.sh goldens/cases.tsv goldens $PWD/port/main.bend --threads 8 --timeout 120 --interpreter-timeout 600` | BLOCKER: not run at HEAD. Started this session against a frozen snapshot of commit `198afa2`, then STOPPED after 2 h 32 min of its interpreter lane: the snapshot went stale the moment `core/views.bend` changed, and this host has 30 GB, so the interpreter lane (a 9.3 GB `bend` per case) and the port's C build (19 GB peak) cannot both run. The three fast lanes above were run one at a time instead, on one build | 2026-09-21 |
| proofs | `(cd port && $BEND_CLI PROOF.bend)` | `All terms check.` (0 @unsafe; 51 laws — the 50 of session 3 plus `run_dep_tree_repeat`, the closed golden of `goldens/dep_tree_repeat`; bend 2.0.20) | 2026-09-22 |
| law coverage | `./scripts/law-coverage.sh` | `{"laws": 51, "proofs": 51, "unproved": "", "ghost_proofs": "", "ghost_cited": "", "uncited": "fast_is_spec", "duplicate_laws": [], "duplicate_proofs": [], "unsafe": 0, "unsafe_annotations": 0, "verdict": "OK"}` | 2026-09-22 |
| spec | `python3 -B scripts/spec-lint.py docs/EXISTING_BEADS_RUST_STRUCTURE.md goldens/cases.tsv` | PASS: 899 clauses, 414 cases, 414 cases cited, 0 finding(s) | 2026-09-22 |
| architecture | `python3 -B scripts/arch-lint.py` | `{"clauses": 764, "homed": 764, "numeric_rows": 25, "s6_rows": 36, "fast_twins": 0, "missing": [], "findings": 0, "verdict": "PASS"}` | 2026-09-21 |
| parity | `./scripts/parity-board.sh docs/FEATURE_PARITY.md` | `{"rows": 42, "present": 4, "partial": 25, "missing": 0, "excluded": 13, "na": 0, "no_evidence": 0, "verdict": "PARTIAL"}` | 2026-09-22 |
| floor | `./scripts/floor.sh <new30>.tsv goldens --repeat 3 --timeout 120 -- scripts/ws-run.sh --oracle br --no-db ::` | `{"repeat":3,"stable":30,"unstable":[],"inconclusive":[],"oracle_identity_checked":true,"verdict":"STABLE"}` | 2026-09-21 |
| floor-corpus | the same over `goldens/cases.tsv` | `{"repeat":3,"stable":384,"unstable":[],"inconclusive":[],"oracle_identity_checked":true,"verdict":"STABLE"}` | 2026-09-20 |
| cases | `./scripts/cases-lint.sh goldens/cases.tsv` | `{"cases": 414, "errors": 0, "notes": 0, "classes_missing": "", "verdict": "OK"}` | 2026-09-21 |
| port lint | `python3 -B scripts/port-lint.py port/main.bend port/core/*.bend --laws port/LAWS.bend` | `{"files": 29, "findings": 193, "errors": 0, "warnings": 2, "infos": 191, "by_rule": {"PL-02": 191, "PL-01": 1, "PL-04": 1}, "laws": "port/LAWS.bend", "verdict": "FINDINGS"}` | 2026-09-21 |
| incumbent | `./scripts/incumbent-bench.sh --pin …` | NOT_RUN: Phase 5 has not begun (the parity gate comes first) | |

Reading the table. The three fast lanes are the whole corpus, case for case, on one build of `port/main.bend`. The interpreter row is a 6-case SAMPLE at HEAD, not the corpus, and four of its six cases are the new traversal; it took about 45 minutes, because one interpreter run type-checks the whole book. Its first attempt used RELATIVE script paths and returned `{"passed":0,"failed":0,"inconclusive":6,…,"verdict":"INCONCLUSIVE"}` — exit 125 on every case, because `ws-run.sh` runs with cwd `/mnt/proj` inside bwrap; the interpreter lane needs ABSOLUTE paths, as `scripts/lanes.sh` uses, and the harness rightly called that INCONCLUSIVE, not FAIL. The `floor-corpus` row is session 3's line at 384 cases and was NOT re-run over 414; the 30 cases added this session were floored on their own (the `floor` row). `./scripts/pin-check.sh docs/PIN.toml`: YELLOW, no RED (the same two as session 3: `original_commit`, `manifest_version`); `manifest_hashes` GREEN over 1242 hashes, `case_count` GREEN (414 cases = 414 goldens = MANIFEST 414). `./scripts/claims-lint.sh docs/*.md perf/*.md README.md`: `claims-lint: 0 hit(s) in 16 file(s)`. `python3 -B scripts/gen-help-bend.py --check`: `gen-help-bend: up to date`. `ubs` was NOT run: no shell or Python file changed this session.

**Lost work, recovered.** Mid-session, every UNCOMMITTED change in the tree (the new law and its proof, OQ-129/OQ-130, the spec amendments, the parity row, the backlog, this file and the README) was discarded by a checkout in the shared tree that this session did not run; the code, fixtures and goldens survived because they had already been committed (`75bc42d`…`b86b2aa`). Everything was re-applied from this session's record and committed in small pieces (`36b622b`, `b1be300`, `1d4ce41`, `fa5c394`), each gate re-run after. The lesson is in the next action's form: commit each finished unit at once.

What the port does NOT do, and answers with its own `INTERNAL_ERROR` failure (exit 1) instead of guessing — **`dep tree` with children has come off this list**: `delete --hard` and `--from-file` (OQ-128); a `--json` delete preview or dry run, and `--dry-run` with `--force`/`--cascade` (OQ-127); `label add/remove` with more than two positionals and no `-l` (OQ-122) or with a positional that resolves to nothing (OQ-123); `dep add` with a tombstoned endpoint or a `parent-child` edge to an `external:` target (OQ-124), and `--metadata`; the 64-label ceiling (OQ-125); `comments add -f`; the `stats` breakdowns and an average lead time whose tie binary64 does not hold exactly (OQ-078); `list --overdue/--tree/--pretty`; `ready --parent/--recursive/--epic`; `blocked --detailed`; `update --parent` and the other flags named in `core/update.bend`'s header; `close --transition-comment/--session/--bypass-policy`; the help text of the 30 levels no case prints. `dep tree --format mermaid` is ignored (text is always rendered, OQ-130).

## What this session added

- **Two fixtures, both the original's own output** (`scripts/make-fixture.sh`; provenance `goldens/scenarios/build_graph.scn`, `build_hierarchy.scn`). `graph`: a diamond, a three-chain and an ancestor back edge. `hierarchy`: a shared node that HAS a child (the only way to reach `repeat` true) and two branches tied on priority, so the status rank decides — against the title order.
- **30 cases** under two `golden-capture.sh --repin` runs whose MANIFEST diffs named only the new cases (0 existing golden hashes moved): 22 `dep_tree_*`, and `dep_cycles_graph{,_json}`, `dep_list_graph_{parent,none}`, `blocked_graph{,_json}`, `ready_graph{,_json}`, `list_graph`, `show_graph_root{,_json}`.
- **`Views.tree_walk`**: one fuel-bounded worklist DFS in a single def (Bend forbids mutual recursion, and a `match` may not scrutinize a call's result). Fuel is one per issue, two per stored dependency, plus one — sound because each id expands at most once and only an expanded node pushes; the ancestor filter, not the fuel, ends a cycle. All 22 `dep_tree_*` passed on their first run on js, c-1t and c-8t.
- **The BLOCKED relation was validated, not changed**: `blocked_graph` is the first case with two blockers on one issue and with a genuine blocking cycle (`proj-9vw → proj-wjh → proj-a14 → proj-9vw`); `core/blocked.bend` answered it byte for byte on its first run.

## Open items

| id | what | blocks | owner |
|---|---|---|---|
| OQ register | 130 rows, 16 RESOLVED, 114 OPEN (`docs/OPEN_QUESTIONS.md`). Opened this session: OQ-129 and OQ-130 | phase 4 convergence (every OQ resolved or excluded) | author |
| OQ-129 | **`dep cycles` has never reported a cycle.** The original refuses a blocking cycle at `dep add` on every route tried (both endpoints open; the source force-closed first; the target closed) and ignores `related` cycles (S4.186), so no scenario through the oracle can build one. A `cycles` fixture would be the first hand-written store that is not the original's own output — defensible, since a git merge of two `issues.jsonl` files is unchecked, but a change to how fixtures are made | the `dep cycles` half of the parity row staying `partial` | **the repository owner: may a hand-written `cycles` fixture be added?** |
| OQ-005, OQ-006 | `br --no-db init`; the id-length band edges | S4.9's `[inference]` bands | author |
| DISC-001 … DISC-008 | DISC-001…007 ACCEPTED under the owner's delegation, DISC-008 RESOLVED; `scripts/converge.sh` now reports `open DISC 0` (finding (d) of round 6) | none | the repository owner |
| not read yet | `.beads/config.yaml`, `BEADS_DIR`, the upward walk and redirects (S2.1–S2.23); the duplicate-id refusal (S2.40) and load validation (S2.43–S2.56); a wall clock when `BEADS_BEND_NOW` is unset (`Clock.wall`) | backlog E3, E4.2, E4.3, E6.6 | author |
| probe scenarios | `goldens/scenarios/probe_*.scn` (9 files) are the exploration that settled the sibling order and the cycle routes; no case names one. Keep, or fold into the two `build_*.scn` comments? No file is deleted without written permission | nothing | the repository owner |

## Find-fix rounds (Phase 4/5)

| round | lens | new genuine findings | fixed | clean | date |
|---|---|---|---|---|---|
| 1 | the spec clauses the corpus does not reach, over the five commands session 3 ported (author round) | 1: S4.341 — a second `delete` of an already-tombstoned id rewrote four fields and the store; the original writes nothing | 1 (`core/remove.bend`) | no | 2026-09-20 |
| 2 | the S9 error table against the port's failures (author round) | 2: S9.22 — the `SELF_DEPENDENCY` context key is `id`, not `issue_id`; S9.11 — the shell's `String.trim_end` ate a trailing SPACE | 2 (`core/edges.bend`; `port/main.bend`) | no | 2026-09-20 |
| 3 | the JSON envelopes and payload rows of the six commands session 3 ported (author round) | 0: six captured envelopes matched the port's spec-derived text byte for byte | 0 | yes | 2026-09-20 |
| 4 | Quiet mode over the mutations (S5.106, S5.107, S9.26, OQ-015) (author round) | 2: `close --quiet` still printed the per-item `Warning: Skipped …` lines; `reopen --quiet` printed nothing where the original prints `✓ Reopened` | 2 (`core/run.bend`) | no | 2026-09-20 |
| 5 | the actor ladders (S4.200, S4.201) (author round) | 0: `actor_flag_dep_add`, `actor_flag_delete` and `actor_flag_label_add` matched on their first run | 0 | yes | 2026-09-20 |
| 6 | the dependency graph beyond depth 0: real depth, a diamond, an ancestor back edge, a shared node with children, a depth limit, the `up` and `both` directions (author round) | 4: (a) S5.179 stated no precedence — a node can be `truncated` AND `repeat`, and `(truncated) ` wins the plain prefix (`dep_tree_repeat`, `dep_tree_repeat_json`); (b) S4.184's four sort keys had never been separated by a case — the status rank beats title (`dep_tree_repeat`) and title beats id (`dep_tree_up_basic`), which refutes a title-only tie-break; (c) the original's cycle check misses a mixed pair — `dep add A B --type parent-child` is accepted while `B blocks A` exists, although its own refusal hint says epic containment participates in blocking cycles, and `dep cycles` still reports none (OQ-129); (d) the DISC register did not satisfy its own gate — `scripts/converge.sh` matches `^- Resolution:` and DISC-008 was written `- Resolution (2026-09-20, …):`, so the RESOLVED entry counted as OPEN | 4 (S5.179, S4.184 and S4.185 amended in `docs/spec-parts/` and merged; the traversal implements the precedence and the four keys; (c) is OQ-129; (d) the field reshaped, no register text changed) | no | 2026-09-21 |

Convergence (`./scripts/converge.sh docs/PORT_STATE.md`): `tier T3: rounds 6, clean 2, clean tail 0, last two clean False, non-author round False, open OQ 116, open DISC 0` → `NOT_CONVERGED`. T3 needs ≥ 10 rounds with the last two clean, a non-author round, every OQ resolved or excluded.

## Next action (one line, executable)

`./scripts/ws-run.sh --oracle br --no-db :: @fx=hierarchy dep list proj-in9 --direction up` — open find-fix round 7 on the lens "`dep list --direction up` and `--direction both`" (S4.179, S5.176–S5.178): no case has ever run `dep list` in a direction other than the default, the port computes it with code `dep tree` does not share, and fixture `hierarchy` now gives the up direction a node with two dependents; capture the forms it shows as `dep_list_up*`/`dep_list_both*` cases, conform them on js, and commit each finished unit at once.
