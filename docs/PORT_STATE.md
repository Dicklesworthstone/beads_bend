# Port state — BEADS_RUST → Bend 2

<!-- Read FIRST on every resume; rewritten at the END of every session.
     Facts only, each with the command that produced it. No "should",
     no "later". -->

## Where we are

| field | value |
|---|---|
| phase | 3 reference port: the READ path is ported for the whole corpus, the WRITE path has not begun. Done: −1 fit screen; 0 truth pack (344 goldens, floor STABLE); 1 spec, first pass (899 clauses, spec-lint 0 findings, blind self-containment review 10/10); 2 architecture (arch-lint PASS, NUMERIC_PLAN, parity skeleton). Phase 1's second and third extraction passes and the capture of the extractors' proposed cases have NOT run (S12.4). Of the port: twenty-one core modules (`port/core/`: `bytes`, `sha256`, `id`, `time`, `json`, `failure`, `model`, `decode`, `store`, `surface`, `cli`, `help`, `query`, `render`, `resolve`, `show`, `blocked`, `work`, `views`, `run`, `scaffold`) and the IO shell `port/main.bend` with two custom effects (`Sys.exit`, `Sys.cwd`); the shell also reads `.beads/last-touched` and eight environment variables through Base's `IO.get_env`. Fifteen commands run, all read-only: `show`, `list`, `count`, `search`, `ready`, `blocked`, `stats`, `dep list`, `dep tree`, `dep cycles`, `label list`, `label list-all`, `comments list` (and `comments <id>`), `epic status`, `where`. Every other accepted command line (every mutation, and `version`) loads the store and then answers the port's own "not ported yet" failure (exit 1), so nothing passes by accident. NOTHING WRITES THE STORE YET. **230 of 344 cases pass on c-1t and on js (the same 230)** |
| tier | T3 |
| bend | `bend 2.0.20` (release binary from the official installer, sha256 `fab9e564c578a0a1…`; run through `scripts/bend-cli.sh`); drift vs the skills' 2.0.16: DRIFT, itemized in PLAN §2b and §8 (`bend version` replaces `--version`; operators need their own `( .. : T)`; foreign defs change the verdict text; cookbook probes 32/32 on interpreter and C) |
| original | `br 0.6.0`, tag `v0.6.0`, commit `b1cfebe`, release binary sha256 `21b967c1ae68df1a…`, run as `scripts/ws-run.sh --oracle br --no-db ::` |
| last updated | 2026-09-20 by Claude (Fable 5.1), session 2 |
| remote | `origin` = https://github.com/Dicklesworthstone/beads_bend (public); sessions end with `main` pushed. The granular backlog is `docs/BACKLOG.md` |

Every command below assumes: `cd /data/projects/beads_bend; export BEND_NO_TELEMETRY=1 BEND_CLI=$PWD/scripts/bend-cli.sh LANE_WRAP=$PWD/scripts/ws-run.sh`

## Last gate outputs (paste, do not paraphrase)

