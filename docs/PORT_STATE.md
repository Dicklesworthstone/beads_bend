# Port state — BEADS_RUST → Bend 2

<!-- Read FIRST on every resume; rewritten at the END of every session.
     Facts only, each with the command that produced it. No "should",
     no "later". -->

## Where we are

| field | value |
|---|---|
| phase | 3 reference port, at its exit gate. Done: −1 fit screen; 0 truth pack (352 goldens, floor STABLE); 1 spec, first pass (899 clauses, spec-lint 0 findings, blind self-containment review 10/10); 2 architecture (arch-lint PASS, NUMERIC_PLAN, parity skeleton). Phase 1's second and third extraction passes and the capture of the extractors' remaining proposed cases have NOT run (S12.4). Of the port: twenty-four core modules (`port/core/`: `bytes`, `sha256`, `id`, `time`, `json`, `failure`, `model`, `decode`, `store`, `surface`, `cli`, `help`, `query`, `render`, `resolve`, `show`, `blocked`, `work`, `views`, `create`, `update`, `status`, `when`, `edges`, `labels`, `remove`, `run`, `scaffold`) and the IO shell `port/main.bend` with three custom effects (`Sys.exit`, `Sys.cwd`, `Sys.remove`); the shell also reads `.beads/last-touched` and eight environment variables through Base's `IO.get_env`. **Every command the corpus exercises now runs, reads and writes the store: `show`, `list`, `count`, `search`, `ready`, `blocked`, `stats`, `dep list/tree/cycles`, `label list/list-all`, `comments list`, `epic status`, `where`, `version`, `create`, `q`, `update`, `close`, `reopen`, `defer`, `undefer`, `dep add`, `dep remove`, `label add`, `label remove`, `label rename`, `comments add`, `delete`.** The one in-scope command that is NOT implemented is `epic close-eligible`: no case captures it, so no golden could judge it. **352 of 352 cases pass on c-1t, on c-8t and on js (the same 352)** |
| tier | T3 |
| bend | `bend 2.0.20` (release binary from the official installer, sha256 `fab9e564c578a0a1…`; run through `scripts/bend-cli.sh`); drift vs the skills' 2.0.16: DRIFT, itemized in PLAN §2b and §8 (`bend version` replaces `--version`; operators need their own `( .. : T)`; foreign defs change the verdict text; a multi-scrutinee `match` must name the parameters in declaration order; definitions resolve in source order; cookbook probes 32/32 on interpreter and C) |
| original | `br 0.6.0`, tag `v0.6.0`, commit `b1cfebe`, release binary sha256 `21b967c1ae68df1a…`, run as `scripts/ws-run.sh --oracle br --no-db ::` |
| last updated | 2026-09-20 by Claude (Opus 5, 1M context), session 3 |
| remote | `origin` = https://github.com/Dicklesworthstone/beads_bend (public); sessions end with `main` pushed. The granular backlog is `docs/BACKLOG.md` |

Every command below assumes: `cd /data/projects/beads_bend; export BEND_NO_TELEMETRY=1 BEND_CLI=$PWD/scripts/bend-cli.sh LANE_WRAP=$PWD/scripts/ws-run.sh`

## Last gate outputs (paste, do not paraphrase)

