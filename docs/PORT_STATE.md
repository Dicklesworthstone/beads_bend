# Port state — BEADS_RUST → Bend 2

<!-- Read FIRST on every resume; rewritten at the END of every session.
     Facts only, each with the command that produced it. No "should",
     no "later". -->

## Where we are

| field | value |
|---|---|
| phase | 1 spec (extraction in progress). Done: −1 fit screen (PLAN §3, §7), 0 truth pack (235 goldens, floor STABLE). Not started: 2 architecture, 3 reference port, 4 parity gate, 5 performance, 6 certify. No Bend implementation exists: `port/main.bend` is the scaffold template |
| tier | T3 |
| bend | `bend 2.0.20` (release binary from the official installer, sha256 `fab9e564c578a0a1…`; run through `scripts/bend-cli.sh`); drift vs the skills' 2.0.16: DRIFT, itemized in PLAN §2b and §8 (`bend version` replaces `--version`; operators need their own `( .. : T)`; foreign defs change the verdict text; cookbook probes 32/32 on interpreter and C) |
| original | `br 0.6.0`, tag `v0.6.0`, commit `b1cfebe`, release binary sha256 `21b967c1ae68df1a…`, run as `scripts/ws-run.sh --oracle br --no-db ::` |
| last updated | 2026-09-20 by Claude (Fable 5.1), session 1 |

Every command below assumes: `cd /data/projects/beads_bend; export BEND_NO_TELEMETRY=1 BEND_CLI=$PWD/scripts/bend-cli.sh LANE_WRAP=$PWD/scripts/ws-run.sh`

## Last gate outputs (paste, do not paraphrase)

| gate | command | result | date |
|---|---|---|---|
| lanes | `./scripts/lanes.sh goldens/cases.tsv goldens $PWD/port/main.bend --threads 8 --timeout 60 --interpreter-timeout 120` | `{"lanes":[{"lane":"interpreter","verdict":"FAIL","passed":1,"failed":234},{"lane":"c-1t","verdict":"FAIL","passed":1,"failed":234},{"lane":"c-8t","verdict":"FAIL","passed":1,"failed":234},{"lane":"js","verdict":"FAIL","passed":1,"failed":234}],"stderr_compared":true,"timeouts_seconds":{"interpreter":120.0,"compiled":60.0,"build":600},"verdict":"FAIL"}` | 2026-09-20 |
| proofs | `(cd port && $BEND_CLI PROOF.bend)` | `All terms check.` (0 @unsafe; the scaffold's single law; bend 2.0.20) | 2026-09-20 |
| parity | `./scripts/parity-board.sh docs/FEATURE_PARITY.md` | `{"rows": 3, "present": 0, "partial": 0, "missing": 3, "excluded": 0, "na": 0, "no_evidence": 0, "verdict": "MALFORMED"}` | 2026-09-20 |
| floor | `./scripts/floor.sh goldens/cases.tsv goldens --repeat 3 --timeout 60 -- scripts/ws-run.sh --oracle br --no-db ::` | `{"repeat":3,"stable":235,"unstable":[],"inconclusive":[],"oracle_identity_checked":true,"verdict":"STABLE"}` | 2026-09-20 |
| cases | `./scripts/cases-lint.sh goldens/cases.tsv` | `{"cases": 235, "errors": 0, "notes": 0, "classes_missing": "", "verdict": "OK"}` | 2026-09-20 |
| incumbent | `./scripts/incumbent-bench.sh --pin …` | NOT_RUN: Phase 5 has not begun; there is no port binary to measure | |

Reading the table. `lanes` FAIL is the truthful state before Phase 3: the program under test is the scaffold template. What that run establishes is the harness: all four lanes execute all 235 cases inside the sandbox and agree with one another (1 passed, 234 failed on each). `parity` MALFORMED: the board still holds the template's placeholder rows; its skeleton is a Phase 2 artifact because its rows cite spec clauses. Goldens: `sha256sum goldens/MANIFEST.txt` → `ae5b18770a62af73…`; they were re-captured with `--repin` after the sandbox fix and 0 of 705 golden hash lines changed.

## Open items

| id | what | blocks | owner |
|---|---|---|---|
| OQ-003 | the port's `version` contract (cases `version_plain`, `version_json` are captured; the port cannot print the original's build metadata) | phase 3 (`version`) | author; a `Platform` DISC needs the approver |
| OQ-005 | what `br --no-db init` does; needs a ws-run mode that dumps every file under `.beads/` | phase 1 (S1, S8) | author |
| OQ-006 | exact issue counts at which the id length steps (fixtures `n163`, `n164` through the oracle) | phase 1 (S4 id table) | author |
| OQ-007 | which optional strings survive a rewrite when empty | phase 1 (S2, S5) | author |
| OQ-008 | when `last-touched` is written and whether reads create files | phase 1 (S8) | author |
| DISC-001 … DISC-005 | pinned-instant seam; single-writer; non-atomic write-back; sidecars; ambiguous-id candidate order (canonicalized) — all OPEN | phase 4 (no OPEN DISC at convergence) | approver: the repository owner |
| UBS | `python.taint.command` on `scripts/ws_inner.py` (argv reaches `subprocess`): the wrapper's contract; not suppressed | commit hygiene (`ubs` exit 1 on that file) | the repository owner decides: a `.ubsignore` entry or a redesign |
| REMOTE | the repository has no git remote; nothing is pushed | session-end "push" | the repository owner: name the remote |
| DRIFT | `scripts/interp-lane.sh` strips a ONE-line compiler note (2.0.16); 2.0.20 prints several lines when a foreign def is reachable (OQ-009). The core/shell file split keeps the core's verdict plain; the first Phase 3 lane run of the shell is the check (`lanes.sh` interpreter row) | phase 3 first lane run | author |

Resolved this session by running the original or the pinned runtime: OQ-001 (chronological order, id tie-break), OQ-002 (every mutation rewrites and normalizes all records), OQ-004 (Bend has no wall clock), OQ-009 (a custom `Clock.wall` effect loads on all three engines). Details: `docs/OPEN_QUESTIONS.md`.

## Find-fix rounds (Phase 4/5)

| round | lens | new genuine findings | fixed | clean? | date |
|---|---|---|---|---|---|

Convergence (computed by `scripts/converge.sh docs/PORT_STATE.md`): T3 ≥ 10 rounds with the last two clean; every OQ resolved or excluded; no OPEN DISC. Current: no rounds yet (Phase 4 has not begun).

## In flight when this file was written

Seven Phase 1 extractors write `docs/spec-parts/{S1_S9,S2_S5a,S5b,S4a_S7,S4b,S4c,S6_S8_S10}.md` from the pinned snapshot `legacy/BEADS_RUST_v0.6.0/` and the goldens (brief: `docs/spec-parts/EXTRACTOR_BRIEF.md`). Two drafters write `docs/drafts/AGENTS.draft.md` and `docs/drafts/README.draft.md` (the owner asked for beads_rust's forms, adapted). A part file that is missing was not finished: re-dispatch that extractor with the same brief.

## Next action (one line, executable)

`python3 scripts/spec-lint.py docs/EXISTING_BEADS_RUST_STRUCTURE.md goldens/cases.tsv` — after merging `docs/spec-parts/*.md` into the spec (S3 reconciled last); then the self-containment review (ten cases predicted from the spec alone).
