# Port state — BEADS_RUST → Bend 2

<!-- Read FIRST on every resume; rewritten at the END of every session.
     Facts only, each with the command that produced it. No "should",
     no "later". -->

## Where we are

| field | value |
|---|---|
| phase | 3 reference port, early. Done: −1 fit screen; 0 truth pack (235 goldens, floor STABLE); 1 spec, first pass (874 clauses, spec-lint 0 findings, blind self-containment review 10/10); 2 architecture (arch-lint PASS, NUMERIC_PLAN, parity skeleton). Phase 1's second and third extraction passes and the capture of the proposed cases have NOT run (S12.4). Of the port: eleven core modules (`port/core/`: `bytes`, `sha256`, `id`, `time`, `json`, `failure`, `model`, `decode`, `store`, `run`, `scaffold`) and the IO shell `port/main.bend` with two custom effects (`Sys.exit`, `Sys.cwd`). There is NO argument parser and NO command: what runs end to end is the no-workspace refusal and the two store-load refusals. **7 of 235 cases pass**; every real command answers the port's own "not ported yet" failure (exit 1), so nothing passes by accident |
| tier | T3 |
| bend | `bend 2.0.20` (release binary from the official installer, sha256 `fab9e564c578a0a1…`; run through `scripts/bend-cli.sh`); drift vs the skills' 2.0.16: DRIFT, itemized in PLAN §2b and §8 (`bend version` replaces `--version`; operators need their own `( .. : T)`; foreign defs change the verdict text; cookbook probes 32/32 on interpreter and C) |
| original | `br 0.6.0`, tag `v0.6.0`, commit `b1cfebe`, release binary sha256 `21b967c1ae68df1a…`, run as `scripts/ws-run.sh --oracle br --no-db ::` |
| last updated | 2026-09-20 by Claude (Fable 5.1), session 1 (rewritten after the Phase 1 and 2 gates) |

Every command below assumes: `cd /data/projects/beads_bend; export BEND_NO_TELEMETRY=1 BEND_CLI=$PWD/scripts/bend-cli.sh LANE_WRAP=$PWD/scripts/ws-run.sh`

## Last gate outputs (paste, do not paraphrase)

| gate | command | result | date |
|---|---|---|---|
| lanes | `./scripts/lanes.sh goldens/cases.tsv goldens $PWD/port/main.bend --threads 8 --timeout 60 --interpreter-timeout 120` (last COMPLETE four-lane run, at commit `7b6c8a2`, before the store refusals landed) | `{"lanes":[{"lane":"interpreter","verdict":"FAIL","passed":3,"failed":232},{"lane":"c-1t","verdict":"FAIL","passed":3,"failed":232},{"lane":"c-8t","verdict":"FAIL","passed":3,"failed":232},{"lane":"js","verdict":"FAIL","passed":3,"failed":232}],"stderr_compared":true,"timeouts_seconds":{"interpreter":120.0,"compiled":60.0,"build":600},"verdict":"FAIL"}` | 2026-09-20 |
| c-1t at HEAD | `./scripts/conform.sh goldens/cases.tsv goldens --lane c-1t --timeout 60 -- scripts/ws-run.sh <binary built from port/main.bend> --threads 1 --gpu off -- ::` at commit `4ca3fdc` | `{"lane": "c-1t", "passed": 7, "failed": 228, "inconclusive": 0, "stderr_compared": true, "verdict": "FAIL"}` | 2026-09-20 |
| proofs | `(cd port && $BEND_CLI PROOF.bend)` | `All terms check.` (0 @unsafe; 29 laws: 3 SHA-256 vectors, 7 captured ids, the id-length table, 15 timestamp laws, the store line of `create_min`, the `malformed` fixture's refusal, the scaffold's placeholder; 27 s; bend 2.0.20) | 2026-09-20 |
| law coverage | `./scripts/law-coverage.sh` | `{"laws": 29, "proofs": 29, "unproved": "", "ghost_proofs": "", "ghost_cited": "", "uncited": "fast_is_spec", "duplicate_laws": [], "duplicate_proofs": [], "unsafe": 0, "unsafe_annotations": 0, "verdict": "OK"}` | 2026-09-20 |
| spec | `python3 -B scripts/spec-lint.py docs/EXISTING_BEADS_RUST_STRUCTURE.md goldens/cases.tsv` | PASS: 874 clauses, 235 cases, 235 cases cited, 0 finding(s) | 2026-09-20 |
| architecture | `python3 -B scripts/arch-lint.py` | `{"clauses": 739, "homed": 739, "numeric_rows": 25, "s6_rows": 36, "fast_twins": 0, "missing": [], "findings": 0, "verdict": "PASS"}` | 2026-09-20 |
| parity | `./scripts/parity-board.sh docs/FEATURE_PARITY.md` | `{"rows": 42, "present": 0, "partial": 2, "missing": 27, "excluded": 13, "na": 0, "no_evidence": 0, "verdict": "PARTIAL"}` | 2026-09-20 |
| floor | `./scripts/floor.sh goldens/cases.tsv goldens --repeat 3 --timeout 60 -- scripts/ws-run.sh --oracle br --no-db ::` | `{"repeat":3,"stable":235,"unstable":[],"inconclusive":[],"oracle_identity_checked":true,"verdict":"STABLE"}` | 2026-09-20 |
| cases | `./scripts/cases-lint.sh goldens/cases.tsv` | `{"cases": 235, "errors": 0, "notes": 0, "classes_missing": "", "verdict": "OK"}` | 2026-09-20 |
| incumbent | `./scripts/incumbent-bench.sh --pin …` | NOT_RUN: Phase 5 has not begun; there is no port binary to measure | |

