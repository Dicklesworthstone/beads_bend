# Port state — BEADS_RUST → Bend 2

<!-- Read FIRST on every resume; rewritten at the END of every session.
     Facts only, each with the command that produced it. No "should",
     no "later". -->

## Where we are

| field | value |
|---|---|
| phase | 3 reference port, at its exit gate, with Phase 4 find-fix rounds running. Done: −1 fit screen; 0 truth pack (1009 goldens; the 16 cases added 2026-09-24 floored STABLE; the two UNSTABLE cases are DISC-010 and DISC-011); 1 spec (909 clauses, spec-lint 0 findings); 2 architecture (every clause homed). The port: 31 modules under `port/core/` and the IO shell `port/main.bend` (custom effects `Sys.exit`, `Sys.cwd`, `Sys.remove`, `Sys.stdin`, `Clock.wall`). **1007 of 1009 cases pass on c-1t, c-8t and js, one build each of the tree at `fd0a945`**; the two failures are the original's own random draws (DISC-010, DISC-011). The interpreter lane has not run on this code (BLOCKER below) |
| tier | T3 |
| bend | `bend 2.0.20` (release binary, sha256 `fab9e564c578a0a1…`; run through `scripts/bend-cli.sh`); drift vs the skills' 2.0.16: DRIFT, itemized in PLAN §2b and §8 |
| original | `br 0.6.0`, tag `v0.6.0`, commit `b1cfebe`, release binary sha256 `21b967c1ae68df1a…`, run as `scripts/ws-run.sh --oracle br --no-db ::` |
| last updated | 2026-09-24 by Claude (Opus 5.5, 1M context), session 8 |
| remote | `origin` = https://github.com/Dicklesworthstone/beads_bend (public); sessions end with `main` pushed. Open work is in the repository's own `.beads/` workspace (prefix `bb`, `br ready --json`); `docs/BACKLOG.md` section H is the bridge plan the beads came from |

Every command below assumes: `cd /data/projects/beads_bend; export BEND_NO_TELEMETRY=1 BEND_CLI=$PWD/scripts/bend-cli.sh LANE_WRAP=$PWD/scripts/ws-run.sh BUN_JSC_forceRAMSize=10737418240`

**Memory on the 30 GB host, shared with other sessions.** `BUN_JSC_forceRAMSize=10737418240` is what makes the gates fit. Measured this session: `PROOF.bend` 11.0–12.8 GB, 316–384 s; the JS build 13.8–16.5 GB, 128–244 s; the C build in two steps, emission `bend main.bend -o <out>/bn.c` 19.0–23.6 GB, 268–302 s, then `clang -std=c11 -O3 <out>/bn.c -lpthread -lm -o <out>/bn` 5.7–6.0 GB, 331–358 s. Announce an emission to the other sessions on the host before starting it. A JS-lane run of the port on a 25 MB store reached 21 GB and was stopped (bead `bb-rvt`).

## Last gate outputs (paste, do not paraphrase)

