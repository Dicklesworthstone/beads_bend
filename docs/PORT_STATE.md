# Port state — BEADS_RUST → Bend 2

<!-- Read FIRST on every resume; rewritten at the END of every session.
     Facts only, each with the command that produced it. No "should",
     no "later". -->

## Where we are

| field | value |
|---|---|
| phase | 3 reference port, at its exit gate. Done: −1 fit screen; 0 truth pack (686 goldens; every case captured in sessions 5–6 floored STABLE except `delete_hard_cascade_json`, DISC-011); 1 spec, first pass (907 clauses, spec-lint 0 findings); 2 architecture. Of the port: thirty core modules under `port/core/` and the IO shell `port/main.bend` (custom effects `Sys.exit`, `Sys.cwd`, `Sys.remove`, `Clock.wall`; the shell also reads the files an argv names, S4.397). **685 of 686 cases pass on c-1t, c-8t and js, one build each of commit `b9f648b`**; the one failure is DISC-011 (the original's own `events_removed` varies between runs). The interpreter lane has not run on this code (see BLOCKER below) |
| tier | T3 |
| bend | `bend 2.0.20` (release binary, sha256 `fab9e564c578a0a1…`; run through `scripts/bend-cli.sh`); drift vs the skills' 2.0.16: DRIFT, itemized in PLAN §2b and §8 |
| original | `br 0.6.0`, tag `v0.6.0`, commit `b1cfebe`, release binary sha256 `21b967c1ae68df1a…`, run as `scripts/ws-run.sh --oracle br --no-db ::` |
| last updated | 2026-09-23 by Claude (Opus 5.5, 1M context), session 6 |
| remote | `origin` = https://github.com/Dicklesworthstone/beads_bend (public); sessions end with `main` pushed. The granular backlog is `docs/BACKLOG.md` |

Every command below assumes: `cd /data/projects/beads_bend; export BEND_NO_TELEMETRY=1 BEND_CLI=$PWD/scripts/bend-cli.sh LANE_WRAP=$PWD/scripts/ws-run.sh BUN_JSC_forceRAMSize=10737418240`

**Memory, measured this session on the 30 GB host.** `bend` runs on bun, whose JavaScriptCore sizes its heap from the machine's RAM, not from a cgroup cap. Telling it 10 GB (`BUN_JSC_forceRAMSize=10737418240`) is what makes the gates fit: `PROOF.bend` 11.5–13.1 GB peak in 275–460 s (without it the same check, and the committed `0c3615b` that passed at 14.0 GB the day before, is OOM-killed at an 18 GB cap within 63–82 s); the JS build 14.0–14.9 GB (22.7 GB without it). The C build does not fit in one step: `bend main.bend -o bn` holds its 19 GB while clang compiles. Emit the C first (`bend main.bend -o <out>/bn.c`: 22.5 GB peak, 358 s), then `clang -std=c11 -O3 <out>/bn.c -lpthread -lm -o <out>/bn` (5.3 GB, 404 s): the flags bend's own `cli_build` uses for a CPU build (`toolchain/bend-v2.0.20-src/bend2/main.ts:361`). Every heavy run went under a user-scope cgroup cap: `systemd-run --user --scope -p MemoryMax=<n>G -p MemorySwapMax=0 …`.

## Last gate outputs (paste, do not paraphrase)

| gate | command | result | date |
|---|---|---|---|
| c-1t | `./scripts/conform.sh goldens/cases.tsv goldens --lane c-1t --timeout 120 -- scripts/ws-run.sh <out>/bn --threads 1 --gpu off -- ::` (binary: the two-step build above, at `b9f648b`); the one failure: `delete_hard_cascade_json`, DISC-011 | `{"lane": "c-1t", "passed": 685, "failed": 1, "inconclusive": 0, "stderr_compared": true, "verdict": "FAIL", "oracle_identity_checked": true}` | 2026-09-23 |
| c-8t | the same binary, `--lane c-8t --timeout 120 … --threads 8`; the same failure | `{"lane": "c-8t", "passed": 685, "failed": 1, "inconclusive": 0, "stderr_compared": true, "verdict": "FAIL", "oracle_identity_checked": true}` | 2026-09-23 |
| js | `./scripts/conform.sh goldens/cases.tsv goldens --lane js --timeout 120 -- scripts/ws-run.sh python3 $PWD/scripts/js-lane.py <out>/bn.js -- ::` (bundle from `(cd port && $BEND_CLI main.bend -o <out>/bn.js)` at `b9f648b`); the same failure | `{"lane": "js", "passed": 685, "failed": 1, "inconclusive": 0, "stderr_compared": true, "verdict": "FAIL", "oracle_identity_checked": true}` | 2026-09-23 |
| interpreter | `INTERP_NOTE_CACHE=1 ./scripts/conform.sh <sample>.tsv goldens --lane interpreter --timeout 900 -- …` | BLOCKER: not run on `b9f648b`. One interpreter case (`version`) is OOM-killed under a 4 GB and an 8 GB cap (pushed code, 2026-09-22) and under a 10 GB cap with `BUN_JSC_forceRAMSize=4294967296` (2026-09-23): the lane type-checks the whole program per case (`bend core/run.bend` alone: 10.6 GB, 24 s). An uncapped case reached 19.5 GB. The lane needs the host to itself | 2026-09-23 |
| lanes | `LANE_WRAP=$PWD/scripts/ws-run.sh ./scripts/lanes.sh goldens/cases.tsv goldens $PWD/port/main.bend --threads 8 --timeout 120 --interpreter-timeout 600` | BLOCKER: not run. `lanes.sh` builds the binary in one step (19 GB held while clang runs, above) and runs the interpreter over the corpus; the three fast lanes above were run lane by lane instead | 2026-09-23 |
| proofs | `(cd port && $BEND_CLI PROOF.bend)` at `4036a3b` | `All terms check.` (0 @unsafe; 58 laws; bend 2.0.20; 13.1 GB peak, 460 s) | 2026-09-23 |
| law coverage | `./scripts/law-coverage.sh` | `{"laws": 58, "proofs": 58, "unproved": "", "ghost_proofs": "", "ghost_cited": "", "uncited": "fast_is_spec", "duplicate_laws": [], "duplicate_proofs": [], "unsafe": 0, "unsafe_annotations": 0, "verdict": "OK"}` | 2026-09-23 |
| spec | `python3 -B scripts/spec-lint.py docs/EXISTING_BEADS_RUST_STRUCTURE.md goldens/cases.tsv` | PASS: `spec-lint: 907 clauses, 686 cases, 686 cases cited, 0 finding(s)` | 2026-09-23 |
| architecture | `python3 -B scripts/arch-lint.py` (the one finding: `LAWS.bend still carries the template's S0.1 / core_fast law`, owner question below) | `{"clauses": 772, "homed": 772, "numeric_rows": 25, "s6_rows": 36, "fast_twins": 2, "missing": [], "findings": 1, "verdict": "FAIL"}` | 2026-09-23 |
| parity | `./scripts/parity-board.sh docs/FEATURE_PARITY.md` | `{"rows": 42, "present": 8, "partial": 21, "missing": 0, "excluded": 13, "na": 0, "no_evidence": 0, "verdict": "PARTIAL"}` | 2026-09-23 |
| floor | `./scripts/floor.sh <new>.tsv goldens --repeat 3 --timeout 120 -- scripts/ws-run.sh --oracle br --no-db ::` over the 40 cases captured after the first floor below | `{"repeat":3,"stable":40,"unstable":[],"inconclusive":[],"oracle_identity_checked":true,"verdict":"STABLE"}` | 2026-09-23 |
| floor (first 56) | the same over the 56 cases captured first this session (the unstable one is DISC-011) | `{"repeat":3,"stable":55,"unstable":["delete_hard_cascade_json"],"inconclusive":[],"oracle_identity_checked":true,"verdict":"UNSTABLE"}` | 2026-09-22 |
| cases | `./scripts/cases-lint.sh goldens/cases.tsv` | `{"cases": 686, "errors": 0, "notes": 16, "classes_missing": "", "verdict": "OK"}` | 2026-09-23 |
| port lint | `python3 -B scripts/port-lint.py port/main.bend port/core/*.bend --laws port/LAWS.bend --json-only` (the one error: PL-17 on `core/scaffold.bend`'s `S0.1`, the template law, owner question) | `{"files": 31, "findings": 263, "errors": 1, "warnings": 3, "infos": 259, "by_rule": {"PL-02": 259, "PL-01": 1, "PL-04": 1, "PL-12": 1, "PL-17": 1}, "laws": "port/LAWS.bend", "spec": "/data/tmp/claude-1000/-data-projects-beads-bend/3f5aee7b-2a21-4618-b9ab-688e03ea1058/scratchpad/bb/docs/EXISTING_BEADS_RUST_STRUCTURE.md", "verdict": "FINDINGS"}` | 2026-09-23 |
| pin | `./scripts/pin-check.sh docs/PIN.toml` (YELLOW: the standing two, `original_commit` and `manifest_version`) | `{"schema":"p2b.pin-check.v1","sha":"4036a3b","bend":"bend 2.0.20","host":"Linux-x86_64","checks":[{"check":"original_present","status":"GREEN","note":"legacy/BEADS_RUST_v0.6.0"},{"check":"original_commit","status":"YELLOW","note":"no VCS identity; preserve original source hashes with the capture"},{"check":"original_gitignored","status":"GREEN","note":"git check-ignore: legacy/BEADS_RUST_v0.6.0"},{"check":"original_version","status":"GREEN","note":"br 0.6.0"},{"check":"manifest","status":"GREEN","note":"captured: 2026-09-23T03:45:46.831720+00:00"},{"check":"manifest_hashes","status":"GREEN","note":"2058 hashes and capture inputs verified"},{"check":"manifest_command","status":"GREEN","note":"[\"scripts/ws-run.sh\", \"--oracle\", \"br\", \"--no-db\", \"::\"]"},{"check":"manifest_version","status":"YELLOW","note":"MANIFEST version lacks the pinned version string 'br 0.6.0' (the original does not answer --version, or the pin moved)"},{"check":"case_count","status":"GREEN","note":"686 cases = 686 goldens = MANIFEST 686"},{"check":"bend_version","status":"GREEN","note":"bend 2.0.20"},{"check":"lane_interpreter","status":"GREEN","note":"/data/projects/beads_bend/scripts/bend-cli.sh"},{"check":"lane_c-1t","status":"GREEN","note":"Ubuntu clang version 21.1.8 (6ubuntu1)"},{"check":"lane_c-Nt","status":"GREEN","note":"Ubuntu clang version 21.1.8 (6ubuntu1)"},{"check":"lane_js","status":"GREEN","note":"bun 1.4.2"},{"check":"approver","status":"GREEN","note":"Jeffrey Emanuel (repository owner)"}],"verdict":"YELLOW"}` | 2026-09-23 |
| incumbent | `./scripts/incumbent-bench.sh --pin …` | NOT_RUN: Phase 5 has not begun (the parity gate comes first) | |

Reading the table. The three fast lanes are the whole corpus of 686 cases on one build each of `b9f648b`; `4036a3b` after it adds laws, a def no command calls (`Store.issues_of`) and a comment fix, so the lanes stand for it. Every re-capture this session printed a MANIFEST diff naming only its new cases, plus the two cases the registers name as unstable, which re-draw: `prefix_config_both` (DISC-010) and `delete_hard_cascade_json` (DISC-011).

What the port does NOT do, and answers with its own `INTERNAL_ERROR` failure (exit 1) instead of guessing: `create --file` (markdown import); `--agent-context` on `create` and `update` (it re-serializes JSON and reads `@path` YAML); `dep add --metadata`; `comments add -f -` (standard input); `stats --activity` (needs git, PLAN §3); an average lead time whose tie binary64 does not hold exactly (OQ-078); `dep cycles` on a graph that still has a cycle (OQ-129); the help text of the levels no case prints.

## What this session added

Sessions 5 (2026-09-22) and 6 (2026-09-23), one conversation. Phase 3 closures, not find-fix rounds (a declared refusal is not a divergence, S9.6):

- **`delete`**: `--hard`, the purge of every tombstone, the JSON preview and every `--dry-run` form, `--from-file` (S4.333, S4.338, S4.339, S4.340; OQ-127, OQ-128 resolved). DISC-011 opened: the original's `events_removed` under `--cascade --hard` varies between runs (1, 2 or 3 of 3 over twelve runs).
- **Transitions**: `--transition-comment` on `close`, `defer`, `undefer`, `update`, `epic close-eligible`; `close --session`; `update`'s refusals of both (new clause S4.396); `close --bypass-policy/--bypass-reason` (S4.399); the dot-notation child skip of `close` (S4.292: the port had closed such a parent unchecked).
- **Files the argv names** (S4.397): the core lists them (`Run.side_files`), the shell reads each and hands back the text or the errno; `delete --from-file`, `comments add -f`, `update`/`create --description-file`.
- **The acceptance checklist** (S4.398, `core/acceptance.bend`): `update --add/--check/--uncheck-acceptance`, `show --json` `acceptance_items`.
- **Labels and edges**: the positional walk and id-shape predicate of `label add/remove` (S4.370, OQ-122, OQ-123); the 64-label ceiling with the original's partial write (S4.372, OQ-125); `update` validates every label it is given (it validated none); `dep add` refuses a tombstoned endpoint and an `external:` parent-child target (S4.353, S4.357, OQ-124).
- **`list --tree`, `--pretty`**, the `stats` breakdowns (S5.127, S5.128, S5.172).
- **Parser**: eleven more options take a value that begins with `-` (S1.87 corrected); the `CLOSE_INCOMPLETE` context member is `reason` (S9.14, OQ-013).
- **Id length** (OQ-006): fixtures `n163`, `n164`, `n983`, `n984` built by the original; its 3 → 4 → 5 steps are captured and match S4.9.
- **Laws**: 56 → 58 (`work_child_index_epic`, `work_child_index_leaf` bind the child table to the scan). `scripts/port-lint.py` re-copied from the skill.
- **Corpus**: 454 → 686 cases; MANIFEST at 686.

## Open items

| id | what | blocks | owner |
|---|---|---|---|
| DISC-009, DISC-010, DISC-011 | all three OPEN, each with its measured impact: the wall clock's precision per engine; `issue_prefix` vs `prefix` drawn at random by the original (`prefix_config_both`); `events_removed` of a cascaded purge drawn at random by the original (`delete_hard_cascade_json`) | convergence (an OPEN DISC blocks it) | **the repository owner: accept, reject, or choose a canonicalizing wrapper** |
| scaffold law | `LAWS.bend`'s template law `fast_is_spec` (S0.1, `core/scaffold.bend`) binds nothing of this port; arch-lint FAIL and port-lint PL-17 both name it. LAWS.bend is human-owned: an agent may not delete a law | arch-lint, port-lint | **the repository owner** |
| OQ register | 130 rows, 107 open (`scripts/converge.sh`) | phase 4 convergence | author |
| OQ-129 | `dep cycles` has never reported a cycle: the original refuses a blocking cycle at `dep add` on every route tried, so only a hand-written fixture can build one | the `dep cycles` half of its parity row | **the repository owner: may a hand-written `cycles` fixture be added?** |
| interpreter lane | not run on `b9f648b` (BLOCKER row above) | T3 "every lane" | author (needs the host alone for hours) |
| bug policy, duplicate case, probe scenarios | unchanged from session 5: toon_bend's fix-all order vs this port's bug-compatibility; `usage_enum_direction_dep_list` duplicates `usage_enum_direction`; `goldens/scenarios/probe_*.scn` | nothing | the repository owner |
| refusals left | `create --file`, `--agent-context`, `dep add --metadata`, `comments add -f -`, OQ-078's lead-time tie | the partial rows of `create`, `update`, `dep add`, `comments add`, `stats` | author |

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

Convergence (`./scripts/converge.sh docs/PORT_STATE.md`): `NOT_CONVERGED` — `rounds 7 < 10`, `last two rounds not both clean`, 107 open OQ, open DISC `DISC-009`, `DISC-010`, `DISC-011`, no non-author round. The session 5–6 work above is Phase 3 closure and is not counted as rounds; the two bugs the new cases exposed (`update` never validated labels; the dot-notation skip was missing) were found by the lanes on new captures, not by a round's lens.

## Next action (one line, executable)

`./scripts/ws-run.sh --oracle br --no-db :: @fx=basic update proj-b75 --status in_progress --add-label x --transition-comment note --json` — open find-fix round 8 on the lens "re-test the last repairs": the forms closed in sessions 5–6 crossed with the flags their cases did not combine (transition comments with label edits and acceptance flags, `delete --hard --from-file`, `label add` past the ceiling under `--json`, `close --session` with a skip); capture each form as a case, conform it on js, and commit each finished unit at once.