| gate | command | result | date |
|---|---|---|---|
| lanes | `./scripts/lanes.sh goldens/cases.tsv goldens $PWD/port/main.bend --threads 8 --timeout 60 --interpreter-timeout 120` (last COMPLETE four-lane run, at commit `7b6c8a2`, 235 cases, before the store refusals, the argument parser and every command landed) | `{"lanes":[{"lane":"interpreter","verdict":"FAIL","passed":3,"failed":232},{"lane":"c-1t","verdict":"FAIL","passed":3,"failed":232},{"lane":"c-8t","verdict":"FAIL","passed":3,"failed":232},{"lane":"js","verdict":"FAIL","passed":3,"failed":232}],"stderr_compared":true,"timeouts_seconds":{"interpreter":120.0,"compiled":60.0,"build":600},"verdict":"FAIL"}` | 2026-09-20 |
| c-1t at HEAD | `./scripts/quick-lanes.sh <out-dir>` (its first line; it builds `port/main.bend` and runs `scripts/conform.sh … --lane c-1t` through the sandbox) | `{"lane": "c-1t", "passed": 230, "failed": 114, "inconclusive": 0, "stderr_compared": true, "verdict": "FAIL"}` | 2026-09-20 |
| js at HEAD | `./scripts/quick-lanes.sh <out-dir>` (its second line: `scripts/conform.sh … --lane js` on the bun build) | `{"lane": "js", "passed": 230, "failed": 114, "inconclusive": 0, "stderr_compared": true, "verdict": "FAIL"}` | 2026-09-20 |
| proofs | `(cd port && $BEND_CLI PROOF.bend)` | `All terms check.` (0 @unsafe; 44 laws: 3 SHA-256 vectors, 7 captured ids, the id-length table, 15 timestamp laws, the store line of `create_min`, the `malformed` fixture's refusal, 8 argument-parser laws `cli_*`, 2 priority-token laws `query_*`, the resolver law `resolve_steps`, the sanitizer law `render_inline_controls`, 3 WHOLE-PROGRAM laws `run_list_two`, `run_count_two` and `run_blocked_three` (the pure `Run.outcome` on a small store equals the golden's bytes), the scaffold's placeholder; 38 s; bend 2.0.20) | 2026-09-20 |
| law coverage | `./scripts/law-coverage.sh` | `{"laws": 44, "proofs": 44, "unproved": "", "ghost_proofs": "", "ghost_cited": "", "uncited": "fast_is_spec", "duplicate_laws": [], "duplicate_proofs": [], "unsafe": 0, "unsafe_annotations": 0, "verdict": "OK"}` | 2026-09-20 |
| spec | `python3 -B scripts/spec-lint.py docs/EXISTING_BEADS_RUST_STRUCTURE.md goldens/cases.tsv` | PASS: 899 clauses, 344 cases, 344 cases cited, 0 finding(s) | 2026-09-20 |
| architecture | `python3 -B scripts/arch-lint.py` | `{"clauses": 764, "homed": 764, "numeric_rows": 25, "s6_rows": 36, "fast_twins": 0, "missing": [], "findings": 0, "verdict": "PASS"}` | 2026-09-20 |
| parity | `./scripts/parity-board.sh docs/FEATURE_PARITY.md` | `{"rows": 42, "present": 0, "partial": 16, "missing": 13, "excluded": 13, "na": 0, "no_evidence": 0, "verdict": "PARTIAL"}` | 2026-09-20 |
| floor | `./scripts/floor.sh goldens/cases.tsv goldens --repeat 3 --timeout 60 -- scripts/ws-run.sh --oracle br --no-db ::` | `{"repeat":3,"stable":344,"unstable":[],"inconclusive":[],"oracle_identity_checked":true,"verdict":"STABLE"}` | 2026-09-20 |
| cases | `./scripts/cases-lint.sh goldens/cases.tsv` | `{"cases": 344, "errors": 0, "notes": 0, "classes_missing": "", "verdict": "OK"}` | 2026-09-20 |
| incumbent | `./scripts/incumbent-bench.sh --pin …` | NOT_RUN: Phase 5 has not begun (the parity gate comes first) | |