| gate | command | result | date |
|---|---|---|---|
| c-1t | `./scripts/conform.sh goldens/cases.tsv goldens --lane c-1t --timeout 60 -- scripts/ws-run.sh <out>/bn --threads 1 --gpu off -- ::` (binary from `(cd port && $BEND_CLI main.bend -o <out>/bn)`) | `{"lane": "c-1t", "passed": 352, "failed": 0, "inconclusive": 0, "stderr_compared": true, "verdict": "PASS", "oracle_identity_checked": true}` | 2026-09-20 |
| c-8t | the same binary, `--lane c-8t … --threads 8` | `{"lane": "c-8t", "passed": 352, "failed": 0, "inconclusive": 0, "stderr_compared": true, "verdict": "PASS", "oracle_identity_checked": true}` | 2026-09-20 |
| js | `./scripts/conform.sh … --lane js --timeout 60 -- scripts/ws-run.sh python3 $PWD/scripts/js-lane.py <out>/bn.js -- ::` (bundle from `(cd port && $BEND_CLI main.bend -o <out>/bn.js)`) | `{"lane": "js", "passed": 352, "failed": 0, "inconclusive": 0, "stderr_compared": true, "verdict": "PASS", "oracle_identity_checked": true}` | 2026-09-20 |
| interpreter (12-case sample) | `./scripts/conform.sh <sample>.tsv goldens --lane interpreter --timeout 600 -- scripts/ws-run.sh <the fd-3 bash wrapper `scripts/lanes.sh` uses> bend-interpreter <note> $PWD/scripts/interp-lane.sh $PWD/scripts/bend-cli.sh $PWD/port/main.bend -- ::` over `usage_none`, `list_plain`, `show_json`, `ready_plain`, `create_min`, `update_status`, `close_basic`, `dep_add_blocks`, `label_rename`, `comments_add`, `delete_basic`, `version_plain` | `{"lane": "interpreter", "passed": 12, "failed": 0, "inconclusive": 0, "stderr_compared": true, "verdict": "PASS", "oracle_identity_checked": true}` | 2026-09-20 |
| lanes | `LANE_WRAP=$PWD/scripts/ws-run.sh ./scripts/lanes.sh goldens/cases.tsv goldens $PWD/port/main.bend --threads 8 --timeout 60 --interpreter-timeout 600` | NOT_RUN: the four-lane script also runs the interpreter lane, which type-checks the whole book on every case — 2 min 28 s per run measured (`time $BEND_CLI port/main.bend -- --help`), about 14.5 hours for 352 cases. The three fast lanes above were run one at a time instead, on the same build | 2026-09-20 |
| proofs | `(cd port && $BEND_CLI PROOF.bend)` | `All terms check.` (0 @unsafe; 50 laws: 3 SHA-256 vectors, 7 captured ids, the id-length table, 15 timestamp laws, the store line of `create_min`, the `malformed` fixture's refusal, 8 argument-parser laws `cli_*`, 2 priority-token laws `query_*`, the resolver law `resolve_steps`, the sanitizer law `render_inline_controls`, the write-back fixpoint of fixture `basic`, 2 lead-time rounding laws, and 5 WHOLE-PROGRAM laws — `run_list_two`, `run_count_two`, `run_blocked_three`, `run_create_min`, `run_dep_add_duplicate`, `run_delete_preview`; bend 2.0.20) | 2026-09-20 |
| law coverage | `./scripts/law-coverage.sh` | `{"laws": 50, "proofs": 50, "unproved": "", "ghost_proofs": "", "ghost_cited": "", "uncited": "fast_is_spec", "duplicate_laws": [], "duplicate_proofs": [], "unsafe": 0, "unsafe_annotations": 0, "verdict": "OK"}` | 2026-09-20 |
| spec | `python3 -B scripts/spec-lint.py docs/EXISTING_BEADS_RUST_STRUCTURE.md goldens/cases.tsv` | PASS: 899 clauses, 352 cases, 352 cases cited, 0 finding(s) | 2026-09-20 |
| architecture | `python3 -B scripts/arch-lint.py` | `{"clauses": 764, "homed": 764, "numeric_rows": 25, "s6_rows": 36, "fast_twins": 0, "missing": [], "findings": 0, "verdict": "PASS"}` | 2026-09-20 |
| parity | `./scripts/parity-board.sh docs/FEATURE_PARITY.md` | `{"rows": 42, "present": 4, "partial": 24, "missing": 1, "excluded": 13, "na": 0, "no_evidence": 0, "verdict": "PARTIAL"}` | 2026-09-20 |
| floor | `./scripts/floor.sh goldens/cases.tsv goldens --repeat 3 --timeout 60 -- scripts/ws-run.sh --oracle br --no-db ::` | `{"repeat":3,"stable":352,"unstable":[],"inconclusive":[],"oracle_identity_checked":true,"verdict":"STABLE"}` | 2026-09-20 |
| cases | `./scripts/cases-lint.sh goldens/cases.tsv` | `{"cases": 352, "errors": 0, "notes": 0, "classes_missing": "", "verdict": "OK"}` | 2026-09-20 |
| port lint | `python3 -B scripts/port-lint.py port/main.bend port/core/*.bend --laws port/LAWS.bend` | `{"files": 29, "findings": 181, "errors": 0, "warnings": 3, "infos": 178, "by_rule": {"PL-02": 178, "PL-01": 1, "PL-04": 1, "PL-10": 1}, "laws": "port/LAWS.bend", "verdict": "FINDINGS"}` | 2026-09-20 |
| incumbent | `./scripts/incumbent-bench.sh --pin …` | NOT_RUN: Phase 5 has not begun (the parity gate comes first) | |

Reading the table. The three fast lanes are the whole corpus, case for case, on the same build of `port/main.bend`; they were run lane by lane with `scripts/conform.sh` because `scripts/lanes.sh` also runs the interpreter lane, which now costs about 14.5 hours (above). Two harness facts from this session, both carried by a `--repin` re-capture whose MANIFEST diff was read: the C build of the port peaks near 19 GB and 8 minutes, and the kernel OOM-killed it three times while other agents used the machine (exit 137, an empty output path, and then every case reads INCONCLUSIVE — check the binary exists before conforming); and `scripts/ws_inner.py`'s per-step budget was raised from 120 s to 600 s so an interpreter case can finish at all (0 of 1056 golden hashes moved). `sha256sum goldens/MANIFEST.txt` → `b802f4dbfde0f479…`. `./scripts/pin-check.sh docs/PIN.toml`: YELLOW, no RED (`original_commit`: the tag snapshot has no VCS identity; `manifest_version`: this capture tool writes no `version:` line); `manifest_hashes` GREEN over 1056 hashes, `case_count` GREEN (352 cases = 352 goldens = MANIFEST 352). `./scripts/claims-lint.sh docs/*.md perf/*.md README.md`: `claims-lint: 0 hit(s) in 16 file(s)`. `python3 -B scripts/gen-help-bend.py --check`: `gen-help-bend: up to date`. The 178 PL-02 infos of the port lint are non-tail recursion over argv-, record- or store-sized lists: a JS-lane depth wall near 3–5e4 frames, which a store of tens of thousands of issues would reach (Phase 5).

What the port does NOT do, and answers with its own `INTERNAL_ERROR` failure (exit 1) instead of guessing, each with the OQ that will settle it: `delete --hard` and `--from-file` (OQ-128); a `--json` delete preview or dry run, and `--dry-run` with `--force`/`--cascade` (OQ-127); `label add/remove` with more than two positionals and no `-l` (OQ-122) or with a positional that resolves to nothing (OQ-123); `dep add` with a tombstoned endpoint or a `parent-child` edge to an `external:` target (OQ-124), and `--metadata`; the 64-label ceiling (OQ-125); `comments add -f`; the `stats` breakdowns and an average lead time whose tie binary64 does not hold exactly (OQ-078); `list --overdue/--tree/--pretty`; `ready --parent/--recursive/--epic`; `blocked --detailed`; `update --parent` and the other flags named in `core/update.bend`'s header; `close --transition-comment/--session/--bypass-policy`; the help text of the 30 levels no case prints; `epic close-eligible`.

## Open items

| id | what | blocks | owner |
|---|---|---|---|
| OQ register | 128 rows, 16 RESOLVED, 112 OPEN (`docs/OPEN_QUESTIONS.md`). Opened this session: OQ-122…OQ-128, one per form the port refuses instead of guessing; each names the case that settles it. OQ-078 is narrowed, not closed: the plain days figure is now computed in exact integer tenths with Rust's ties-to-even rule (laws `lead_tenths_quarter`, `lead_tenths_odd_tie_refused`), and only a non-dyadic tie and the JSON mean of hours remain refused | phase 1 passes two and three; phase 4 convergence (every OQ resolved or excluded) | author |
| OQ-005, OQ-006 | `br --no-db init`; the id-length band edges (fixtures `n163`/`n164`) | S4.9's `[inference]` bands | author |
| DISC-001 … DISC-007 | all ACCEPTED on 2026-09-20 under the owner's delegation ("You decide on everything. I approve whatever you want to do."); the owner can revoke any of them, which returns it to OPEN. DISC-006 landed this session: `bn version 0.1.0 (bend 2.0.20) (port of br 0.6.0@b1cfebe)`, its JSON report, `bn --version`, and the shape canonicalizer in `scripts/ws_inner.py` | none (no OPEN DISC) | the repository owner |
| not read yet | `.beads/config.yaml` (`issue_prefix`, `actor`), `BEADS_DIR`, the upward walk and redirects (S2.1–S2.23): the workspace is the current directory and the prefix is its name; the duplicate-id refusal (S2.40) and load validation (S2.43–S2.56); a wall clock when `BEADS_BEND_NOW` is unset (`Clock.wall`, probed in `port/probes/clock/`) | backlog E3, E4.2, E4.3, E6.6 | author |
| epic close-eligible | the only in-scope command with no captured case (S4.390–S4.393). A case is captured before it is implemented, so that a golden can judge it | the parity board's one `missing` row | author |

Resolved this session by running the original on new cases: the single-parent refusal names the field `depends_on_id`, not `parent` (`error_dep_add_second_parent`, spec S4.363 amended); `label rename` to a name nobody carries, to itself, and onto a label an issue already has (`label_rename_absent`, `label_rename_same`, `label_rename_merge`); `dep remove --type` (`dep_remove_typed`); `label add -l a,b` (`label_add_flag_two`); the joined positional words and the no-source refusal of `comments add` (`comments_add_words`, `error_comments_add_no_text`). One inference was refuted by its case and corrected before commit: the single-parent field above.

## Find-fix rounds (Phase 4/5)

| round | lens | new genuine findings | fixed | clean? | date |
|---|---|---|---|---|---|

Convergence (computed by `scripts/converge.sh docs/PORT_STATE.md`): T3 ≥ 10 rounds with the last two clean; every OQ resolved or excluded; no OPEN DISC. Current: no rounds yet (Phase 4 has not begun).

## Next action (one line, executable)

`LANE_WRAP=$PWD/scripts/ws-run.sh ./scripts/lanes.sh goldens/cases.tsv goldens $PWD/port/main.bend --threads 8 --timeout 60 --interpreter-timeout 600` as an overnight checkpoint (about 14.5 hours, almost all of it the interpreter lane), then capture `epic_close_eligible` and implement it (backlog E6.4a).
