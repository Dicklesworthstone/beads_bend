# Port state — BEADS_RUST → Bend 2

<!-- Read FIRST on every resume; rewritten at the END of every session.
     Facts only, each with the command that produced it. No "should",
     no "later". -->

## Where we are

| field | value |
|---|---|
| phase | 3 reference port, early. Done: −1 fit screen; 0 truth pack (235 goldens, floor STABLE); 1 spec, first pass (874 clauses, spec-lint 0 findings, blind self-containment review 10/10); 2 architecture (arch-lint PASS, NUMERIC_PLAN, parity skeleton). Phase 1's second and third extraction passes and the capture of the proposed cases have NOT run (S12.4). Of the port: nine core modules (`port/core/`: `bytes`, `sha256`, `id`, `time`, `json`, `failure`, `model`, `decode`, `run`) and the IO shell `port/main.bend` with one custom effect (`Sys.exit`). What runs end to end is the no-workspace refusal only: 3 of 235 cases pass, identically on all four lanes; every command that needs a workspace answers the port's own "not ported yet" failure (exit 1), so nothing passes by accident |
| tier | T3 |
| bend | `bend 2.0.20` (release binary from the official installer, sha256 `fab9e564c578a0a1…`; run through `scripts/bend-cli.sh`); drift vs the skills' 2.0.16: DRIFT, itemized in PLAN §2b and §8 (`bend version` replaces `--version`; operators need their own `( .. : T)`; foreign defs change the verdict text; cookbook probes 32/32 on interpreter and C) |
| original | `br 0.6.0`, tag `v0.6.0`, commit `b1cfebe`, release binary sha256 `21b967c1ae68df1a…`, run as `scripts/ws-run.sh --oracle br --no-db ::` |
| last updated | 2026-09-20 by Claude (Fable 5.1), session 1 (rewritten after the Phase 1 and 2 gates) |

Every command below assumes: `cd /data/projects/beads_bend; export BEND_NO_TELEMETRY=1 BEND_CLI=$PWD/scripts/bend-cli.sh LANE_WRAP=$PWD/scripts/ws-run.sh`

## Last gate outputs (paste, do not paraphrase)

| gate | command | result | date |
|---|---|---|---|
| lanes | `./scripts/lanes.sh goldens/cases.tsv goldens $PWD/port/main.bend --threads 8 --timeout 60 --interpreter-timeout 120` | `{"lanes":[{"lane":"interpreter","verdict":"FAIL","passed":3,"failed":232},{"lane":"c-1t","verdict":"FAIL","passed":3,"failed":232},{"lane":"c-8t","verdict":"FAIL","passed":3,"failed":232},{"lane":"js","verdict":"FAIL","passed":3,"failed":232}],"stderr_compared":true,"timeouts_seconds":{"interpreter":120.0,"compiled":60.0,"build":600},"verdict":"FAIL"}` | 2026-09-20 |
| proofs | `(cd port && $BEND_CLI PROOF.bend)` | `All terms check.` (0 @unsafe; 27 laws: 3 SHA-256 vectors, 7 captured ids, 15 timestamp laws, the store line of `create_min`, the scaffold's placeholder; bend 2.0.20) | 2026-09-20 |
| law coverage | `./scripts/law-coverage.sh` | `{"laws": 27, "proofs": 27, "unproved": "", "ghost_proofs": "", "ghost_cited": "", "uncited": "fast_is_spec", "duplicate_laws": [], "duplicate_proofs": [], "unsafe": 0, "unsafe_annotations": 0, "verdict": "OK"}` | 2026-09-20 |
| spec | `python3 -B scripts/spec-lint.py docs/EXISTING_BEADS_RUST_STRUCTURE.md goldens/cases.tsv` | PASS: 874 clauses, 235 cases, 235 cases cited, 0 finding(s) | 2026-09-20 |
| architecture | `python3 -B scripts/arch-lint.py` | `{"clauses": 739, "homed": 739, "numeric_rows": 25, "s6_rows": 36, "fast_twins": 0, "missing": [], "findings": 0, "verdict": "PASS"}` | 2026-09-20 |
| parity | `./scripts/parity-board.sh docs/FEATURE_PARITY.md` | `{"rows": 42, "present": 0, "partial": 0, "missing": 29, "excluded": 13, "na": 0, "no_evidence": 0, "verdict": "PARTIAL"}` | 2026-09-20 |
| floor | `./scripts/floor.sh goldens/cases.tsv goldens --repeat 3 --timeout 60 -- scripts/ws-run.sh --oracle br --no-db ::` | `{"repeat":3,"stable":235,"unstable":[],"inconclusive":[],"oracle_identity_checked":true,"verdict":"STABLE"}` | 2026-09-20 |
| cases | `./scripts/cases-lint.sh goldens/cases.tsv` | `{"cases": 235, "errors": 0, "notes": 0, "classes_missing": "", "verdict": "OK"}` | 2026-09-20 |
| incumbent | `./scripts/incumbent-bench.sh --pin …` | NOT_RUN: Phase 5 has not begun; there is no port binary to measure | |

Reading the table. `lanes` FAIL is the truthful state: the three passing cases are `error_no_workspace_list`, `error_no_workspace_list_json`, `error_no_workspace_create`; all four lanes agree (3 passed, 232 failed on each). The interpreter lane needed the port's copy of `scripts/interp-lane.sh` to strip Bend 2.0.20's multi-line pre-run note (the DRIFT item of the previous state file, now closed). Probes that are not conformance cases: `port/probe_decode.bend` decodes and re-encodes every line of fixture `basic` byte for byte (8/8) on the interpreter, C and JS; `port/probe_json.bend` reproduces the golden's serde_json message and column. `parity` PARTIAL: 29 in-scope rows, every one `missing`, and 13 classed exclusions; nothing is ported, and partial never rounds up. Self-containment review 1 (`docs/reviews/self-containment-1/RESULT.md`): 10/10 cases byte-identical from the spec alone; its six clause contradictions are OQ-093…OQ-098. `pin-check.sh docs/PIN.toml`: YELLOW, no RED (the tag snapshot has no VCS identity; this capture tool writes no `version:` line); `original_version` GREEN `br 0.6.0`. Goldens: `sha256sum goldens/MANIFEST.txt` → `ae5b18770a62af73…`; they were re-captured with `--repin` after the sandbox fix and 0 of 705 golden hash lines changed.

## Open items

| id | what | blocks | owner |
|---|---|---|---|
| OQ register | 98 rows, 7 RESOLVED, 91 OPEN (`docs/OPEN_QUESTIONS.md`). Most open rows are the extractors' `(case to add …)` proposals and the six review contradictions (OQ-093…OQ-098); each names the case that settles it | phase 1 passes two and three; phase 4 convergence (every OQ resolved or excluded) | author |
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

`(cd port && $BEND_CLI PROOF.bend)` must still print `All terms check.`; then write `port/core/store.bend` for S2.24–S2.42 and S5.1–S5.19: split the file text into lines (trim, skip blank, count line numbers), refuse conflict markers (S2.26) and malformed lines (S2.27) with their verbatim messages, decode each line with `Decode.issue_of`, apply the load repairs of S2.31–S2.36, and `text(store)` = the records' `Model.line`s sorted by id bytes. Then give the shell `Shell.read_all` and route `list --json` through it: the first workspace cases to aim at are `empty_list_json`, `list_json`, `error_conflict_markers`, `error_malformed_jsonl`.
