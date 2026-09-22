# Port state — BEADS_RUST → Bend 2

<!-- Read FIRST on every resume; rewritten at the END of every session.
     Facts only, each with the command that produced it. No "should",
     no "later". -->

## Where we are

| field | value |
|---|---|
| phase | 3 reference port, at its exit gate. Done: −1 fit screen; 0 truth pack (454 goldens, floor STABLE: 384 + 30 + the 40 of this session); 1 spec, first pass (902 clauses, spec-lint 0 findings, blind self-containment review 10/10); 2 architecture (arch-lint PASS, NUMERIC_PLAN, parity skeleton). Phase 1's second and third extraction passes have NOT run (S12.4). Of the port: twenty-eight core modules under `port/core/` and the IO shell `port/main.bend` with three custom effects (`Sys.exit`, `Sys.cwd`, `Sys.remove`). **Every command the corpus exercises runs, reads and writes the store. 454 of 454 cases pass on c-1t, c-8t and js, one build of commit `aaf6622`.** This session closed three declared refusals (Phase 3 work, not find-fix rounds: SESSION-LESSONS P48 of the porting-to-bend2 skill): `dep tree --format mermaid`, `blocked --detailed`, `ready --parent/--recursive/--epic` |
| tier | T3 |
| bend | `bend 2.0.20` (release binary from the official installer, sha256 `fab9e564c578a0a1…`; run through `scripts/bend-cli.sh`); drift vs the skills' 2.0.16: DRIFT, itemized in PLAN §2b and §8 |
| original | `br 0.6.0`, tag `v0.6.0`, commit `b1cfebe`, release binary sha256 `21b967c1ae68df1a…`, run as `scripts/ws-run.sh --oracle br --no-db ::` |
| last updated | 2026-09-22 by Claude (Opus 5.5, 1M context), session 5 |
| remote | `origin` = https://github.com/Dicklesworthstone/beads_bend (public); sessions end with `main` pushed. The granular backlog is `docs/BACKLOG.md` |

Every command below assumes: `cd /data/projects/beads_bend; export BEND_NO_TELEMETRY=1 BEND_CLI=$PWD/scripts/bend-cli.sh LANE_WRAP=$PWD/scripts/ws-run.sh`

## Last gate outputs (paste, do not paraphrase)

