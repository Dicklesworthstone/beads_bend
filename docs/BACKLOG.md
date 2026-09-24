# Backlog (the granular to-do list) — the Bend 2 port of BEADS_RUST

The working list. `docs/PORT_STATE.md` is the resume document (gate lines, next
action); this file is the granular backlog behind it. An item is checked only
when its evidence exists (a gate line, a golden passing on a lane, a commit).
Items found during the work are appended under the phase they belong to.

Legend: `[x]` done with evidence · `[ ]` open · `[~]` partly done (what is
left is stated) · `(OQ-n)` / `(DISC-n)` cross-reference the registers.

## A. Owner decisions (delegated 2026-09-20: "You decide on everything. I approve whatever you want to do.")

- [x] A1. Git remote: create a public GitHub repository under the owner's account, with a description and topics; push `main`
  - [x] A1.1 scan tracked files for IPs, key paths, tokens, email addresses (clean, 864 files)
  - [x] A1.2 add a LICENSE (the owner's beads_rust license text, the project this one ports)
  - [x] A1.3 `gh repo create` public, description, topics, homepage-free
  - [x] A1.4 push `main`; `git status` shows up to date with origin (https://github.com/Dicklesworthstone/beads_bend)
  - [x] A1.5 README: repository URL, clone line, license section; AGENTS.md and PORT_STATE: the remote exists
- [x] A2. DISC-001…DISC-005: record ACCEPTED with the approver and the authorizing words
- [x] A3. UBS `python.taint.command` on `scripts/ws_inner.py`: one inline `# ubs:ignore[python.taint.command]` with the reason on the one line; `ubs scripts/ws_inner.py` exits 0
- [x] A4. The port's `version` contract and binary name (`bn`): DISC-006 ACCEPTED, OQ-003 resolved; the canonicalizer itself lands with E3.5

## B. Phase 0 — truth pack (done; maintenance items)

- [x] B1. 235 goldens, floor STABLE, MANIFEST pinned (344 since the three parser batches of B12)
- [ ] B2. ws-run: a mode that dumps EVERY file under `.beads/` (needed by OQ-005 `init`, OQ-008 sidecars)
- [ ] B3. ws-run: a directive to run from a SUBDIRECTORY of the workspace (upward walk, OQ-103)
- [ ] B4. ws-run: a directive to set ONE environment variable (`BEADS_DIR`, `BR_OUTPUT_FORMAT`, `BD_ACTOR`; S1/S8 cases)
- [ ] B5. ws-run: fixture selector for `.beads/` WITHOUT `issues.jsonl`, and binary fixtures (non-UTF-8, OQ-101)
- [ ] B6. ws-run: stage extra input files in the workspace (`--description-file`, `create -f`, `comments add -f`, `delete --from-file`)
- [~] B7. Large fixtures through the oracle: `n163`, `n164`, `n983`, `n984` built and captured (OQ-006 resolved, 2026-09-22); left: the real stores of this machine, which reach 45 MB (section H1)
- [x] B8. Non-integer average lead time: scenarios `lead_time_half`, `lead_time_third` (OQ-078 resolved 2026-09-23)
- [~] B9. Diamonds, external blockers, templates, custom statuses captured (batches 3, 5, 6); left: a real dependency cycle (OQ-129, the owner's call)
- [ ] B10. Capture the extractors' ~215 `(case to add …)` proposals in batches with `golden-capture.sh --repin`, re-floor
- [ ] B11. Full four-lane run at HEAD when the machine has memory (last one was stopped by the harness)
- [x] B12. The parser's surface as cases, three batches under `--repin`: 43 (every command's usage line, the argument syntax forms), 41 (refusal shapes, value checks, exclusions, aliases, hyphen values), 25 (the questions the first two raised: OQ-104…OQ-113). 344 cases
  - [x] B12.1 floor over 278: STABLE
  - [x] B12.2 floor over 344: STABLE
- [x] B13. `scripts/quick-lanes.sh`: c-1t and js over the whole corpus, the inner loop (the four-lane gate stays `scripts/lanes.sh`)

## C. Phase 1 — spec (first pass done)

- [x] C1. 874 clauses merged; spec-lint 0 findings; blind review 10/10
- [x] C2. The six contradictions the blind review found (OQ-093…OQ-098) resolved and their clauses amended (2026-09-23)
- [ ] C3. Reconcile S4.52 vs S8.31 (how often the clock is read, OQ-100)
- [ ] C4. S10.49 looks misattributed (`where` omits `prefix:` when the prefix is undetectable): verify and amend
- [ ] C5. Second extraction pass (same prompt, same files) per section; third, case-keyed expansion pass
- [ ] C6. Second blind self-containment review on ten NEW cases, including mutating ones, after C2
- [~] C7. Resolve or exclude every OPEN row of `docs/OPEN_QUESTIONS.md`: 21 open on 2026-09-23 (from 107), most needing a harness mode (B2–B6) or the owner (OQ-129)

## D. Phase 2 — architecture (done; amendments)

- [x] D1. PROPOSED_ARCHITECTURE, NUMERIC_PLAN, parity skeleton; arch-lint PASS
- [ ] D2. Amend the architecture: `Sys.remove`, `Sys.rename` effects are planned, not written; `Clock.wall` lives in a probe only
- [x] D3. S7.20: the multi-limb binary64 routine, `port/core/float.bend` (exact nearest double, ryu's shortest round trip, `{:.1}`); `scn_lead_time_third` passes

## E. Phase 3 — reference port

### E1. Foundations (done)
- [x] bytes (UTF-8 encode/decode) · sha256 · id (seed, hash36, length table) · time (RFC 3339) · json (lexer, members) · failure (renderings, escaping) · model (record, store line) · decode (line → record) · store (load, refusals) · run (dispatcher) · scaffold · shell with `Sys.exit`, `Sys.cwd`
- [x] 29 closed laws proved; 7 of 235 cases pass on c-1t

### E2. Command line (S1.1–S1.30, S1.68–S1.92) — `port/core/surface.bend` (tables), `port/core/cli.bend` (algorithm), `port/core/help.bend` (generated texts)
- [x] E2.1 read S1 in full; list the grammar: global flags, per-command flags, value syntax, aliases, conflicts → `core/surface.bend`, 36 levels
- [x] E2.2 the token layer: `--flag`, `--flag=value`, `-f`, `-fvalue`, combined shorts, `--`, negative numbers, `-` alone
- [x] E2.3 clap's refusals, verbatim, exit 2: unknown subcommand and option (with the similarity tips, Jaro in exact fractions), the `--` advice, missing value, invalid value (unsigned, ranged, enumerated with the similar-value tip), repeated option, unexpected value, exclusions in argv order, missing positionals, the order rule of S1.84
- [x] E2.4 the bare `dep` / `label` / `epic` help blocks on stderr, exit 2; a group with options only (S1.83)
- [x] E2.5 the result type: `Cli.Parsed` with `Command{path, opts, words}` (NOT one constructor per command form: PROPOSED_ARCHITECTURE §2 amended)
- [x] E2.6 route `Run.outcome` through it: usage refusals come BEFORE any workspace or store access
- [x] E2.7 goldens on c-1t and js: every `usage_*` case that the parser alone decides passes; the rest wait for their command (E5, E6) or for `version` (E3.5)
- [x] E2.8 help texts: top (`--help`, `help`), `list --help`, `list -h`, `help list`, the three groups; the spec appendix `docs/spec-parts/HELP_TEXTS.md` (clause S1.89) is their single source, `scripts/gen-help-bend.py` builds the module
- [x] E2.9 eight closed laws (`cli_*`): refusal texts, similarity, exclusions, accepted command lines, help forms
- [x] E2.10 DISC-007: an explicit top-level `--no-db` is accepted
- [ ] E2.11 the help text of the other 30 levels, long and short (about 60 cases and 150 KB of text): decide in PLAN §3 whether they stay excluded
- [ ] E2.12 open parser questions: OQ-106 (threshold in floating point), OQ-107 (equal similarity), OQ-111 (`--assignee` bare against empty)
- [ ] E2.13 environment reads the parser's callers need (`BR_OUTPUT_FORMAT`, `NO_COLOR`, `USER`, `BD_ACTOR`…): a `Sys.env` custom effect, probed on three engines

### E3. Workspace (S2.1–S2.23) — `core/discover.bend`
- [ ] E3.1 upward walk for `.beads/` then `_beads/`; `BEADS_DIR`; `redirect` (fuel 10); probes in the shell, decision in the core
- [ ] E3.2 the prefix: `config.yaml` `issue_prefix`, directory-name rules, fallback `br`
- [ ] E3.3 `metadata.json`, `BEADS_JSONL`, user-level config layers under `$HOME`
- [ ] E3.4 `where` (plain, JSON): goldens `where_plain`, `where_json`
- [x] E3.5 `version` per DISC-006 (`bn version 0.1.0 (bend 2.0.20) (port of br 0.6.0@b1cfebe)`, the JSON report, and `bn --version`), the shape canonicalizer `versions`/`canon_version` in `scripts/ws_inner.py`, the three goldens re-captured with `--disc DISC-006` (the MANIFEST diff named only them)

### E4. Store completeness — `core/store.bend`
- [x] E4.1 (`Model.repaired`, `Store.model`; `show` keeps the raw records) load repairs S2.31–S2.36: status/type/dep-type folding and aliases; label sort+dedup; duplicate edges; duplicate comments; `-wisp-` ⇒ ephemeral; `closed_at` repairs; `external_ref` trim; `updated_at` ≥ `created_at`
- [~] E4.2 duplicate-id refusal (S2.40) done (`error_jsonl_duplicate_id*`); tombstone protection (S2.42) not measured
- [~] E4.3 validation S2.43–S2.54 done, in the measured order, exit 7 (`error_load_*`); the import check S2.57 done; S2.55 (comments) and S2.56 (dependencies) not measured
- [x] E4.4 `Store.text`: records by id bytes, `\n` each; S5.9 `""` rule; S5.14 dependency defaults (`import`, `{}`, `""`); S5.16 exclusions
- [ ] E4.5 laws: `labels_normalize_idempotent`, `store_text_fixpoint_basic`, a closed law for `edge_precision_rewrite`'s lines
- [ ] E4.6 UTF-8 strictness (overlong, surrogates, > U+10FFFF) after OQ-101

### E5. Queries — `core/query.bend`, `core/blocked.bend`, `core/graph.bend`
- [x] E5.1 visibility, filters (statuses, types, priorities with ranges and comma lists, assignee, ids, labels, bounds, the three `--*-contains`), `--limit/--offset`, `total/has_more`; six `le` comparators over precomputed sort keys (`Query.Row`)
  - [ ] E5.1a `--overdue` (needs the clock: E6), `--tree`, `--pretty`, `--format json|csv`
- [x] E5.2a `list` plain / `--long` / JSON (`Model.listed`), `count` and every `--by-*`: all 38 `list_*`/`count_*` cases pass on c-1t and js
- [x] E5.2b `search` (hidden closed matches, the 50-row page); `stats` (every figure; an average lead time that is not a whole number of tenths stays refused: OQ-078)
  - [ ] E5.2c the `stats` breakdowns (`--by-*`); `list --overdue/--tree/--pretty`
- [x] E5.3 the BLOCKED relation (three ordered steps, the external overlay, fuel-bounded propagation) in `core/blocked.bend`; `ready` (three sort policies, the defer gate against the pinned instant) and `blocked` in `core/work.bend`
  - [ ] E5.3a `ready --parent/--recursive/--epic`
  - [x] E5.3b `blocked --detailed` (S5.254, round 9, 2026-09-22): five cases captured first, among them the first `external:` blocker (`scn_blocked_detailed_external`); `Render.blocked_detail`; JSON unchanged by the flag
- [x] E5.4 `show` (raw-record path, S2.39; partial ids in `core/resolve.bend`), `dep list` (two orders), `epic status`, `label list`, `label list-all`, `comments list`, `where` in `core/views.bend`
  - [x] E5.4a `dep tree` with children: the traversal of S4.182-S4.185 is `Views.tree_walk` in `core/views.bend`, a single
    fuel-bounded worklist DFS (Bend forbids the mutual recursion the shape invites). Fixtures `graph` and `hierarchy` were
    built through the ORIGINAL first (`build_graph.scn`, `build_hierarchy.scn`); 30 cases captured; all 22 `dep_tree_*`
    pass on c-1t, c-8t and js on their first run. Law `run_dep_tree_repeat`. S5.179 and S4.184 amended from the goldens
  - [x] E5.4a-1 `dep tree --format mermaid` (S4.394, S5.253, OQ-130, round 8, 2026-09-22): nine cases captured first; `Views.tree_mermaid`; law `run_dep_tree_mermaid`. `dep list --direction up/both` (round 7): ten cases, no port change needed
  - [ ] E5.4a-2 `dep cycles` reporting a cycle (S4.187): unreachable through the original, which refuses a blocking cycle
    at `dep add` on every route tried and ignores `related` cycles. A `cycles` fixture would be the first hand-written
    store that is not the original's own output: the owner's call (OQ-129)
  - [~] E5.4b `show`: wrapping of bodies and comments (S5.115) and the plain deferred/estimate/due/ref fields done; `Rollup:` not captured
- [ ] E5.5 laws: `counts_sum_to_total`; order laws for the comparators

### E6. Mutations — `core/mutate.bend`
- [x] E6.1 `create`, `q` (full id ladder against the store; child ids; `--deps`, `--parent`; `--dry-run`, `--silent`, `--ephemeral`)
- [x] E6.2 `update` (every flag, `--claim`, last-touched fallback), `close` (+`--suggest-next`, blocked refusal, partial batches exit 3), `reopen`, `defer`/`undefer` (date forms S4.56–S4.62)
- [x] E6.3 `delete` (tombstone, dependents, `--force`, `--cascade`, `--dry-run`, removes `last-touched`) — `core/remove.bend`; `--hard` and `--from-file` answer the port's own failure (OQ-128), as do a `--json` preview or dry run and `--dry-run` with `--force`/`--cascade` (OQ-127)
- [x] E6.4 `dep add/remove` (cycle refusal exit 5, no-op duplicates) in `core/edges.bend`; `label add/remove/rename` and `comments add` (id = store-wide max + 1) in `core/labels.bend`. Left refused with the port's own failure: a tombstoned endpoint and a `parent-child` edge to an `external:` target (OQ-124), the split of more than two label positionals (OQ-122), a label positional that resolves to nothing (OQ-123), `comments add -f`
  - [x] E6.4a `epic close-eligible` (S4.390–S4.393): six cases captured first (`epic_close_eligible_none`, `…_none_json`, `…_dry_run`, `…_dry_run_json`, `scn_epic_close_eligible`, `scn_epic_close_eligible_plain`), then implemented in `core/status.bend` and `core/run.bend`; all six pass on the first lane run. `--transition-comment` answers the port's own failure
- [ ] E6.5 the shell's writes: `Sys.rename` temp-file publication, `Sys.remove`, `last-touched` ordering after the flush
- [~] E6.6 `Clock.wall` read by the shell: an unpinned `create` works (checked on a real store copy, 2026-09-23); the precision difference is DISC-009 (OPEN, the owner's)

### E7. Rendering — `core/render.bend`
- [ ] E7.1 plain text per command (S5.100–S5.252): glyphs, padding, pluralization, wrapping at 100 columns
- [ ] E7.2 JSON per command (S5.20–S5.58): key orders, `+00:00` in `close`/`defer` payloads, `--fields` ignored under `--json`
- [ ] E7.3 quiet mode; warnings on stderr; the complete S9 error table as `Failure.*` constructors

### E8. Phase 3 exit
- [ ] E8.1 lanes PASS on interpreter, c-1t, c-8t, js (gpu MISSING with reason)
- [ ] E8.2 every def tagged; `law-coverage.sh` OK; `port-lint.py` no errors
- [x] E8.3 stack safety on the JS lane for a large store (B7) — the fault was the port's own `joined_bytes` (`List.concat` over the read chunks, one JS stack frame per element), not a runtime wall: `port/probes/jsdepth/` reads 1,638,750 bytes three ways on the JS lane without faulting. The shell now answers a single chunk as it is and reads 64 MiB at a time; the JS lane carries 5,000 records. Locked in by fixture `large` and the cases `edge_large_count`, `edge_large_list_limit`, `edge_large_create` (DISC-008 RESOLVED)
  - [ ] E8.3a the other 180 PL-02 infos: the core still walks store-sized lists in non-tail positions (`Model.repaired`, the renderers, `Store.text_lines`). 512 records and 5,000 records pass on every lane today; find the size at which the core itself faults, and decide there whether the port needs accumulator twins

## F. Phases 4–6

- [ ] F1. Parity gate: board FULL/DEBT; ≥ 10 find-fix rounds with rotating lenses, 2 consecutive clean, non-author rounds; `law-mutation.sh` STRONG for every def a property law names
- [ ] F2. Performance: hotspot → card → fast twin → law → keep-audit → cv-gated capture → ledger; incumbent = `br --no-db` in the sandbox at thread parity
- [ ] F3. Certify: `docs/PORT_REPORT.md`, evidence bundle, SHIP / HOLD / BLOCK

## G. Toolchain and upstream

- [ ] G1. File upstream (bendlang/bend): the foreign-reliance verdict cost (reproducer `port/probe_shell_time.bend`); the `../` import + `( .. : U32)` misresolution; GUIDE.md still saying bare operators default to `Nat`; the JS backend walking a list on the JavaScript call stack, which faults above ~30 KB of input (DISC-008); and the error a multi-scrutinee `match` out of parameter order gives, which names neither the order nor the scrutinee (PLAN §8)
- [ ] G2. `scripts/version-drift.sh` between 2.0.16 and 2.0.20 now that the port has gates
- [ ] G3. CI: `assets/github-workflows/port-gates.yml` filled for this port (compiler + oracle placeholders), once a runner with bubblewrap and the pins exists

## H. Reality check, 2026-09-23 — the bridge plan

Written after running the port (the JS bundle of the working tree) on copies of real `.beads/issues.jsonl` stores from
this machine (136 of them, 37 KB to 45 MB), outside the harness. The corpus says the port matches the original byte for
byte on 993 captured cases; the real stores said three other things. Each item below is a bead (`br list`).

### H1. Real stores: correctness beyond the corpus
- [x] H1.1 The id-shape rule of batch 5 refused every real store whose prefix holds `_` (`franken_agent_detection-13w`):
  shipped in `3eb2ee0`, found by running the port on a real store, re-measured with 8 prefix cases, fixed (split at the
  LAST hyphen; the prefix allows `_`, `.`, `-`)
- [ ] H1.2 A real-store sweep through the sandbox: a `ws_inner` directive `@store=<absolute path>` that copies an external
  store read-only into `/mnt/proj/.beads/`, then `count`, `list --json`, `ready --json`, `blocked --json`, `stats --json`,
  `show <first id> --json` on the original and the port, compared byte for byte. A probe, not a golden (the stores are
  not ours to commit); every difference becomes a captured case on a hand-written fixture
- [ ] H1.3 Every refusal the port raised on a real store explained (the sweep's report)
- [ ] H1.4 Shrink every divergence the sweep finds to its smallest reproducing store by delta debugging (drop records, then members, while the port and the original still differ), and commit the shrunk store as a hand-written fixture with its case: the real stores become a generator of minimal, reviewable cases instead of a pile of anecdotes
- [ ] H1.5 The sweep as a standing probe: all 136 stores × the six read-only commands, rerun at every certified commit, its summary line pasted into PORT_STATE beside the lanes

### H2. Performance: the port is not usable on real stores yet
- [ ] H2.1 Measure the C lane on the real-store copies (the JS lane: 7.4 s for `count` and 18.8 s for `stats` on a 1 MB,
  966-record store, about 1 GB; no answer within 5 minutes and 7.3 GB on a 25 MB store; `br` answers in milliseconds).
  An informal timing today, a measurement only through `scripts/incumbent-bench.sh`
- [ ] H2.2 Profile the load path: the duplicate-id check added in batch 5 is quadratic (`Store.has_id` over the records
  so far); the decode of a 44-member record per line; `Model.repaired`; the BLOCKED relation's fixed point
- [ ] H2.3 Phase 5 levers, each with a card, a fast twin, a `{fast == spec}` law and the kill-switch: an id index for
  the duplicate check, the decode, sorting, the relation
- [ ] H2.4 The incumbent contract in PLAN (commit, toolchain, flags, threads) and the first `incumbent-bench.sh --pin`
- [ ] H2.5 The target, stated so it can fail: on the C lane, `count`, `ready` and `stats` on the 45 MB store no slower than `br --no-db` on the same copy (which imports the whole file into SQLite on every call), measured by `incumbent-bench.sh` with the cv gate. The route: a projection twin that decodes only the members a command reads, bound to the full decode followed by the projection by a quantified law; an id index built once per load; the parallel decode that exists (`Store.load_fast`) extended to the repairs

### H3. The law side is mostly unbuilt
- [ ] H3.1 Of 61 laws only the scaffold's `fast_is_spec` is quantified; every other law is a closed fact. Quantified laws
  the spec names: the store line round trip (`decode(encode(x)) == x` over a record), label normalization idempotent,
  `count` groups summing to the total, the comparators being total orders
- [ ] H3.2 `scripts/law-mutation.sh` STRONG for the two fast twins that exist (`Store.load_fast`, the child table)
- [ ] H3.3 The flagship law: the store codec round trip quantified over every record the decoder accepts, and `Store.text` idempotent over load (`text(load(text(xs))) == text(xs)`). That is the property every downstream tool (bv, git merges, agents) relies on, and today it rests on the corpus alone

### H4. Evidence gates the method requires
- [ ] H4.1 The interpreter lane over the whole corpus (BLOCKER: more than 10 GB per case; about 40 hours)
- [ ] H4.2 The C lanes at every certified commit, sequenced with the other session's heavy jobs
- [ ] H4.3 `scripts/lanes.sh` itself PASS once (the gate; the lanes have been run one by one with `conform.sh`)
- [ ] H4.4 An interpreter sample chosen by coverage rather than by hand: one case per core def the corpus reaches (the case that reaches it cheapest), so the interpreter lane checks every def in a few hours instead of 40

### H5. Using the port as a tool
- [ ] H5.1 `init` (OQ-005): without it the port cannot create a workspace; needs the harness mode that lists `.beads/`
- [ ] H5.2 The harness modes B2–B6, which 16 of the 21 open questions wait on
- [ ] H5.3 The markdown import of `create -f` (needs B6)

### H6. Documents that say what is true
- [ ] H6.1 README: every number (454 cases, 52 laws, "a mutation without `BEADS_BEND_NOW` is refused") is stale
- [ ] H6.2 AGENTS.md "Current State (2026-09-20)", the fixture list and the 384-case line
- [ ] H6.3 This backlog reconciled against the evidence (done for the items above, 2026-09-23)

### H7. The owner's decisions
- [ ] H7.1 DISC-009, DISC-010, DISC-011 (OPEN; convergence waits on them)
- [ ] H7.2 The scaffold law `fast_is_spec` (arch-lint FAIL, port-lint PL-17)
- [ ] H7.3 May a hand-written fixture hold a dependency cycle (OQ-042, OQ-074, OQ-081, OQ-129)?
