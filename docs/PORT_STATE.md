# Port state — BEADS_RUST → Bend 2

<!-- Read FIRST on every resume; rewritten at the END of every session.
     Facts only, each with the command that produced it. No "should",
     no "later". -->

## Where we are

| field | value |
|---|---|
| phase | 3 reference port, early. Done: −1 fit screen; 0 truth pack (344 goldens, floor STABLE); 1 spec, first pass (899 clauses, spec-lint 0 findings, blind self-containment review 10/10); 2 architecture (arch-lint PASS, NUMERIC_PLAN, parity skeleton). Phase 1's second and third extraction passes and the capture of the extractors' proposed cases have NOT run (S12.4). Of the port: eighteen core modules (`port/core/`: `bytes`, `sha256`, `id`, `time`, `json`, `failure`, `model`, `decode`, `store`, `surface`, `cli`, `help`, `query`, `render`, `resolve`, `show`, `run`, `scaffold`) and the IO shell `port/main.bend` with two custom effects (`Sys.exit`, `Sys.cwd`); the shell also reads `.beads/last-touched` and eight environment variables through Base's `IO.get_env`. The argument parser is done for the captured surface: every refusal, tip, usage line and carried help text is the original's bytes. Three commands run, all read-only: `show` (the file's records as they are, partial ids, `.beads/last-touched`, plain and JSON, several ids), `list` (filters, the six orders, paging, plain, `--long`, JSON, Quiet) and `count` (every grouping), over the loaded model with the repairs of S2.31–S2.36. Every other accepted command line loads the store and then answers the port's own "not ported yet" failure (exit 1), so nothing passes by accident. Nothing writes the store yet. **179 of 344 cases pass on c-1t and on js (the same 179)** |
| tier | T3 |
| bend | `bend 2.0.20` (release binary from the official installer, sha256 `fab9e564c578a0a1…`; run through `scripts/bend-cli.sh`); drift vs the skills' 2.0.16: DRIFT, itemized in PLAN §2b and §8 (`bend version` replaces `--version`; operators need their own `( .. : T)`; foreign defs change the verdict text; cookbook probes 32/32 on interpreter and C) |
| original | `br 0.6.0`, tag `v0.6.0`, commit `b1cfebe`, release binary sha256 `21b967c1ae68df1a…`, run as `scripts/ws-run.sh --oracle br --no-db ::` |
| last updated | 2026-09-20 by Claude (Fable 5.1), session 2 |
| remote | `origin` = https://github.com/Dicklesworthstone/beads_bend (public); sessions end with `main` pushed. The granular backlog is `docs/BACKLOG.md` |

Every command below assumes: `cd /data/projects/beads_bend; export BEND_NO_TELEMETRY=1 BEND_CLI=$PWD/scripts/bend-cli.sh LANE_WRAP=$PWD/scripts/ws-run.sh`

## Last gate outputs (paste, do not paraphrase)

| gate | command | result | date |
|---|---|---|---|
| lanes | `./scripts/lanes.sh goldens/cases.tsv goldens $PWD/port/main.bend --threads 8 --timeout 60 --interpreter-timeout 120` (last COMPLETE four-lane run, at commit `7b6c8a2`, 235 cases, before the store refusals and the argument parser landed) | `{"lanes":[{"lane":"interpreter","verdict":"FAIL","passed":3,"failed":232},{"lane":"c-1t","verdict":"FAIL","passed":3,"failed":232},{"lane":"c-8t","verdict":"FAIL","passed":3,"failed":232},{"lane":"js","verdict":"FAIL","passed":3,"failed":232}],"stderr_compared":true,"timeouts_seconds":{"interpreter":120.0,"compiled":60.0,"build":600},"verdict":"FAIL"}` | 2026-09-20 |
| c-1t at HEAD | `./scripts/quick-lanes.sh <out-dir>` (its first line; it builds `port/main.bend` and runs `scripts/conform.sh … --lane c-1t` through the sandbox) | `{"lane": "c-1t", "passed": 179, "failed": 165, "inconclusive": 0, "stderr_compared": true, "verdict": "FAIL"}` | 2026-09-20 |
| js at HEAD | `./scripts/quick-lanes.sh <out-dir>` (its second line: `scripts/conform.sh … --lane js` on the bun build) | `{"lane": "js", "passed": 179, "failed": 165, "inconclusive": 0, "stderr_compared": true, "verdict": "FAIL"}` | 2026-09-20 |
| proofs | `(cd port && $BEND_CLI PROOF.bend)` | `All terms check.` (0 @unsafe; 43 laws: 3 SHA-256 vectors, 7 captured ids, the id-length table, 15 timestamp laws, the store line of `create_min`, the `malformed` fixture's refusal, 8 argument-parser laws `cli_*`, 2 priority-token laws `query_*`, the resolver law `resolve_steps` (six inputs against the eight ids of fixture `basic`, two of them captured refusal texts), the sanitizer law `render_inline_controls`, 2 WHOLE-PROGRAM laws `run_list_two` and `run_count_two` (the pure `Run.outcome` on a two-record store equals the golden's lines), the scaffold's placeholder; 38 s; bend 2.0.20) | 2026-09-20 |
| law coverage | `./scripts/law-coverage.sh` | `{"laws": 43, "proofs": 43, "unproved": "", "ghost_proofs": "", "ghost_cited": "", "uncited": "fast_is_spec", "duplicate_laws": [], "duplicate_proofs": [], "unsafe": 0, "unsafe_annotations": 0, "verdict": "OK"}` | 2026-09-20 |
| spec | `python3 -B scripts/spec-lint.py docs/EXISTING_BEADS_RUST_STRUCTURE.md goldens/cases.tsv` | PASS: 899 clauses, 344 cases, 344 cases cited, 0 finding(s) | 2026-09-20 |
| architecture | `python3 -B scripts/arch-lint.py` | `{"clauses": 764, "homed": 764, "numeric_rows": 25, "s6_rows": 36, "fast_twins": 0, "missing": [], "findings": 0, "verdict": "PASS"}` | 2026-09-20 |
| parity | `./scripts/parity-board.sh docs/FEATURE_PARITY.md` | `{"rows": 42, "present": 0, "partial": 7, "missing": 22, "excluded": 13, "na": 0, "no_evidence": 0, "verdict": "PARTIAL"}` | 2026-09-20 |
| floor | `./scripts/floor.sh goldens/cases.tsv goldens --repeat 3 --timeout 60 -- scripts/ws-run.sh --oracle br --no-db ::` | `{"repeat":3,"stable":344,"unstable":[],"inconclusive":[],"oracle_identity_checked":true,"verdict":"STABLE"}` | 2026-09-20 |
| cases | `./scripts/cases-lint.sh goldens/cases.tsv` | `{"cases": 344, "errors": 0, "notes": 0, "classes_missing": "", "verdict": "OK"}` | 2026-09-20 |
| incumbent | `./scripts/incumbent-bench.sh --pin …` | NOT_RUN: Phase 5 has not begun (the parity gate comes first) | |

Reading the table. `lanes` FAIL is the truthful state, and no four-lane line exists for HEAD: the `lanes` row is the last complete run (an older commit and the 235-case corpus); the run started at the end of session 1 was STOPPED by the harness because the machine was critically low on memory (28 of 30 GB in use, other agents' jobs running), which says nothing about the run. The two `at HEAD` rows are current and agree case for case (the same 179 names pass on both). The 179: every `show_*` case and the refusals of `show` (20), every `list_*` and `count_*` case (38), `empty_list`, `empty_list_json`, `empty_count`, the `precision` fixture's three listing cases, 108 `usage_*` cases (everything the argument parser decides alone: refusals, tips, usage lines, help texts) and the seven refusals of a missing or damaged store (`error_no_workspace_list`, `error_no_workspace_list_json`, `error_no_workspace_create`, `error_conflict_markers`, `error_conflict_markers_json`, `error_malformed_jsonl`, `error_malformed_jsonl_json`). The `usage_*` cases that still fail are accepted command lines whose command is not ported (`docs/FEATURE_PARITY.md`, first row, names them). Re-run the `lanes` command when the machine has memory to spare (about 100 minutes at 344 cases, nearly all of it the interpreter lane). Why that lane is slow, and what was done about it: under bend 2.0.20 a book in which one def reaches both a foreign effect and the large core takes 16–31 s to type-check (`port/probe_shell_time.bend` is the reproducer with timings); the interpreter lane type-checks per case, so `scripts/interp-lane.sh` caches the compiler's note per book, and the proof book never imports the shell. `scripts/quick-lanes.sh` is the inner loop: a C build takes about 2.5 minutes, a JS build 40 s, each conform pass under a minute. Corpus growth this session: three batches captured with `--repin` (43, 41 and 25 cases; the MANIFEST diff of each named only new cases), floor re-run after the first (278: STABLE) and the third (344: STABLE). `sha256sum goldens/MANIFEST.txt` → `6642f42fc2b31562…`. `pin-check.sh docs/PIN.toml`: YELLOW, no RED (`original_commit`: the tag snapshot has no VCS identity; `manifest_version`: this capture tool writes no `version:` line). `python3 -B scripts/gen-help-bend.py --check` → `gen-help-bend: up to date`; `python3 -B scripts/merge-spec-parts.py --check` → 899 clauses from 8 part files. `python3 -B scripts/port-lint.py port/core/cli.bend port/core/surface.bend port/core/help.bend port/core/run.bend`: 0 errors, 0 warnings, 28 PL-02 infos (recursion over argv-sized lists).

## Open items

| id | what | blocks | owner |
|---|---|---|---|
| OQ register | 117 rows, 15 RESOLVED, 102 OPEN (`docs/OPEN_QUESTIONS.md`). Most open rows are the extractors' `(case to add …)` proposals and the six review contradictions (OQ-093…OQ-098); each names the case that settles it. Opened by the `list` work: OQ-114…OQ-117 (JSON envelopes of its validation failures, the plain truncation note, priority tokens beyond the captured one, Unicode case folding). Opened by the parser work and still open: OQ-106 (the 0.7 threshold in floating point against exact fractions), OQ-107 (equally similar names), OQ-111 (`ready --assignee` bare against empty) | phase 1 passes two and three; phase 4 convergence (every OQ resolved or excluded) | author |
| OQ-005, OQ-006, OQ-078 | `br --no-db init`; the id-length band edges (fixtures `n163`/`n164`); a non-integer average lead time (needs a multi-limb binary64 routine or a decision) | phase 3 row `stats`; S4.9's `[inference]` bands | author |
| DISC-001 … DISC-007 | all ACCEPTED on 2026-09-20 under the owner's delegation ("You decide on everything. I approve whatever you want to do."); the owner can revoke any of them, which returns it to OPEN. New this session: DISC-007 (an explicit top-level `--no-db` is accepted, so the port can stand in for `br --no-db`), and DISC-006 now also covers the `--version` flag (`usage_version_flag`) | none (no OPEN DISC) | the repository owner |
| help texts | the port carries six (top, `list` long and short, the three groups); the other 30 levels answer the port's own failure. PLAN §3 excludes them; backlog E2.11 is the decision to revisit | parity row 1 stays `partial` | author |

Resolved this session by running the original: OQ-104 (`--format` lists), OQ-105 (the similar-value tip), OQ-108 (a group with options only), OQ-109 (exclusions name arguments in argv order), OQ-110 (`help list`), OQ-112 for `-d` (leading `-` values on `q` and `update`), OQ-113 (a repeated valued option). One inference of mine was refuted by its case and corrected before commit: `comments lis` is an issue id, not a refused subcommand (S1.86).

## Find-fix rounds (Phase 4/5)

| round | lens | new genuine findings | fixed | clean? | date |
|---|---|---|---|---|---|

Convergence (computed by `scripts/converge.sh docs/PORT_STATE.md`): T3 ≥ 10 rounds with the last two clean; every OQ resolved or excluded; no OPEN DISC. Current: no rounds yet (Phase 4 has not begun).

## Next action (one line, executable)

`(cd port && $BEND_CLI PROOF.bend)` must still print `All terms check.`; then the rest of the read path in `port/core/`, dispatched from `Run.command_pick`: `search` (S4.137–S4.143, S5.156–S5.160; it reuses `Query.build`/`Query.ordered`), then the BLOCKED relation (S4.157–S4.166) in a new `core/blocked.bend` for `ready`, `blocked` and `stats`, then `dep list`/`dep tree`/`dep cycles`, `label list`/`list-all`, `comments list`, `epic status`; check with `./scripts/quick-lanes.sh <out-dir>`.