| gate | command | result | date |
|---|---|---|---|
| c-1t | `./scripts/conform.sh goldens/cases.tsv goldens --lane c-1t --timeout 120 -- scripts/ws-run.sh <out>/bn --threads 1 --gpu off -- ::` (binary from `(cd port && $BEND_CLI main.bend -o <out>/bn)` at `aaf6622`: 550.33 s, 18,189,168 KB peak by GNU `time`, exit 0) | `{"lane": "c-1t", "passed": 454, "failed": 0, "inconclusive": 0, "stderr_compared": true, "verdict": "PASS", "oracle_identity_checked": true}` | 2026-09-22 |
| c-8t | the same binary, `--lane c-8t --timeout 120 … --threads 8` | `{"lane": "c-8t", "passed": 454, "failed": 0, "inconclusive": 0, "stderr_compared": true, "verdict": "PASS", "oracle_identity_checked": true}` | 2026-09-22 |
| js | `./scripts/conform.sh goldens/cases.tsv goldens --lane js --timeout 120 -- scripts/ws-run.sh python3 $PWD/scripts/js-lane.py <out>/bn.js -- ::` (bundle from `(cd port && $BEND_CLI main.bend -o <out>/bn.js)` at `aaf6622`) | `{"lane": "js", "passed": 454, "failed": 0, "inconclusive": 0, "stderr_compared": true, "verdict": "PASS", "oracle_identity_checked": true}` | 2026-09-22 |
| interpreter | `INTERP_NOTE_CACHE=1 ./scripts/conform.sh <sample>.tsv goldens --lane interpreter --timeout 900 -- $PWD/scripts/ws-run.sh bash -c 'exec 3>> "$1" \|\| exit 125; shift; exec "$@"' bend-interpreter <note> $PWD/scripts/interp-lane.sh $PWD/scripts/bend-cli.sh $PWD/port/main.bend -- ::` over `dep_list_both`, `dep_tree_mermaid`, `blocked_detailed`, `ready_parent_recursive` at `aaf6622` | `{"lane": "interpreter", "passed": 4, "failed": 0, "inconclusive": 0, "stderr_compared": true, "verdict": "PASS", "oracle_identity_checked": true}` | 2026-09-22 |
| lanes | `LANE_WRAP=$PWD/scripts/ws-run.sh ./scripts/lanes.sh goldens/cases.tsv goldens $PWD/port/main.bend --threads 8 --timeout 120 --interpreter-timeout 600` | BLOCKER: not run. This copy of `lanes.sh` runs the interpreter first (about 14.5 hours for the corpus at a 9.3 GB `bend` per case), and this 30 GB host cannot hold that beside the 18.2 GB C build; the three fast lanes above were run lane by lane on one build instead, and the interpreter sampled | 2026-09-22 |
| proofs | `(cd port && $BEND_CLI PROOF.bend)` | `All terms check.` (0 @unsafe; 52 laws — the 51 of session 4 plus `run_dep_tree_mermaid`, the closed golden of `goldens/dep_tree_mermaid`; bend 2.0.20) | 2026-09-22 |
| law coverage | `./scripts/law-coverage.sh` | `{"laws": 52, "proofs": 52, "unproved": "", "ghost_proofs": "", "ghost_cited": "", "uncited": "fast_is_spec", "duplicate_laws": [], "duplicate_proofs": [], "unsafe": 0, "unsafe_annotations": 0, "verdict": "OK"}` | 2026-09-22 |
| spec | `python3 -B scripts/spec-lint.py docs/EXISTING_BEADS_RUST_STRUCTURE.md goldens/cases.tsv` | PASS: 902 clauses, 454 cases, 454 cases cited, 0 finding(s) | 2026-09-22 |
| architecture | `python3 -B scripts/arch-lint.py` | `{"clauses": 767, "homed": 767, "numeric_rows": 25, "s6_rows": 36, "fast_twins": 0, "missing": [], "findings": 0, "verdict": "PASS"}` | 2026-09-22 |
| parity | `./scripts/parity-board.sh docs/FEATURE_PARITY.md` | `{"rows": 42, "present": 4, "partial": 25, "missing": 0, "excluded": 13, "na": 0, "no_evidence": 0, "verdict": "PARTIAL"}` | 2026-09-22 |
| floor | `./scripts/floor.sh <new40>.tsv goldens --repeat 3 --timeout 120 -- scripts/ws-run.sh --oracle br --no-db ::` over the 40 cases captured this session | `{"repeat":3,"stable":40,"unstable":[],"inconclusive":[],"oracle_identity_checked":true,"verdict":"STABLE"}` | 2026-09-22 |
| floor-corpus | the same over `goldens/cases.tsv` | `{"repeat":3,"stable":384,"unstable":[],"inconclusive":[],"oracle_identity_checked":true,"verdict":"STABLE"}` | 2026-09-20 |
| cases | `./scripts/cases-lint.sh goldens/cases.tsv` | `{"cases": 454, "errors": 0, "notes": 0, "classes_missing": "", "verdict": "OK"}` | 2026-09-22 |
| port lint | `python3 -B scripts/port-lint.py port/main.bend port/core/*.bend --laws port/LAWS.bend` | `{"files": 29, "findings": 202, "errors": 0, "warnings": 2, "infos": 200, "by_rule": {"PL-02": 200, "PL-01": 1, "PL-04": 1}, "laws": "port/LAWS.bend", "verdict": "FINDINGS"}` | 2026-09-22 |
| incumbent | `./scripts/incumbent-bench.sh --pin …` | NOT_RUN: Phase 5 has not begun (the parity gate comes first) | |