Reading the table. `lanes` FAIL is the truthful state. The seven passing cases on c-1t at HEAD are `error_no_workspace_list`, `error_no_workspace_list_json`, `error_no_workspace_create`, `error_conflict_markers`, `error_conflict_markers_json`, `error_malformed_jsonl`, `error_malformed_jsonl_json`. A full four-lane run at HEAD was started at the end of session 1 and was STOPPED by the harness before any lane finished, because the machine was critically low on memory (28 of 30 GB in use, other agents' jobs running); that says nothing about the run. No four-lane line exists for HEAD: the `lanes` row above is the last complete one, and the `c-1t at HEAD` row is current. Re-run the `lanes` command when the machine has memory to spare (about 75 minutes, of which the interpreter lane is about an hour). Why that lane is slow, and what was done about it: under bend 2.0.20 a book in which one def reaches both a foreign effect and the large core takes 16–31 s to type-check (`port/probe_shell_time.bend` is the reproducer with timings); the interpreter lane type-checks per case, so `scripts/interp-lane.sh` now caches the compiler's note per book (17 s per case, was 46 s), and the proof book no longer imports the shell (27 s, was 41 s). Use c-1t and js for the fast loop. Probes that are not conformance cases: `port/probe_decode.bend` round-trips every line of fixture `basic` (8/8) on the interpreter, C and JS; `port/probe_json.bend` reproduces the golden's serde_json message and column. `parity` PARTIAL: 29 in-scope rows (2 `partial`, 27 `missing`) and 13 classed exclusions; partial never rounds up. Self-containment review 1 (`docs/reviews/self-containment-1/RESULT.md`): 10/10 cases byte-identical from the spec alone; its six clause contradictions are OQ-093…OQ-098. `pin-check.sh docs/PIN.toml`: YELLOW, no RED (the tag snapshot has no VCS identity; this capture tool writes no `version:` line); `original_version` GREEN `br 0.6.0`. Goldens: `sha256sum goldens/MANIFEST.txt` → `ae5b18770a62af73…`; they were re-captured with `--repin` after the sandbox fix and 0 of 705 golden hash lines changed.

## Open items

| id | what | blocks | owner |
|---|---|---|---|
| OQ register | 103 rows, 7 RESOLVED, 96 OPEN (`docs/OPEN_QUESTIONS.md`). Most open rows are the extractors' `(case to add …)` proposals and the six review contradictions (OQ-093…OQ-098); each names the case that settles it | phase 1 passes two and three; phase 4 convergence (every OQ resolved or excluded) | author |
| OQ-003, OQ-005, OQ-006, OQ-078 | the port's `version` contract; `br --no-db init`; the id-length band edges (fixtures `n163`/`n164`); a non-integer average lead time (needs a multi-limb binary64 routine or a decision) | phase 3 rows `version`, `stats`; S4.9's `[inference]` bands | author; approver for the `version` DISC |
| DISC-001 … DISC-005 | pinned-instant seam; single-writer; non-atomic write-back; sidecars; ambiguous-id candidate order (canonicalized) — all OPEN | phase 4 (no OPEN DISC at convergence) | approver: the repository owner |
| UBS | `python.taint.command` on `scripts/ws_inner.py` (argv reaches `subprocess`): the wrapper's contract; not suppressed | commit hygiene (`ubs` exit 1 on that file) | the repository owner decides: a `.ubsignore` entry or a redesign |
| REMOTE | the repository has no git remote; nothing is pushed | session-end "push" | the repository owner: name the remote |

Resolved this session by running the original or the pinned runtime: OQ-001 (chronological order, id tie-break), OQ-002 (every mutation rewrites and normalizes all records), OQ-004 (Bend has no wall clock), OQ-007 (`compacted_at_commit` alone survives as `""`), OQ-009 (custom effects load on all three engines), OQ-015 (`--quiet` suppresses warnings), OQ-092 (`IO.die` always writes to stderr; a custom `Sys.exit` is the exit path). Details: `docs/OPEN_QUESTIONS.md`.

Subagents: the seven extractors ran on the Opus override the skill's role files name; four of them hit the account's session limit (HTTP 429, "resets 3am America/New_York") near the end. Their part files were structurally complete; the lint fixes and the blind review ran on agents that inherit the parent model.

## Find-fix rounds (Phase 4/5)

| round | lens | new genuine findings | fixed | clean? | date |
|---|---|---|---|---|---|

Convergence (computed by `scripts/converge.sh docs/PORT_STATE.md`): T3 ≥ 10 rounds with the last two clean; every OQ resolved or excluded; no OPEN DISC. Current: no rounds yet (Phase 4 has not begun).

## Next action (one line, executable)

`(cd port && $BEND_CLI PROOF.bend)` must still print `All terms check.`; then write `port/core/cli.bend` for S1.1–S1.67 (argv → `Command` or a usage refusal with clap's verbatim texts; start from the sixteen `usage_*` goldens, which need no workspace) and route `Run.outcome` through it, so that a store is loaded only by the commands that load one. After that: the load repairs of S2.31–S2.36 and the duplicate-id refusal in `core/store.bend`, then `core/query.bend` and `Render.json_list` for `empty_list_json` and `list_json`. Check each step on c-1t with `./scripts/conform.sh … --lane c-1t …` (the `c-1t at HEAD` row above shows the command).