| gate | command | result | date |
|---|---|---|---|
| c-1t | `./scripts/conform.sh goldens/cases.tsv goldens --lane c-1t --timeout 120 -- scripts/ws-run.sh <out>/bn --threads 1 --gpu off -- ::` (binary: the two-step build above of the tree committed as `fd0a945`); failures `prefix_config_both` (DISC-010), `delete_hard_cascade_json` (DISC-011); every lane row pastes conform's last line without its `cases` array | `{"lane": "c-1t", "passed": 1007, "failed": 2, "inconclusive": 0, "stderr_compared": true, "verdict": "FAIL", "oracle_identity_checked": true}` | 2026-09-24 |
| c-8t | the same binary, `--lane c-8t --timeout 120 … --threads 8`; the same two | `{"lane": "c-8t", "passed": 1007, "failed": 2, "inconclusive": 0, "stderr_compared": true, "verdict": "FAIL", "oracle_identity_checked": true}` | 2026-09-24 |
| js | `./scripts/conform.sh goldens/cases.tsv goldens --lane js --timeout 120 -- scripts/ws-run.sh python3 $PWD/scripts/js-lane.py <out>/bn.js -- ::` (bundle of the same tree); the same two | `{"lane": "js", "passed": 1007, "failed": 2, "inconclusive": 0, "stderr_compared": true, "verdict": "FAIL", "oracle_identity_checked": true}` | 2026-09-24 |
| kill-switch | the js conform above with `scripts/ws-run.sh env BEADS_RUST_SPEC=1 python3 …` (the spec twins: `Store.load`, the list scans of the BLOCKED relation and its users, the record scan of the import check), the same bundle; the same two failures | `{"lane": "js", "passed": 1007, "failed": 2, "inconclusive": 0, "stderr_compared": true, "verdict": "FAIL", "oracle_identity_checked": true}` | 2026-09-24 |
| interpreter | `INTERP_NOTE_CACHE=1 ./scripts/conform.sh <sample>.tsv goldens --lane interpreter --timeout 900 -- …` | BLOCKER: not run on this code. The lane type-checks the whole program per case (10+ GB, minutes per case); it needs the host alone for hours | 2026-09-24 |
| lanes | `LANE_WRAP=$PWD/scripts/ws-run.sh ./scripts/lanes.sh goldens/cases.tsv goldens $PWD/port/main.bend --threads 8 --timeout 120 --interpreter-timeout 600` | BLOCKER: not run. `lanes.sh` builds in one step (19 GB held while clang runs) and runs the interpreter over the corpus; the three fast lanes were run lane by lane instead | 2026-09-24 |
| proofs | `(cd port && $BEND_CLI PROOF.bend)` on the tree committed as `fd0a945` | `All terms check.` (0 @unsafe; 68 laws; bend 2.0.20; 12.8 GB peak, 348 s) | 2026-09-24 |
| law coverage | `./scripts/law-coverage.sh` | `{"laws": 68, "proofs": 68, "unproved": "", "ghost_proofs": "", "ghost_cited": "", "uncited": "fast_is_spec store_load_fast_dangling store_load_fast_duplicate work_blocked_rows_hierarchy work_blocked_rows_table work_figures_table work_lead_subsecond work_ready_table", "duplicate_laws": [], "duplicate_proofs": [], "unsafe": 0, "unsafe_annotations": 0, "verdict": "OK"}` | 2026-09-24 |
| spec | `python3 -B scripts/spec-lint.py docs/EXISTING_BEADS_RUST_STRUCTURE.md goldens/cases.tsv` | PASS: `spec-lint: 909 clauses, 1009 cases, 1009 cases cited, 0 finding(s)` | 2026-09-24 |
| architecture | `python3 -B scripts/arch-lint.py` (the one finding: `LAWS.bend still carries the template's S0.1 / core_fast law`, owner question below) | `{"clauses": 774, "homed": 774, "numeric_rows": 25, "s6_rows": 36, "fast_twins": 2, "missing": [], "findings": 1, "verdict": "FAIL"}` | 2026-09-24 |
| parity | `./scripts/parity-board.sh docs/FEATURE_PARITY.md` | `{"rows": 42, "present": 9, "partial": 20, "missing": 0, "excluded": 13, "na": 0, "no_evidence": 0, "verdict": "PARTIAL"}` | 2026-09-24 |
| floor | `./scripts/floor.sh <new16>.tsv goldens --repeat 3 --timeout 120 -- scripts/ws-run.sh --oracle br --no-db ::` over the 16 cases of OQ-131, OQ-132 and OQ-133 | `{"repeat":3,"stable":16,"unstable":[],"inconclusive":[],"oracle_identity_checked":true,"verdict":"STABLE"}` | 2026-09-24 |
| cases | `./scripts/cases-lint.sh goldens/cases.tsv` | `{"cases": 1009, "errors": 0, "notes": 9, "classes_missing": "", "verdict": "OK"}` | 2026-09-24 |
| port lint | `python3 -B scripts/port-lint.py port/main.bend port/core/*.bend --laws port/LAWS.bend --json-only` (30 errors: 29 PL-11 and the PL-17 on the template law; not triaged this session, bead below) | `{"files": 32, "findings": 331, "errors": 30, "warnings": 4, "infos": 297, "by_rule": {"PL-02": 297, "PL-11": 29, "PL-01": 2, "PL-04": 1, "PL-12": 1, "PL-17": 1}, "laws": "port/LAWS.bend", "spec": "…/docs/EXISTING_BEADS_RUST_STRUCTURE.md", "verdict": "FINDINGS"}` | 2026-09-24 |
| pin | `./scripts/pin-check.sh docs/PIN.toml`, after a re-capture that moved no golden hash (before it: RED on `manifest_hashes`, `capture integrity failed: changed input …/.beads/issues.jsonl`; the capture records this repository's own tracker as case inputs, so the next bead edit turns it RED again: bead `bb-nvc`) | `{"schema":"p2b.pin-check.v1","sha":"fd0a945","bend":"bend 2.0.20","host":"Linux-x86_64","checks":[{"check":"original_present","status":"GREEN","note":"legacy/BEADS_RUST_v0.6.0"},{"check":"original_commit","status":"YELLOW","note":"no VCS identity; preserve original source hashes with the capture"},{"check":"original_gitignored","status":"GREEN","note":"git check-ignore: legacy/BEADS_RUST_v0.6.0"},{"check":"original_version","status":"GREEN","note":"br 0.6.0"},{"check":"manifest","status":"GREEN","note":"captured: 2026-09-24T07:57:01.883232+00:00"},{"check":"manifest_hashes","status":"GREEN","note":"3027 hashes and capture inputs verified"},{"check":"manifest_command","status":"GREEN","note":"[\"scripts/ws-run.sh\", \"--oracle\", \"br\", \"--no-db\", \"::\"]"},{"check":"manifest_version","status":"YELLOW","note":"MANIFEST version lacks the pinned version string 'br 0.6.0' (the original does not answer --version, or the pin moved)"},{"check":"case_count","status":"GREEN","note":"1009 cases = 1009 goldens = MANIFEST 1009"},{"check":"bend_version","status":"GREEN","note":"bend 2.0.20"},{"check":"lane_interpreter","status":"GREEN","note":"/data/projects/beads_bend/scripts/bend-cli.sh"},{"check":"lane_c-1t","status":"GREEN","note":"Ubuntu clang version 21.1.8 (6ubuntu1)"},{"check":"lane_c-Nt","status":"GREEN","note":"Ubuntu clang version 21.1.8 (6ubuntu1)"},{"check":"lane_js","status":"GREEN","note":"bun 1.4.2"},{"check":"approver","status":"GREEN","note":"Jeffrey Emanuel (repository owner)"}],"verdict":"YELLOW"}` | 2026-09-24 |
| incumbent | `./scripts/incumbent-bench.sh --pin …` | NOT_RUN: Phase 5 has not begun (the parity gate comes first) | |

**The real-store sweep (a probe, not a gate).** `scripts/real-store-sweep.py run <dir> <out>/bn -j 3` runs `count`, `list --json`, `ready --json`, `blocked --json`, `stats --json` and `show <first id> --json` on the original and on the port over snapshots of the host's `.beads/issues.jsonl` stores, each copied in through `scripts/ws-run.sh … :: @store=<path>` (`/dp/beads_rust` excluded); runs 1 and 2 ran the same code from the session's scratch directory before it was committed as this script. Run 1, binary of `d3f9239`: `{"stores": 138, "runs": 828, "differences": 34, "stores_with_difference": 13}`. Run 2, binary of `fd0a945`: `{"stores": 138, "runs": 828, "differences": 16, "stores_with_difference": 5}`; all 16 are DISC-012 (both sides refuse, exit 6, `SYNC_CONFLICT`; only the named record differs), in the 5 stores with several refused records.

Reading the table. The three fast lanes are the whole corpus on one build each. The sweep is a probe, not goldens: the stores are other projects' trackers and are not committed. Its run 1 found three behaviors no case had captured (round 11 below); each is now a set of captured cases and a repair. What run 2 still reports is DISC-012: with several refused records the original names one at random (for the same store it named `bd-38oh` in run 1 and `bd-8po2` in run 2).

What the port does NOT do, and answers with its own `INTERNAL_ERROR` failure (exit 1) instead of guessing: the markdown import of `create --file` (OQ-051); `--agent-context @path`; an `--agent-context` float beyond 15 significant digits or outside ryu's plain notation, a malformed JSON literal, a repeated key; `stats --activity` (needs git, PLAN §3); `dep cycles` on a graph that still has a cycle (OQ-129); the help text of the levels no case prints.

## What this session added

Session 8 (2026-09-24), the beads of the 2026-09-23 reality check taken in order.

- **Performance levers, each a fast twin behind `BEADS_RUST_SPEC=1` with closed laws** (`perf/EXPERIMENTS.md`, exploratory timings, nothing measured): EXP-003 the load's duplicate-id check through a `Map` (quadratic → linear: 4,000 records 32.9 s on C before); EXP-004 the BLOCKED relation's record lookups and the id sets of `ready`/`stats`/`blocked` through `Map`s; EXP-005 the relation itself over a table (a 2,945-record store with 7,818 edges: `stats --json` 43.7 s → 15.4 s, single runs).
- **The real-store sweep** (bead `bb-acg`): `ws_inner.py` gains `@store=<absolute path>` (re-captured with `--repin`: no golden hash moved except the two documented draws), 138 store snapshots, run 1 above.
- **Three behaviors found by the sweep, captured and repaired**: the import's dependency edges (S2.57 amended, S2.58 new: a target that is not stored, an edge on itself, an `issue_id` naming another record; 13 cases, OQ-131); `show` of a missing target (`[missing issue: <id>]`, OQ-132, 2 cases); lead times keep fractions of a second (OQ-133, 1 case). DISC-012 (OPEN) records the original's random pick among several refused records.
- **JS lane**: a text member of 64 KB or more faulted the JS lane (DISC-008 amended, bead `bb-rvt`): `Json.codes`, `Json.byte_len`, `Store.has_nul`, `Store.has_space` recursed once per character; with accumulators the load answers a 1.4-million-character member (probe `port/probes/longstr/`).
- **Laws** 61 → 68. **Corpus** 993 → 1009. AGENTS.md's facts brought up to date (bead `bb-nr7`).

## Open items

| id | what | blocks | owner |
|---|---|---|---|
| DISC-009, DISC-010, DISC-011, DISC-012 | all four OPEN, each with its measured impact: the wall clock's precision per engine; `issue_prefix` vs `prefix` drawn at random by the original; `events_removed` of a cascaded purge drawn at random; which refused record the import names when several fail | convergence (an OPEN DISC blocks it) | **the repository owner: accept, reject, or choose a canonicalizing wrapper** (bead `bb-mjf`) |
| scaffold law | `LAWS.bend`'s template law `fast_is_spec` (S0.1, `core/scaffold.bend`) binds nothing of this port; arch-lint FAIL and port-lint PL-17 both name it. LAWS.bend is human-owned | arch-lint, port-lint | **the repository owner** (bead `bb-ym9`) |
| `bb-nvc` | the capture records the repository's own `.beads/` files as case inputs; pin-check RED after any bead edit. Fix in the `porting-to-bend2` skill's `golden-capture.sh`, then re-copy | pin-check | author |
| `bb-rvt` | JS lane on the real 25 MB and 46 MB stores after the load repair: not re-run (21 GB; needs a quiet host) | the JS half of the large-store claim | author |
| OQ register | 133 rows, 21 open (`scripts/converge.sh`); most need a harness mode (bead `bb-sfm`) or an owner decision (OQ-129, bead `bb-ptx`) | phase 4 convergence | author, owner |
| interpreter lane | not run on this code (BLOCKER row above) | T3 "every lane" | author (needs the host alone for hours) |
| port lint | 29 PL-11 errors not triaged this session | nothing yet | author |

## Find-fix rounds (Phase 4/5)

| round | lens | new genuine findings | fixed | clean | date |
|---|---|---|---|---|---|
| 1 | the spec clauses the corpus does not reach, over the five commands session 3 ported (author round) | 1: S4.341 — a second `delete` of an already-tombstoned id rewrote four fields and the store; the original writes nothing | 1 (`core/remove.bend`) | no | 2026-09-20 |
| 2 | the S9 error table against the port's failures (author round) | 2: S9.22 — the `SELF_DEPENDENCY` context key is `id`, not `issue_id`; S9.11 — the shell's `String.trim_end` ate a trailing SPACE | 2 (`core/edges.bend`; `port/main.bend`) | no | 2026-09-20 |
| 3 | the JSON envelopes and payload rows of the six commands session 3 ported (author round) | 0: six captured envelopes matched the port's spec-derived text byte for byte | 0 | yes | 2026-09-20 |
| 4 | Quiet mode over the mutations (S5.106, S5.107, S9.26, OQ-015) (author round) | 2: `close --quiet` still printed the per-item `Warning: Skipped …` lines; `reopen --quiet` printed nothing where the original prints `✓ Reopened` | 2 (`core/run.bend`) | no | 2026-09-20 |
| 5 | the actor ladders (S4.200, S4.201) (author round) | 0: `actor_flag_dep_add`, `actor_flag_delete` and `actor_flag_label_add` matched on their first run | 0 | yes | 2026-09-20 |
| 6 | the dependency graph beyond depth 0 (author round) | 4: S5.179 precedence; S4.184's sort keys; the original's mixed-pair cycle gap (OQ-129); the DISC register's `Resolution` field shape | 4 | no | 2026-09-21 |
| 7 | `dep list --direction up` and `--direction both` (author round) | 0: ten captured cases matched on their first run | 0 | yes | 2026-09-22 |
| 8 | re-test the last repairs: the forms closed in sessions 5–6 crossed with flags their cases did not combine (author round) | 0: thirteen captured cases (`r8_*`, `scn_r8_*`), floored STABLE, matched on js on their first run | 0 | yes | 2026-09-23 |
| 9 | `--quiet` and the JSON error envelopes over the same closures (author round) | 0: thirteen captured cases (`r9_*`, `scn_r9_*`), floored STABLE, matched on js on their first run | 0 | yes | 2026-09-23 |
| 10 | the query commands over the larger fixtures no query case had used, run by a fresh agent that did not write the port, with only the spec and the harness (non-author) | 0: thirty-five captured cases (`r10_*`), floored STABLE, matched on js on their first run | 0 | yes | 2026-09-23 |
| 11 | real stores: the original and the port on snapshots of 138 `.beads/issues.jsonl` stores found on this host, six read commands each (author round) | 3: the import refuses dependency edges the corpus never had (S2.57, S2.58, OQ-131); `show` of a missing target (S5.151, OQ-132); lead times keep fractions of a second (S4.154, OQ-133) | 3 (`core/store.bend`, `core/show.bend`, `core/work.bend`, `core/model.bend`) | no | 2026-09-24 |

Convergence (`./scripts/converge.sh docs/PORT_STATE.md`): `NOT_CONVERGED` — round 11 found three behaviors, so the clean tail restarts; 21 OQs are open and four DISCs are OPEN (`DISC-009` … `DISC-012`), which only the repository owner can accept or reject.

## Next action (one line, executable)

`scripts/real-store-sweep.py snapshot $TMPDIR/rss && scripts/real-store-sweep.py run $TMPDIR/rss <out>/bn -j 3` with a binary built from `main` (round 12 re-runs the sweep as its clean check); then `br ready --json` and take `bb-9ru` (a non-author find-fix round over the code of batches 5–8).