Reading the table. The three fast lanes are the whole corpus of 454 cases, case for case, on one build of commit `aaf6622`. The interpreter row is a 4-case SAMPLE, one case per code path this session added, not the corpus. The 40 cases captured this session (10 `dep list --direction`, 9 `dep tree --format`, 5 `blocked --detailed`, 16 `ready --parent/--recursive/--epic`) were floored on their own (the `floor` row; session 4's 30 were floored the same way, `{"repeat":3,"stable":30,…,"verdict":"STABLE"}` on 2026-09-21); each capture's MANIFEST diff named only its new cases (0 existing golden hashes moved, four `--repin` captures). `./scripts/pin-check.sh docs/PIN.toml`: YELLOW, no RED (the same two as sessions 3 and 4: `original_commit`, `manifest_version`). `python3 -B scripts/gen-help-bend.py --check`: `gen-help-bend: up to date`. `ubs` was NOT run: no shell or Python file of the port changed this session.

The commit subjects `4976302` ("round 8"), `983fcb8` ("round 9") and `aaf6622` ("round 10") name the three refusal closures as rounds. They are recorded below as Phase 3 work, not find-fix rounds, because a declared refusal is not a divergence (S9.6) and closing one reviews nothing the port already claimed.

What the port does NOT do, and answers with its own `INTERNAL_ERROR` failure (exit 1) instead of guessing — `dep tree --format mermaid`, `blocked --detailed` and `ready --parent/--recursive/--epic` have come off this list: `delete --hard` and `--from-file` (OQ-128); a `--json` delete preview or dry run, and `--dry-run` with `--force`/`--cascade` (OQ-127); `label add/remove` with more than two positionals and no `-l` (OQ-122) or with a positional that resolves to nothing (OQ-123); `dep add` with a tombstoned endpoint or a `parent-child` edge to an `external:` target (OQ-124), and `--metadata`; the 64-label ceiling (OQ-125); `comments add -f`; the `stats` breakdowns and an average lead time whose tie binary64 does not hold exactly (OQ-078); `list --overdue/--tree/--pretty`; `update --parent` and the other flags named in `core/update.bend`'s header; `close --transition-comment/--session/--bypass-policy`; `dep cycles` on a graph that still has a cycle (OQ-129); the help text of the 30 levels no case prints.

## What this session added

- **Find-fix round 7** (lens: `dep list --direction up` and `both`, S4.179–S4.181, S5.176–S5.178; no case had run a direction other than the default): ten cases captured on fixtures `hierarchy` and `basic`; all ten passed on js on their first run with no port change. S4.180's two orders were confirmed: JSON keeps the query order and the two halves grouped (dependencies, then dependents), text re-sorts by priority, then `issue_id`.
- **Phase 3: `dep tree --format mermaid`** (OQ-130 RESOLVED). Nine cases captured first (a scenario `mermaid_titles` for `"`, `[`, `|` and a tab in titles). New clauses S4.394 (the value is free text; `mermaid` in any letter case selects it; `--json` wins) and S5.253 (nodes in pre-order `n0…`, edges from the place of the parent occurrence, `"` → `'`). `Views.tree_mermaid`, `Views.mermaid_of`; law `run_dep_tree_mermaid`.
- **Phase 3: `blocked --detailed`**. Five cases, among them the first `external:` blocker in the corpus (`scn_blocked_detailed_external`). New clause S5.254 (the bullet form, `{id}:blocked (not found)` for a blocker with no record, JSON unchanged by the flag). `Render.blocked_detail`.
- **Phase 3: `ready --parent/--recursive/--epic`**. A new fixture `parents`, the original's own output of `goldens/scenarios/build_parents.scn`; sixteen cases. S4.173 amended from them (the parent never a member, `-r` is `--recursive`, `--epic` is `--parent --recursive`, an unknown parent is `ISSUE_NOT_FOUND`); S4.178 and S5.133 gained their measured "filtered" empty line. `Work.members` (breadth first, fuel one per issue), `Work.scoped`.
- **Document repairs**: the headers of `core/views.bend` and `core/work.bend` no longer claim the closed forms are unported; the parity rows of `dep`, `blocked` and `ready` cite the new cases; `docs/BACKLOG.md` E5.3b and E5.4a-1 ticked.
- **The porting-to-bend2 skill**: this port's five sessions were mined into its fourth pass of session lessons (P48–P80, quote bank §84–§88) and its `scripts/lanes.sh` now runs the interpreter last (skill commit `2c530471` in `je_private_skills_repo`). This port's own `scripts/` copies are unchanged.

## Open items

| id | what | blocks | owner |
|---|---|---|---|
| OQ register | 130 rows; `scripts/converge.sh` counts 115 open (OQ-130 RESOLVED this session; `docs/OPEN_QUESTIONS.md`) | phase 4 convergence (every OQ resolved or excluded) | author |
| OQ-129 | **`dep cycles` has never reported a cycle.** The original refuses a blocking cycle at `dep add` on every route tried, so no scenario through the oracle can build one. A `cycles` fixture would be hand-written (the day-one fixtures `conflict`, `malformed` and `precision` are hand-written edge files too) | the `dep cycles` half of the parity row staying `partial` | **the repository owner: may a hand-written `cycles` fixture be added?** |
| bug policy | The toon_bend owner ordered every bug of the original FIXED (skill P27/P28), while this port's AGENTS.md makes bug-compatibility the default and DISC-001…007 were accepted under the owner's delegation of 2026-09-20. Raised by the toon_bend session on 2026-09-22; nothing was changed here | whether any DISC or reproduced bug changes class | **the repository owner** |
| duplicate case | `usage_enum_direction_dep_list` repeats `usage_enum_direction` (the same refusal of `--direction sideways`, another store and id). A case name is never renamed or deleted; it stays, cited in S1.78 | nothing | the repository owner (keep, or authorize a removal and re-capture) |
| probe scenarios | `goldens/scenarios/probe_*.scn` (14 files, two added this session: `probe_mermaid_ids`, `probe_ready_parent_ids`) are exploration no case names. Keep, or fold them into the build scenarios' comments? No file is deleted without written permission | nothing | the repository owner |
| OQ-005, OQ-006 | `br --no-db init`; the id-length band edges | S4.9's `[inference]` bands | author |
| not read yet | `.beads/config.yaml`, `BEADS_DIR`, the upward walk and redirects (S2.1–S2.23); the duplicate-id refusal (S2.40, needs a hand-written fixture: see OQ-129's question) and load validation (S2.43–S2.56); a wall clock when `BEADS_BEND_NOW` is unset (`Clock.wall`) | backlog E3, E4.2, E4.3, E6.6 | author |

## Find-fix rounds (Phase 4/5)

| round | lens | new genuine findings | fixed | clean | date |
|---|---|---|---|---|---|
| 1 | the spec clauses the corpus does not reach, over the five commands session 3 ported (author round) | 1: S4.341 — a second `delete` of an already-tombstoned id rewrote four fields and the store; the original writes nothing | 1 (`core/remove.bend`) | no | 2026-09-20 |
| 2 | the S9 error table against the port's failures (author round) | 2: S9.22 — the `SELF_DEPENDENCY` context key is `id`, not `issue_id`; S9.11 — the shell's `String.trim_end` ate a trailing SPACE | 2 (`core/edges.bend`; `port/main.bend`) | no | 2026-09-20 |
| 3 | the JSON envelopes and payload rows of the six commands session 3 ported (author round) | 0: six captured envelopes matched the port's spec-derived text byte for byte | 0 | yes | 2026-09-20 |
| 4 | Quiet mode over the mutations (S5.106, S5.107, S9.26, OQ-015) (author round) | 2: `close --quiet` still printed the per-item `Warning: Skipped …` lines; `reopen --quiet` printed nothing where the original prints `✓ Reopened` | 2 (`core/run.bend`) | no | 2026-09-20 |
| 5 | the actor ladders (S4.200, S4.201) (author round) | 0: `actor_flag_dep_add`, `actor_flag_delete` and `actor_flag_label_add` matched on their first run | 0 | yes | 2026-09-20 |
| 6 | the dependency graph beyond depth 0: real depth, a diamond, an ancestor back edge, a shared node with children, a depth limit, the `up` and `both` directions (author round) | 4: (a) S5.179 stated no precedence — a node can be `truncated` AND `repeat`, and `(truncated) ` wins the plain prefix (`dep_tree_repeat`, `dep_tree_repeat_json`); (b) S4.184's four sort keys had never been separated by a case — the status rank beats title (`dep_tree_repeat`) and title beats id (`dep_tree_up_basic`), which refutes a title-only tie-break; (c) the original's cycle check misses a mixed pair — `dep add A B --type parent-child` is accepted while `B blocks A` exists, although its own refusal hint says epic containment participates in blocking cycles, and `dep cycles` still reports none (OQ-129); (d) the DISC register did not satisfy its own gate — `scripts/converge.sh` matches `^- Resolution:` and DISC-008 was written `- Resolution (2026-09-20, …):`, so the RESOLVED entry counted as OPEN | 4 (S5.179, S4.184 and S4.185 amended in `docs/spec-parts/` and merged; the traversal implements the precedence and the four keys; (c) is OQ-129; (d) the field reshaped, no register text changed) | no | 2026-09-21 |
| 7 | `dep list --direction up` and `--direction both` (S4.179–S4.181, S5.176–S5.178): the other end of every edge, the two orders of S4.180 on a node with two dependents tied on priority, the empty lines per direction, a type filter with a direction (author round) | 0: ten captured cases (`dep_list_up*`, `dep_list_both*`, `usage_enum_direction_dep_list`) matched the port's spec-derived text byte for byte on their first run | 0 | yes | 2026-09-22 |

Convergence (`./scripts/converge.sh docs/PORT_STATE.md`): `tier T3: rounds 7, clean 3, clean tail 1, last two clean False, non-author round False, open OQ 115, open DISC 0` → `NOT_CONVERGED`. T3 needs ≥ 10 rounds with the last two clean, a non-author round, every OQ resolved or excluded.

## Next action (one line, executable)

`./scripts/ws-run.sh --oracle br --no-db :: @fx=parents ready --parent proj-9vo --limit 1` — open find-fix round 8 on the lens "re-test the last repairs" (the skill's first lens after a batch of closures): the three forms closed this session crossed with the flags their cases did not combine (`ready --parent` with `--limit`, `--sort oldest`, `-t`, `--quiet`; `blocked --detailed` with `-t`/`-l` filters and `--quiet`; `dep tree --format mermaid` with `--max-depth 0` and on an `external:` neighbour); capture the forms as cases, conform them on js, and commit each finished unit at once.