Reading the table. `lanes` FAIL is the truthful state, and no four-lane line exists for HEAD: the `lanes` row is the last complete run (an older commit and the 235-case corpus); the run started at the end of session 1 was STOPPED by the harness because the machine was critically low on memory, which says nothing about the run. The two `at HEAD` rows are current and agree case for case (the same 230 names pass on both). What passes: every read-only case of the corpus (`show_*`, `list_*`, `count_*`, `search_*`, `ready_*`, `blocked_*`, `stats_*`, `dep_list*`, `dep_tree*`, `dep_cycles*`, `label_list*`, `comments_list*`, `epic_status*`, `where_*`, the `empty_*` and `edge_precision_*` reads), everything the argument parser decides alone, and the refusals of a missing or damaged store. What fails, by family (`scripts/quick-lanes.sh`, c-1t): `error_*` 24, `create_*` 14, `update_*` 14, `usage_*` 11, `dep_*` 8, `close_*` 7, `delete_*` 6, `label_*` 6, `comments_*` 4, `scn_*` 4, `reopen_*` 3, `defer_*` 3, `edge_*` 2, `q_*` 2, `undefer_*` 2, `actor_*` 2, `version_*` 2: every one is a mutation (or reads a mutation's refusal), or `version` (DISC-006). Every command of this session passed all of its cases on its FIRST lane run except `list` (two fixes: `--limit +1`, and the load repairs of S2.36 on fixture `precision`). Conservative forms that answer the port's own failure instead of a guess: `dep tree` on a root with neighbours, `dep cycles` on a graph with a cycle, `blocked --detailed`, `ready --parent/--recursive/--epic`, `list --overdue/--tree/--pretty`, the `stats` breakdowns, an average lead time that is not a whole number of tenths (OQ-078), and the help text of 30 levels. Re-run the `lanes` command when the machine has memory to spare (about 100 minutes at 344 cases, nearly all of it the interpreter lane, which type-checks the program per case: `port/probe_shell_time.bend`). `scripts/quick-lanes.sh` is the inner loop: a C build takes about 3 minutes, a JS build 40 s, each conform pass under a minute. Corpus: three batches captured with `--repin` this session (43, 41 and 25 cases; each MANIFEST diff named only new cases), floor re-run at 278 and at 344: STABLE. `sha256sum goldens/MANIFEST.txt` → `6642f42fc2b31562…`. `pin-check.sh docs/PIN.toml`: YELLOW, no RED (`original_commit`: the tag snapshot has no VCS identity; `manifest_version`: this capture tool writes no `version:` line). `python3 -B scripts/gen-help-bend.py --check` → `gen-help-bend: up to date`. `python3 -B scripts/port-lint.py port/main.bend port/core/*.bend --laws port/LAWS.bend`: 0 errors, 0 warnings, 134 PL-02 infos (non-tail recursion over argv-, record- or store-sized lists: a JS-lane depth wall near 3–5e4 frames, which a store of tens of thousands of issues would reach; Phase 5).

## Open items

| id | what | blocks | owner |
|---|---|---|---|
| OQ register | 121 rows, 15 RESOLVED, 106 OPEN (`docs/OPEN_QUESTIONS.md`). Most open rows are the extractors' `(case to add …)` proposals and the six review contradictions (OQ-093…OQ-098); each names the case that settles it. Opened this session and still open: OQ-106, OQ-107, OQ-111 (parser), OQ-114…OQ-117 (`list`), OQ-118…OQ-121 (`show` and id lookup) | phase 1 passes two and three; phase 4 convergence (every OQ resolved or excluded) | author |
| OQ-005, OQ-006, OQ-078 | `br --no-db init`; the id-length band edges (fixtures `n163`/`n164`); a non-integer average lead time (needs a multi-limb binary64 routine or a decision) | phase 3 row `stats`; S4.9's `[inference]` bands | author |
| DISC-001 … DISC-007 | all ACCEPTED on 2026-09-20 under the owner's delegation ("You decide on everything. I approve whatever you want to do."); the owner can revoke any of them, which returns it to OPEN | none (no OPEN DISC) | the repository owner |
| not read yet | `.beads/config.yaml` (`issue_prefix`, `actor`), `BEADS_DIR`, the upward walk and redirects (S2.1–S2.23): the workspace is the current directory and the prefix is its name; the duplicate-id refusal (S2.40) and load validation (S2.43–S2.56); a wall clock when `BEADS_BEND_NOW` is unset (`Clock.wall`, probed in `port/probes/clock/`) | backlog E3, E4.2, E4.3, E6 | author |

Resolved this session by running the original: OQ-104, OQ-105, OQ-108, OQ-109, OQ-110, OQ-112 (for `-d`), OQ-113. Two inferences were refuted by their cases and corrected before commit: `comments lis` is an issue id, not a refused subcommand (S1.86); `list --long` prints no `Labels:` line (S5.117, from golden `list_long`).

## Find-fix rounds (Phase 4/5)

| round | lens | new genuine findings | fixed | clean? | date |
|---|---|---|---|---|---|

Convergence (computed by `scripts/converge.sh docs/PORT_STATE.md`): T3 ≥ 10 rounds with the last two clean; every OQ resolved or excluded; no OPEN DISC. Current: no rounds yet (Phase 4 has not begun).

## Next action (one line, executable)

`(cd port && $BEND_CLI PROOF.bend)` must still print `All terms check.`; then the WRITE path (backlog E6): give `Run.Outcome` the files to write (`.beads/issues.jsonl`, `.beads/last-touched`) and the shell the effects to write and remove them, write `Store.text` (S5.1–S5.19: every record of the MODEL re-rendered, ascending by id bytes), then `create` first (read S4.200–S4.240 in `docs/EXISTING_BEADS_RUST_STRUCTURE.md`; `Id.seed`, `Id.hash36` and `Id.length_for` exist and are law-checked; the pinned instant is `BEADS_BEND_NOW`), targets `create_min`, `create_full`, `q_basic`; check with `./scripts/quick-lanes.sh <out-dir>`.
