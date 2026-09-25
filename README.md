# beads_bend - Beads in Bend 2

<div align="center">

[![Status](https://img.shields.io/badge/status-Phase%203%3A%201327%20of%201327%20cases%20on%20c--1t%2C%20c--8t%2C%20js-orange.svg)](#status)
[![Bend](https://img.shields.io/badge/bend-2.0.20%20%28pinned%29-blue.svg)](docs/PLAN_TO_PORT_BEADS_RUST_TO_BEND2.md)
[![Oracle](https://img.shields.io/badge/oracle-br%200.6.0%20%28pinned%29-orange.svg)](docs/PLAN_TO_PORT_BEADS_RUST_TO_BEND2.md)

</div>

A port of [`br` (beads_rust)](https://github.com/Dicklesworthstone/beads_rust), my Rust port of Steve Yegge's [beads](https://github.com/steveyegge/beads), to the [Bend 2](https://bend-lang.com) programming language. The contract being ported is `br --no-db`: the JSONL-only mode of the frozen "classic beads" architecture.

[Status](#status) | [TL;DR](#tldr) | [Commands](#commands) | [Scope and Exclusions](#scope-and-exclusions) | [Known Discrepancies](#known-discrepancies) | [Limitations](#limitations) | [FAQ](#faq)

<div align="center">
<h3>There is nothing to install</h3>

<p><em>There is no release, no installer and no binary to download, and the port has not been through its parity gate, its performance phase or its certification. What exists is a Bend program you can build yourself (<code>bend port/main.bend -o bn</code>) that reproduces the pinned original byte for byte on 1327 of the 1327 captured conformance cases (two of them only while the original's random draw matches), on three executors (native C at 1 and 8 threads, and JavaScript; the other two are outputs the original draws at random, DISC-010 and DISC-011), plus the evidence base a port is judged against. Read <a href="#status">Status</a> before anything else.</em></p>
</div>

---

## Status

As of 2026-09-24 this project is at the end of Phase 3 of an eight-phase port method (fit screen, truth pack, spec, architecture, reference port, parity gate, performance, certify). The fit screen, the truth pack, a first pass of the spec and the architecture are done; the reference port answers the commands the 1327-case corpus exercises, reads and writes the store, and reproduces the pinned original byte for byte on 1327 of 1327 cases on three of the four lanes (two of those hold values the original draws at random, and pass only while the captured draw matches the port; the interpreter lane has not run on the current code). Fifteen find-fix rounds have run, three of them by a non-author; the fourteenth and fifteenth found six and five behaviors (all repaired), so the two clean rounds tier T3 asks for at the end are yet to come; `scripts/converge.sh` still reports `NOT_CONVERGED`, because no spec question (OQ) is open any more but four DISCs are `OPEN` (DISC-009 to DISC-012), which only the repository owner can accept. No parity claim, no measurement, no certification. I would rather publish an honest account of a half-finished port than a README that describes software that does not exist.

| Artifact | State | Where |
|----------|-------|-------|
| The original, pinned | `br 0.6.0`, tag `v0.6.0`, commit `b1cfebe05437463e91a353cf2bedafac27266f5b`; the published release binary, 27,772,512 bytes, sha256 `21b967c1ae68df1a2e8eb2256d13b8e57d293d89e331933919076104832ddbc0` | [PLAN §2](docs/PLAN_TO_PORT_BEADS_RUST_TO_BEND2.md) |
| Bend, pinned | `bend 2.0.20` from the official installer; binary sha256 `fab9e564c578a0a15880d5fea561ac1612dba01265a5a219906b5888f3381d8c`; bun `1.4.2`; clang `21.1.8` | [PLAN §2b](docs/PLAN_TO_PORT_BEADS_RUST_TO_BEND2.md) |
| Hermetic oracle sandbox | exists: `scripts/ws-run.sh` and `scripts/ws_inner.py` (bubblewrap, tmpfs workspace, cleared environment, pinned instant) | `scripts/ws-run.sh --help` |
| Conformance cases | 1327 cases in `goldens/cases.tsv` (85 added 2026-09-24: the markdown import, long texts on the JS lane, the stored-metadata rule, round 12, the harness modes; 16 from what the real-store sweep found, OQ-131 to OQ-133; the OQ batches and find-fix rounds of 2026-09-22 and 2026-09-23 before them; 40 added 2026-09-22: `dep list --direction up/both`, `dep tree --format mermaid`, `blocked --detailed`, and `ready --parent/--recursive/--epic` on a new oracle-built fixture `parents`; 30 added 2026-09-21 for the dependency graph: real tree depth, a diamond, an ancestor back edge, `repeat` and `truncated`, `--max-depth`, the `up` and `both` directions, and the BLOCKED relation with two blockers and a blocking cycle); `scripts/cases-lint.sh`: `{"cases": 1327, "errors": 0, "notes": 16, "classes_missing": "", "verdict": "OK"}` | `goldens/` |
| Goldens | 1327 captured `.out` / `.err` / `.exit` triples from the pinned original; digests in `goldens/MANIFEST.txt`; 230 of them carry a dump of the resulting `.beads/issues.jsonl`. Three (`version_plain`, `version_json`, `usage_version_flag`) are compared through the DISC-006 shape canonicalizer, which reduces both sides to `<name> version <version> <details>` | `goldens/` |
| Reproducibility floor | `{"repeat":3,"stable":384,"unstable":[],"inconclusive":[],"oracle_identity_checked":true,"verdict":"STABLE"}` over the 384 cases of 2026-09-20, and `{"repeat":3,"stable":30,"unstable":[],"inconclusive":[],"oracle_identity_checked":true,"verdict":"STABLE"}` over the 30 added on 2026-09-21, and `{"repeat":3,"stable":40,"unstable":[],"inconclusive":[],"oracle_identity_checked":true,"verdict":"STABLE"}` over the 40 added on 2026-09-22, after the one hash-random output of the original was canonicalized (DISC-005); each later batch was floored the same way before its commit, with one unstable case, `delete_hard_cascade_json` (DISC-011), and the 16 cases added 2026-09-24 floored `{"repeat":3,"stable":16,"unstable":[],"inconclusive":[],"oracle_identity_checked":true,"verdict":"STABLE"}`. `prefix_config_both` (DISC-010) is the other output the original draws at random | `docs/PORT_STATE.md` |
| Fixtures and scenarios | 163 fixture stores in `goldens/fixtures/` (among them `basic`, `basic_touched`, `conflict`, `empty`, `graph`, `hierarchy`, `large`, `malformed`, `precision`, `parents`, and hand-written edge stores such as the `dep_dangling*` ones) and 78 scenarios; the realistic fixtures are the original's own output, `graph` and `hierarchy` included | `goldens/fixtures/`, `goldens/scenarios/` |
| Spec (Phase 1) | **first pass done**: 909 numbered clauses with `file:line` provenance and a golden case each (25 of them, S1.68–S1.92, written from measured output while the argument parser was built), merged from eight part files by `scripts/merge-spec-parts.py`; `scripts/spec-lint.py`: `spec-lint: 909 clauses, 1327 cases, 1327 cases cited, 0 finding(s)`; a blind self-containment review predicted 10 of 10 sampled cases byte for byte from the spec alone (`docs/reviews/self-containment-1/`) and still found six clause contradictions, now open questions. The method's second and third extraction passes and the capture of the extractors' proposed cases have not run | `docs/EXISTING_BEADS_RUST_STRUCTURE.md`, `docs/spec-parts/`, `docs/OPEN_QUESTIONS.md` |
| Architecture, numeric plan (Phase 2) | written: one pure function `run : Inputs -> Outcome` and a thin IO shell; every one of the 764 behavior clauses has a home def (`scripts/arch-lint.py`: PASS); no `F32` anywhere and no budgeted output class | `docs/PROPOSED_ARCHITECTURE.md`, `docs/NUMERIC_PLAN.md` |
| Bend implementation (Phase 3) | **every command the corpus exercises runs, on a store it also writes; not certified**: 31 pure modules under `port/core/` (UTF-8, SHA-256, the id hash, instants, the JSON line lexer and member splitter, the 44-member record with its store line and load repairs, the line decoder, store loading and write-back, error rendering, the command-line tables, the argument parser, the carried help texts, the listing relation, the renderers, the partial-id resolver, `show`, the BLOCKED relation, `ready`/`blocked`/`stats`, the small views, `create`, `update`, the status transitions, the date grammar, the dependency edges, labels and comments, `delete`, the dispatcher, among others) and the IO shell `port/main.bend` with five custom effects (`Sys.exit`, `Sys.cwd`, `Sys.remove`, `Sys.stdin`, `Sys.argv`, `Clock.wall`). **Golden-tested: 1327 of 1327 conformance cases pass, the same on the single-thread C lane, the 8-thread C lane and the JS lane** (`scripts/conform.sh` per lane on one build each of the working tree, 2026-09-24). Two of them hold outputs the original draws at random, so each capture holds one draw and the case passes or fails with it (this capture's draws fell on the port's values): `prefix_config_both` (DISC-010: with both `issue_prefix` and `prefix` configured the original picks one) and `delete_hard_cascade_json` (DISC-011: `events_removed` varies between runs of the original). `dep tree` walks the graph (S4.182–S4.185) and renders it as text, JSON or mermaid (S5.253); `blocked --detailed` lists each blocker (S5.254); `ready --parent`, `--recursive` and `--epic` scope the ready rows to an issue's children or descendants (S4.173); every form closed after 2026-09-22 was captured from the original before it was written. The interpreter lane has not run on the current code: one interpreter run type-checks the whole program per case, so the corpus needs the host alone for many hours. Forms no case captures are refused with the port's own failure rather than guessed; the open ones are listed in `docs/OPEN_QUESTIONS.md` | `port/`, `docs/PORT_STATE.md` |
| Laws and proofs | 73 closed laws, all proved by the checker computing both sides on one value. Among them are the first `fast == spec` laws, each on a small fixture: the parallel store load `Store.load_fast` against the sequential load (on `basic`, `precision`, a refusal, a duplicate id and a dangling edge), the child index, and the table-indexed BLOCKED relation and the `stats`/`ready`/`blocked` tables against the list scans they replace. The earlier 52 are: SHA-256 against three published vectors, seven captured ids from their seeds (including `q`'s empty-creator seed and the nonce ladder), the id-length table, fifteen timestamp facts (the five spellings of fixture `precision` as the original wrote them back, calendar borrows and carries, refusals), the exact store line of `create_min`, the refusal of fixture `malformed`, eight facts of the argument parser (five captured refusal texts, three accepted command lines, the help forms, the similar-value tip), priority tokens and ranges, the control-character sanitizer, the partial-id resolver on the eight ids of fixture `basic` (two captured refusal texts among its six facts), and seven whole-program facts: the pure program run on a two-record store prints the lines the `list` golden shows for those records, `count --by-status` leaves the deferred one out, and `blocked` on three records of fixture `basic` prints `goldens/blocked_plain.out` byte for byte, `dep add` on an edge that is already there rewrites nothing and still writes the sidecar, `delete` of a depended-on issue prints the six-block preview and writes nothing, and `dep tree proj-6ja` over the five records of fixture `hierarchy` prints `goldens/dep_tree_repeat.out` and, with `--format mermaid`, `goldens/dep_tree_mermaid.out`; two more pin the rounding of the average lead time (`23.25` days prints `23.2`, and a tie binary64 does not hold exactly is refused). `bend port/PROOF.bend` prints `All terms check.` with 0 `@unsafe` under `bend 2.0.20` (2026-09-24); `scripts/law-coverage.sh`: 73 laws, 73 proofs, 0 unsafe, verdict `OK`. A closed law covers one value; none of these is a quantified property, and a `fast == spec` law on one fixture does not cover other stores | `port/LAWS.bend`, `port/PROOF.bend` |
| Feasibility probes | a wall-clock custom effect (OQ-009: it loads on the interpreter, C and JS engines; Bend 2.0.20 itself has no wall clock, OQ-004; the port now wires it as `Clock.wall`, so a mutation without `BEADS_BEND_NOW` is stamped with the wall clock, at the engine's precision, DISC-009) and a SHA-256 over `U32` words whose four digests equal `hashlib`'s on all three engines (PLAN §8). Probes are not the port | `port/probes/` |
| Real-store sweep (2026-09-24) | a differential probe, not goldens: the original and the port (C lane) run on copies of 138 real `.beads/issues.jsonl` stores found on this machine (the stores are not committed). First run `{"stores": 138, "runs": 828, "differences": 34, "stores_with_difference": 13}`; the 34 differences were three behaviors the corpus had not captured, now captured as 16 cases and repaired (the import refuses dangling, self and foreign dependency edges, OQ-131; `show` of a missing target, OQ-132; lead times keep fractions of a second, OQ-133). A re-run with the repaired binary leaves only the original's random choice of which refused record it names (DISC-012). The C lanes carry these stores; the JS lane used to fault on a text member of 64 KB or more, which the load path now handles (bead `bb-rvt`), but whether the later stages carry the 25–46 MB stores on JS has not been checked (such a run needed about 21 GB of memory) | `docs/PORT_STATE.md`, `docs/OPEN_QUESTIONS.md` |
| Parity board (Phase 4) | `scripts/parity-board.sh`: `{"rows": 42, "present": 9, "partial": 20, "missing": 0, "excluded": 13, "na": 0, "no_evidence": 0, "verdict": "PARTIAL"}`. Eleven find-fix rounds have run (6 clean; round 10 by a non-author; round 11, the real-store sweep, found three behaviors, so the clean tail restarts at 0); `scripts/converge.sh` reports `NOT_CONVERGED`: no open OQ and four `OPEN` DISCs (DISC-009 to DISC-012) remain | `docs/FEATURE_PARITY.md` |
| Performance (Phase 5) | nothing has been measured. `perf/EXPERIMENTS.md` holds five experiment cards (EXP-001 to EXP-005: the child index, the parallel load, id tables for the duplicate check and the BLOCKED relation) with exploratory timings only: single runs, other jobs on the host, no cv gate, so none of them is a measurement | `perf/` |
| Port report (Phase 6) | template | `docs/PORT_REPORT.md` |
| Repository and license | public at https://github.com/Dicklesworthstone/beads_bend; `LICENSE` is MIT with the OpenAI/Anthropic rider, the same text as `br`'s. The repository tracks its own work in a `.beads/` workspace (prefix `bb`) | `LICENSE`, `.beads/` |
| Binary, installer, release | none. `bend port/main.bend -o bn` builds one locally (about 8 minutes and 19 GB of RAM at this size); `bend port/main.bend -o bn.js` builds the JS bundle in about a minute | |

`docs/PORT_STATE.md` is the live copy of this table: it is rewritten at the end of every working session with the gate lines pasted verbatim, and it wins over this README when the two differ.

**Everything below that describes issue-tracker behavior describes the contract**: what `br --no-db` does, captured byte for byte, which the port must reproduce. What the port does is only what the lane line above says: the captured cases it matches, nothing beyond them.

---

## Why This Project Exists

I (Jeffrey Emanuel) LOVE [Steve Yegge's Beads project](https://github.com/steveyegge/beads). Discovering it, and seeing how well it worked together with my [MCP Agent Mail](https://github.com/Dicklesworthstone/mcp_agent_mail), was a truly transformative moment in my development workflows and professional life. It led to [beads_viewer (bv)](https://github.com/Dicklesworthstone/beads_viewer), and my [Agent Flywheel](http://agent-flywheel.com/tldr) system is built around beads operating in a specific way. I'm very grateful to Steve for making it.

As Steve evolved beads toward [GasTown](https://github.com/steveyegge/gastown) and beyond, our use cases diverged. Rather than ask him to maintain a legacy mode for my niche, I wrote [`br`](https://github.com/Dicklesworthstone/beads_rust), a Rust port that freezes the "classic beads" architecture I depend on: issues in a local store, mirrored to a git-friendly `.beads/issues.jsonl`. Steve gave that project his full endorsement. `br` is the tool I and my agent swarms use every day, and that does not change.

This project carries the same frozen contract one step further, into Bend 2, for a different reason. Swarms of agents read `br`'s bytes: the ids, the JSONL lines, the `--json` envelopes, the exit codes. A tool like that is a good test subject for a question I care about: **what does law-proved, lane-identical software look like for a real tool, as opposed to a sorting function in a paper?** Bend 2 is a pure language in which a `law` is a claim the compiler checks and a proof is an ordinary definition; the same program runs on an interpreter, as a native binary through C at one or many threads, and as JavaScript. So the experiment is concrete: take the JSONL-only contract of `br`, capture what the original does, write the obvious Bend translation, require identical bytes on every executor, and bind every optimized function to its obvious twin by a proof.

**This isn't a criticism of `br` or of Rust.** `br` does far more than this port has in scope (SQLite, recovery tooling, workflow policy, MCP), and the exclusions below say exactly what is left out and why. It's an experiment with a hard acceptance test, with the evidence kept in the repository.

---

## TL;DR

### The Problem

Porting a tool that other programs depend on byte for byte usually ends in one of two ways:
- **"It passes my tests"**: tests written by the porter, from the porter's reading of the source, encode the porter's misunderstandings.
- **"It's equivalent, trust me"**: optimized code drifts from the simple code it replaced, and nobody can say which behaviors are evidence-backed and which are hope.

### The Solution

Two equivalences, never conflated. Every claim in this repository names which one it rests on.

| Equivalence | How it is established | Artifacts | State today |
|-------------|-----------------------|-----------|-------------|
| **original == spec** | **Golden-tested.** The pinned original's stdout, stderr and exit code are captured per case; the port must produce the same bytes on every lane (interpreter, C at 1 thread, C at N threads, JS). Empirical, and bounded by the corpus | `goldens/cases.tsv`, `goldens/MANIFEST.txt`, `scripts/lanes.sh` | 1327 cases captured, floor `STABLE` except the two outputs the original draws at random (DISC-010, DISC-011); the port passes 1327 of 1327 on c-1t, c-8t and js, the two draws included only because this capture's draws fell on the port's values |
| **spec == fast** | **Law-proved.** Every optimized def (a *fast twin*) has the same signature as its literal, sequential *spec twin*, and a law `{fast(x) == spec(x)}` that `bend port/PROOF.bend` must check, ending in `All terms check.` | `port/LAWS.bend`, `port/PROOF.bend` | closed `fast == spec` laws on small fixtures for the parallel load and the table-indexed BLOCKED relation, `stats`, `ready` and `blocked` (among 73 laws, `All terms check.`, 0 unsafe, `bend 2.0.20`); no quantified one |

Nothing compares the original with a fast twin except the shipped binary on the goldens. The lanes run the port as it is built, against the goldens; each `fast == spec` law so far is closed, on one small fixture.

### Why this contract?

| Property of `br --no-db` | Why it suits a Bend port |
|--------------------------|--------------------------|
| `issues.jsonl` is the whole store: load, answer, write back | Needs only file open/read/write/close, which Bend's effects provide |
| Deterministic given argv, the store, the environment and the clock, with one registered exception (DISC-005) | Can be golden-tested once the clock is pinned |
| The part of beads other tools consume (`bv`, git merges, agents reading `--json`) | The port is judged on the bytes that matter downstream |
| Ids and content hashes are SHA-256 based; ordering and JSON encoding are exact | Natural targets for closed laws against published vectors and for `fast == spec` laws |

---

## Quick Example

This is the contract, not the port. The transcript is what the pinned `br 0.6.0` prints inside the sandbox; each block is a captured golden (`goldens/<case>.out`, `.err`, `.exit`). The workspace is always `/mnt/proj`, so the id prefix is `proj`, and the default pinned instant is 2026-01-02 03:04:05 UTC.

```bash
# case create_min: ["create", "First issue"] on an empty store, exit 0
scripts/ws-run.sh --oracle br --no-db :: create "First issue"
# ✓ Created proj-fyw: First issue
# --- .beads/issues.jsonl ---
# {"id":"proj-fyw","title":"First issue","status":"open","priority":2,"issue_type":"task","created_at":"2026-01-02T03:04:05Z","created_by":"tester","updated_at":"2026-01-02T03:04:05Z","source_repo":"proj","source_repo_path":"/mnt/proj","compaction_level":0,"original_size":0}
# --- .beads/last-touched ---
# proj-fyw

# case ready_plain: ["@fx=basic", "ready"], exit 0
scripts/ws-run.sh --oracle br --no-db :: @fx=basic ready
# 📋 Ready work (3 issues with no blockers):
#
# 1. [● P1] [task] proj-mta: Set up database schema
# 2. [● P3] [docs] proj-5u2: Write API docs
# 3. [● P2] [task] proj-b75: Ünïcödé title — “quotes” & <tags> \ backslash

# case error_close_blocked: ["@fx=basic", "close", "proj-170"], exit 3, stdout empty, stderr:
# Warning: Skipped proj-170: blocked by: proj-mta — close the open blocker(s) first, or use --force to close anyway
# Error: Nothing to do: all 1 issue(s) skipped — proj-170: blocked by: proj-mta — close the open blocker(s) first, or use --force to close anyway
# Hint: Skipped issue(s) have open blocking dependencies. Close the blockers first, or re-run with --force to close anyway.
```

When a run changes the store, the sandbox appends `--- .beads/issues.jsonl ---` and `--- .beads/last-touched ---` dumps to stdout, so the resulting file bytes are part of the golden. A read-only command that rewrites the store therefore fails its case.

The port is checked with the same wrapper on every lane:

```bash
LANE_WRAP=scripts/ws-run.sh scripts/lanes.sh goldens/cases.tsv goldens "$PWD/port/main.bend"
```

On 2026-09-24 the three fast lanes, each run on its own with `scripts/conform.sh` on one build of the working tree, pass 1327 of 1327 cases each (c-1t, c-8t, js). Two of them, `prefix_config_both` (DISC-010) and `delete_hard_cascade_json` (DISC-011), hold one of the values the original draws at random; they pass because this capture's draw fell on the port's value, and another capture can fail them. `scripts/lanes.sh` as a whole has not run on this code (a BLOCKER in `docs/PORT_STATE.md`): its interpreter lane type-checks the whole program on every case and needs the host alone for hours. The gpu lane is `MISSING` (no device).

---

## Design Philosophy

### 1. The Original Is an Oracle, Never a Template

During implementation `br` is *run*, never read. Capture, the reproducibility floor and the incumbent benchmark are the only contacts with it. Implementation reads the spec (`docs/EXISTING_BEADS_RUST_STRUCTURE.md`), whose clauses are numbered `S<n>.<m>` and each cite a captured case. The source is read once, in Phase 1 and pinned at the tag, to write those clauses; where the source and a golden disagree, the golden wins. A gap in the spec is an `OQ-` entry in `docs/OPEN_QUESTIONS.md`, resolved by running the original on a new case and capturing it.

The oracle is the published release binary, not a build of the source tree: `/dp/beads_rust` is 271 commits past the pin and is edited concurrently by other agents, so it is explicitly not the oracle. Spec citations use the tag (`legacy/BEADS_RUST_v0.6.0/`).

### 2. Two Equivalences, Never Conflated

```
original ==(goldens: captured cases, every lane)== spec twins ==(laws: stated domain)== fast twins
```

The left equality is empirical and bounded by the corpus. The right one is a proof in Bend's logic over the law's stated inputs; a closed law covers one value. Neither establishes that a compiler backend is correct, that an effect succeeds, or that runtime intermediates fit `Nat`'s 48-bit representation. Those are stated separately, as are any `@unsafe` definitions, whose count is reported beside every parity or performance claim.

### 3. Goldens Are Captured, Never Typed

`scripts/golden-capture.sh` writes every golden and records sha256 digests, the exact original argv and its resolved identity in `goldens/MANIFEST.txt`. A re-capture needs `--repin "<reason>"` or `--disc DISC-nnn` and keeps the previous files. Fixtures follow the same rule: `scripts/make-fixture.sh` produces them by running a scenario through the original and refuses to overwrite an existing one.

### 4. Bug-Compatible by Default

The port reproduces the original's behavior, oddities included. A deliberate divergence exists only as a `DISC-` entry in `docs/DISCREPANCIES.md` with a class, a kill-switch, the affected cases, a measured impact and an approver who did not implement it. No silent fixes. See [Known Discrepancies](#known-discrepancies).

### 5. Every Lane, Identical Bytes

A lane is an executor: the interpreter (`bend file.bend`), the native binary at 1 thread and at N threads (`bend file.bend -o out`, run with `--threads N`), and the JavaScript build under bun (`bend file.bend -o out.js`). A difference between lanes is a bug, never a tolerance. A lane that cannot run is reported `MISSING` with its reason: this host has no CUDA device, so the gpu lane is `MISSING`.

### 6. Pure Core, Thin IO Shell

The intended structure, stated in `port/main.bend`'s header, is a pure core that laws can talk about and an IO shell (arguments, files, stdout, exit codes) that only calls the core and is golden-tested. PLAN §7 already places the byte-exact JSON encoder and the total decoder in the core, and DISC-001 keeps the clock out of it: the instant enters through the shell as one environment read. Under `bend 2.0.20` a program that reaches a foreign def gets the verdict `All terms check, but N defs rely on unsafe or foreign code:`, so the core and the shell live in separate files and `PROOF.bend` imports only the core (PLAN §8). Phase 2 fixes the full split in `docs/PROPOSED_ARCHITECTURE.md`, with every spec clause given a home and an evidence kind.

### 7. Claims Are Tagged or Deleted

"Proved" means a law. "Golden-tested" means the harness on named lanes. "Measured" means an interleaved capture with a coefficient-of-variation gate and equal stdout checksums. Nothing else is a claim, and `scripts/claims-lint.sh` scans the claim-bearing documents, this README included, for hedges and deferrals. A parity claim in this project takes one fixed shape:

```
Parity: <FULL | DEBT (n exclusions: …) | PARTIAL>   commit <sha>   <date>   bend <version>
Golden-tested: <n>/<n> cases on interpreter, c-1t, c-<N>t, js[, gpu | gpu MISSING: <reason>]   MANIFEST <sha16>
Proved: <laws> — <verdict line verbatim> (unsafe <k> = <a> @unsafe + <b> template instances)   bend <version>
Discrepancies: <none | DISC-… (class)>   Open: <OQ-…>
Rounds: <r> (<c> clean, <a> non-author) — converge.sh: <CONVERGED for T<t> | NOT_CONVERGED: …>
```

No such claim exists for this project today. Phase 4 produces the first one. The best reachable verdict is `DEBT`, never `FULL`, because the SQLite rows are infeasible by class.

### The Words

| Word | Meaning |
|------|---------|
| **spec twin** | The literal, sequential def for a group of spec clauses |
| **fast twin** | A second def with the same signature, bound to its spec twin by a `{fast == spec}` law (Phase 5) |
| **golden** | A captured original output: `.out`, `.err`, `.exit` |
| **lane** | An executor: interpreter, c-1t, c-Nt, js, gpu |
| **board** | `docs/FEATURE_PARITY.md`: present / partial / missing / excluded. Partial never rounds up; excluded is debt |
| **DISC** | A discrepancy record: OPEN until repaired (RESOLVED) or approved (ACCEPTED) |
| **OQ** | A spec gap, resolved by running the original on a new case |
| **floor** | The original's own nondeterminism, measured by running it against its goldens |
| **incumbent** | The pinned, strongly built original at thread parity, the only valid performance comparison |

---

## Comparison vs Alternatives

### `br` vs `br --no-db` vs this port

| Aspect | `br` (default mode) | `br --no-db` (the contract) | This port |
|--------|---------------------|-----------------------------|-----------|
| Exists today | **Yes** (`br 0.6.0`) | **Yes** (same binary) | **Buildable, not released** (`bend port/main.bend -o bn`) |
| Primary store | SQLite `beads.db`, mirrored to JSONL | `issues.jsonl` only | `issues.jsonl` only |
| Sync, doctor, history, schema migration | Yes | Database tooling; outside the contract | Excluded (no SQLite binding in Bend) |
| Cross-process write locks | Yes | Yes (lock sidecars observed) | Excluded: single-writer (DISC-002) |
| Atomic JSONL publication | Temp file, fsync, rename, history backup | Same | Excluded: written in place (DISC-003) |
| Output modes | Rich, Plain, JSON, TOON, Quiet | Same | Plain, JSON, Quiet |
| Reads git history | Reporting commands only | Same | Excluded (no subprocess effect in Bend) |
| Evidence of behavior | Its own test suites | 1327 captured cases in this repository | 1327 of those 1327 cases on three lanes (c-1t, c-8t, js; two of them only while the original's random draws), plus 68 closed laws |

**When to use `br`:** always, today. It is the working tool.

**When to look at this repository:** you want to follow or audit a port done under the two-equivalences method, or you are an agent working on it.

---

## Building from Source

There is no released binary; `bend port/main.bend -o bn` builds one locally. What can be set up today is the toolchain the evidence was captured with, and the gates that already run.

### Prerequisites (the pins)

| Tool | Pinned value | Notes |
|------|--------------|-------|
| `bend` | `2.0.20`, via the official installer `https://bend-lang.com/install.sh`, installed at `~/.bend/bin/bend` | Download the installer, read it, check its sha256 against PLAN §2b, then run it |
| `bun` | `1.4.2` | The JS lane and Bend's interpreter engine |
| `clang` | `21.1.8` | The native lanes (Bend needs clang 14 or newer) |
| `bwrap` (bubblewrap) | `0.11.1` on the capture host | The sandbox; without it every case exits 125 |
| `python3` | 3.11 or newer | The harness (`tomllib`) |
| `br` | `0.6.0`, the published x86_64 GNU release binary, sha256 `21b967c1…ddbc0` | The oracle. A different build is a different pin |
| libfaketime | `0.9.10`, under `toolchain/faketime/` | Pins the original's wall clock; `toolchain/` is gitignored |

```bash
bend version            # bend 2.0.20   (2.0.17 replaced `bend --version` with `bend version`)
bun --version           # 1.4.2
clang --version
bwrap --version
br --version            # br 0.6.0
sha256sum "$(command -v br)"
```

The harness scripts were written against `bend --version`. `scripts/bend-cli.sh` translates that one spelling and passes everything else through:

```bash
export BEND_CLI="$PWD/scripts/bend-cli.sh"
```

### Gates that exist today

Results are the gate lines of 2026-09-24; `docs/PORT_STATE.md` holds the pasted copies.

| Gate | Command | Last result |
|------|---------|-------------|
| Case table syntax | `scripts/cases-lint.sh goldens/cases.tsv` | `{"cases": 1327, "errors": 0, "notes": 16, "classes_missing": "", "verdict": "OK"}` |
| One case through the original | `scripts/ws-run.sh --oracle br --no-db :: [@fx=<fixture>] <br args…>` | The original's bytes in the sandbox |
| Capture | `scripts/golden-capture.sh goldens/cases.tsv goldens --timeout 60 -- scripts/ws-run.sh --oracle br --no-db ::` | A re-capture needs `--repin` or `--disc`; the last `--repin` (a sandbox fix) changed 0 of 705 golden hash lines |
| Floor | `scripts/floor.sh goldens/cases.tsv goldens --repeat 3 --timeout 60 -- scripts/ws-run.sh --oracle br --no-db ::` | `STABLE`, 384 of 384 (2026-09-20); `STABLE`, 30 of 30 over the cases added 2026-09-21; each later batch floored before its commit, `delete_hard_cascade_json` unstable (DISC-011); the 16 cases of 2026-09-24: `{"repeat":3,"stable":16,"unstable":[],"inconclusive":[],"oracle_identity_checked":true,"verdict":"STABLE"}` |
| Laws | `(cd port && $BEND_CLI PROOF.bend)` | `All terms check.` (0 `@unsafe`; 68 closed laws; `bend 2.0.20`) |
| Lanes | `LANE_WRAP=$PWD/scripts/ws-run.sh scripts/lanes.sh goldens/cases.tsv goldens "$PWD/port/main.bend" --threads 8 --timeout 60 --interpreter-timeout 600` | BLOCKER: `lanes.sh` as a whole has not run on this code. c-1t, c-8t and js, run lane by lane with `scripts/conform.sh` on one build each of the working tree, pass 1327 of 1327 each; `prefix_config_both` (DISC-010) and `delete_hard_cascade_json` (DISC-011) among them only because this capture's random draws fell on the port's values. The interpreter lane has not run on the current code (it needs the host alone for hours); gpu `MISSING` (no device) |
| Parity board | `scripts/parity-board.sh docs/FEATURE_PARITY.md` | `{"rows": 42, "present": 9, "partial": 20, "missing": 0, "excluded": 13, "na": 0, "no_evidence": 0, "verdict": "PARTIAL"}` |
| Convergence | `scripts/converge.sh docs/PORT_STATE.md` | `NOT_CONVERGED`: rounds 15, clean 6, clean tail 0 (rounds 14 and 15 found six and five behaviors), non-author rounds 10, 12 and 15; 0 open OQ and 4 open DISC (DISC-009, DISC-010, DISC-011, DISC-012) remain, and only the repository owner can accept a DISC |
| Wording | `scripts/claims-lint.sh docs/*.md perf/*.md README.md` | Scans claim-bearing documents for hedges and deferrals |

Not run, because there is nothing to measure yet: `scripts/incumbent-bench.sh` (Phase 5). Each script prints its contract with `--help`.

---

## Quick Start

For a person or an agent picking this repository up.

### 1. Read the Mandate and the State

```bash
cat AGENTS.md            # the two equivalences, the gates, the hard rules
cat docs/PORT_STATE.md   # phase, last gate lines, the next action
```

### 2. Check the Pins, Lint the Cases, Run One Case Against Its Golden

Run the version commands under [Prerequisites](#prerequisites-the-pins) and compare them with PLAN §2 and §2b. A missing tool is a blocker, never a skip.

```bash
scripts/cases-lint.sh goldens/cases.tsv
scripts/ws-run.sh --oracle br --no-db :: @fx=basic show proj-170 --json
diff <(scripts/ws-run.sh --oracle br --no-db :: @fx=basic ready) goldens/ready_plain.out
```

### 3. Add a Case (Never a Golden)

Add a row `name<TAB>["argv", …]` to `goldens/cases.tsv`, lint it, and capture it through `scripts/golden-capture.sh` with `--repin "new case <name>"`. The printed MANIFEST diff must name only the new case. `CONTRIBUTING.md` has the full procedure.

---

## Commands

The surface in scope, from PLAN §3. "Cases" counts the rows of `goldens/cases.tsv` whose argv invokes the command, error and edge cases included, as counted on the 454-case corpus of 2026-09-22; the corpus has since grown to 1327 cases and these columns have not been recounted. Examples are captured argv; ids such as `proj-mta` belong to the `basic` fixture.

### Issue Lifecycle

| Command | Contract (`br --no-db`) | Example (captured) | Cases |
|---------|-------------------------|--------------------|-------|
| `create` | Create an issue; flags for type, priority, labels, assignee, description, deps, parent, status; `--dry-run`; `--silent` prints the id only; `--ephemeral` issues are not written to `issues.jsonl` | `create "First issue" --json` | 24 |
| `q` | Quick capture | `q "Quick urgent" -p 0` | 2 |
| `show` | Show one or more issues; a partial id resolves when it is unambiguous (`show mta`), otherwise `AMBIGUOUS_ID` | `show proj-170 --json` | 18 |
| `update` | Status, priority, title, assignee, notes, labels, `--claim`; several ids at once; with no id, the `last-touched` issue (case `update_last_touched`) | `update proj-mta --claim --json` | 20 |
| `close` | Close; refuses blocked issues and epics with open children unless `--force`; `--suggest-next` | `close proj-mta --reason "Shipped" --json` | 11 |
| `reopen` | Reopen a closed issue | `reopen proj-mkh --reason "Regressed" --json` | 4 |
| `defer` / `undefer` | Defer until a date or a relative time; undo it | `defer proj-mta --until +1h --json` | 4 / 2 |
| `delete` | Tombstone; when other issues depend on the target it previews and changes nothing unless `--force` (orphan them) or `--cascade` (delete them recursively); `--dry-run` | `delete proj-mta --cascade --json` | 8 |

### Querying

| Command | Contract (`br --no-db`) | Example (captured) | Cases |
|---------|-------------------------|--------------------|-------|
| `list` | Filters (status, type, priority range, assignee, labels, title, id), `--sort`, `-r`, `--limit`/`--offset`, `--long`, `--fields`; JSON envelope `{issues,total,limit,offset,has_more}` | `list --limit 2 --offset 1 --json` | 44 |
| `ready` | Open, unblocked, not deferred work; `--sort priority\|oldest`, `--include-deferred`, filters; `--parent <id>` keeps its direct children, `-r`/`--recursive` all its descendants, `--epic <id>` is both | `ready --epic proj-9vo --json` | 28 |
| `blocked` | Issues with open blocking dependencies; `--detailed` lists each blocker's title, priority and status | `blocked --detailed` | 9 |
| `search` | Text search over title and description, case-insensitive, with filters | `search work --status closed` | 9 |
| `count` | Count, optionally grouped (`--by-status`, `--by-priority`, `--by-type`, `--by-assignee`, `--by-label`) | `count --by-priority --json` | 9 |
| `stats` | Project statistics (without the commit-activity part, which runs git) | `stats --json` | 4 |
| `where`, `version` | Active `.beads` directory; version report (the port's own `version` contract is OQ-003) | `where --json` | 2 / 2 |

### Dependencies, Labels, Comments, Epics

| Command | Contract (`br --no-db`) | Example (captured) | Cases |
|---------|-------------------------|--------------------|-------|
| `dep add` / `dep remove` | Typed edges; refuses cycles (exit 5), self-dependency, missing ids, a second parent; duplicate and `external:` edges | `dep add proj-ptp proj-mta -t related` | 12 / 3 |
| `dep list` / `dep tree` / `dep cycles` | Read the graph. `dep tree` walks depth-first in pre-order, orders siblings by priority, status rank, title and id, marks a re-reached node `repeat` and a cut one `truncated`, and takes `--max-depth` (default 10) and `--direction`; `--format mermaid` prints the same walk as a mermaid graph. `dep list --direction up\|both` lists dependents too | `dep tree proj-6ja --format mermaid` | 15 / 31 / 4 |
| `label add/remove/list/list-all/rename` | Label charset and limits | `label rename backend server --json` | 15 in total |
| `comments add` / `comments list` | Comment identity, `--author`, `-m` | `comments add proj-mta "Looks good."` | 9 / 3 |
| `epic status` | Epic rollups | `epic status --json` | 2 |
| `epic close-eligible` | Closes, in one batch, every non-closed epic that has at least one child and whose children are all closed, with the fixed reason `All children completed`; `--dry-run` lists them and writes nothing | `epic close-eligible --dry-run --json` | 7 (two scenarios and a usage refusal among them) |

### Global Flags and Exit Codes in the Corpus

| Flag | Description |
|------|-------------|
| `--no-db` | JSONL-only mode: the whole contract |
| `--json` | JSON output; errors are a pretty-printed `{"error":{…}}` object on stdout |
| `--quiet` | Quiet mode (`list --quiet` prints nothing) |
| `--actor <name>` | Actor recorded on the mutation (`created_by` in case `actor_flag_create`) |

| Exit code | Cases | Examples in the corpus |
|-----------|-------|------------------------|
| 0 | 647 | success, including no-op outcomes such as `dep_add_duplicate` (`Dependency already exists: …`) and the `delete` preview; every multi-step scenario |
| 2 | 104 | argument-parser usage errors; `NOT_INITIALIZED` (no `.beads/`) |
| 3 | 35 | `ISSUE_NOT_FOUND`, `AMBIGUOUS_ID`, `NOTHING_TO_DO` |
| 4 | 87 | `VALIDATION_FAILED`, `INVALID_PRIORITY`, no ids and no last-touched issue |
| 5 | 10 | `CYCLE_DETECTED`, self-dependency |
| 6 | 9 | `SYNC_CONFLICT`: the import's semantic verification refuses a record (`edge_empty_optionals_list`) |
| 7 | 109 | `CONFIG_ERROR`: merge conflict markers or malformed JSON in `issues.jsonl`, and the other configuration refusals |
| 8 | 8 | `IO_ERROR`: a store that is not UTF-8, a file an argv names that is missing (`error_store_not_utf8`, `error_comments_add_file_missing`) |

Outside JSON mode, errors are `Error:` and `Hint:` lines on stderr.

---

## Scope and Exclusions

The contract is **`br --no-db`**: same argv, same stdout, stderr and exit code, same resulting `.beads/issues.jsonl` bytes, in Plain and JSON output modes. The in-scope surface is the [Commands](#commands) section plus workspace discovery, JSONL load / normalize / validate, JSONL write-back (lines by id in ascending byte order; labels, dependencies and comments normalized; ephemeral and `-wisp-` ids excluded), id generation (SHA-256 seed, base36, adaptive length 3–8, nonce ladder, child ids `<parent>.<n>`) and the content hash.

Each exclusion is debt or infeasibility, stated with its class:

| Excluded | Why | Class | Debt? |
|----------|-----|-------|-------|
| The SQLite store: `beads.db`, the default mode, auto-import / auto-flush, dirty tracking, the blocked cache table | The `fsqlite` engine reaches every DB path; Bend has no SQLite binding, and the file format cannot be golden-tested through the shell | external-dependency | no |
| `doctor`, schema migration, `sync --import-only/--rebuild/--merge/--reconcile*`, `history` | They repair and reconcile a SQLite database against JSONL | external-dependency | no |
| `init` creating `beads.db` | Same; the port's `init` writes the JSONL-side files only (a DISC, Phase 4; see OQ-005) | external-dependency | no |
| `serve` (MCP) | Not compiled into the pinned binary (`features: ["self_update"]`): there is no oracle to capture | out-of-scope | yes |
| `upgrade`, `completions`, `agents`, `config edit` | Network self-replacement, shell integration, an `$EDITOR` subprocess | platform | no |
| `changelog`, `orphans`, `vcs-status`, commit activity in `stats` | They run `git` as a subprocess; Bend has no subprocess effect | external-dependency | no |
| Rich (TTY) output | Terminal detection and ANSI tables; a captured run is piped, hence Plain | platform | no |
| TOON output | Reimplementable; not in the first certification | out-of-scope | yes |
| Cross-process write locks, opener leases, the inode lock | `fcntl` byte locks and lock-file queues; Bend has no lock effect (DISC-002) | concurrency-observable | no |
| Temp file + `RENAME_EXCHANGE` publication, fsync, `.br_history/` backups | Bend's file effects are open / read / write / close; no rename, no fsync (DISC-003). A custom effect would repay it | platform | yes |
| `audit`, `capacity`, `gate`, `coordination`, `scheduler`, `query`, `lint`, `stale`, `graph`, `info`, `schema`, `capabilities`, `robot-docs`, `config list/get/set` | Feasible; outside the first certification's surface | out-of-scope | yes |
| Close policy workflows (`strict` transitions, gates, required fields) | Configured per workspace; the default non-strict behavior is in scope | out-of-scope | yes |
| `clap` help and usage texts beyond the captured error shapes | Generated by the argument-parser library; the captured cases pin what is reproduced | external-dependency | yes |

---

## Configuration

### What the contract reads

Workspace discovery walks up from the working directory for `.beads/`, and `BEADS_DIR` overrides it. The id prefix comes from the directory name or from `.beads/config.yaml`. The spec (Phase 1) owns the full list of environment variables the JSONL-only path honors (clause S1.5); this README does not restate what is not yet written there.

### The pinned environment of every case

`scripts/ws-run.sh` runs each case under `bwrap` with a read-only root (`/tmp` and `TMPDIR` stay writable), a fresh tmpfs at `/mnt` (the workspace is `/mnt/proj` and vanishes with the process), and a cleared environment:

```
PATH=<inherited>  HOME=/mnt/home  USER=tester  TZ=UTC  NO_COLOR=1  RUST_LOG=error  BEND_NO_TELEMETRY=1
clock, original:  libfaketime preloaded, FAKETIME=<instant>, DONT_FAKE_MONOTONIC=1
clock, port:      BEADS_BEND_NOW=<epoch seconds>   (the DISC-001 seam, set from the case's @time)
```

Case pseudo-arguments: `@fx=<name>` selects `goldens/fixtures/<name>.jsonl` (`none` means no `.beads/` at all), `@time=<YYYY-MM-DD hh:mm:ss>` sets the instant, `@scn=<name>` runs a multi-step scenario from `goldens/scenarios/`.

### Harness knobs

| Variable / file | Purpose |
|-----------------|---------|
| `BEND_CLI` | The Bend command the scripts call; point it at `scripts/bend-cli.sh` |
| `BEND_BIN` | The `bend` binary behind that wrapper (default `~/.bend/bin/bend`) |
| `LANE_WRAP` | The per-case wrapper for `scripts/lanes.sh`; here `scripts/ws-run.sh` |
| `port.env` | Knobs read by `scripts/port.sh`; still holds the scaffold's placeholder values |
| `docs/PIN.toml` | The pins as data for `scripts/pin-check.sh`; still holds the scaffold's placeholders, PLAN §2 and §2b are the filled copy |

---

## Architecture

```
┌──────────────────────────────────────────────────────────────────────┐
│  br 0.6.0 release binary (pinned)                                    │
│  run only, inside scripts/ws-run.sh: bwrap, tmpfs, pinned instant    │
└──────────────────────────────────────────────────────────────────────┘
                 │  scripts/golden-capture.sh
                 ▼
┌──────────────────────────────────────────────────────────────────────┐
│  goldens/   1327 cases: <case>.out .err .exit, MANIFEST.txt          │
└──────────────────────────────────────────────────────────────────────┘
                 │  original == spec        GOLDEN-TESTED, every lane
                 ▼
┌──────────────────────────────────────────────────────────────────────┐
│  spec twins: port/main.bend, pure core                      Phase 3  │
│  written from the spec, clauses S1–S12                               │
└──────────────────────────────────────────────────────────────────────┘
                 │  spec == fast            LAW-PROVED
                 │  port/LAWS.bend + port/PROOF.bend → "All terms check."
                 ▼
┌──────────────────────────────────────────────────────────────────────┐
│  fast twins: id hashing, sorting, blocked-set propagation,           │
│  JSON encoding                                              Phase 5  │
└──────────────────────────────────────────────────────────────────────┘
```

### Data Flow of One Invocation

The steps are the contract; the core/shell labels are the intended split, which Phase 2 fixes.

```
argv, env          ──►  shell: find .beads/, read issues.jsonl
issues.jsonl bytes ──►  core: decode, validate (conflict markers and bad JSON refuse, exit 7)
command            ──►  core: filter / sort / graph query / mutate
result             ──►  core: render Plain | JSON | Quiet
rendered bytes     ──►  shell: stdout, stderr, exit code
mutation only      ──►  core: normalize, order lines by id, encode
                   ──►  shell: write issues.jsonl and last-touched
```

A mutation rewrites every record, not only the touched one (OQ-002, resolved from `goldens/edge_precision_rewrite.out`): unknown fields are dropped, labels come back sorted and deduplicated, timestamps are re-rendered in canonical form.

### Repository Layout

```
beads_bend/
├── AGENTS.md, CONTRIBUTING.md, port.env
├── docs/
│   ├── PLAN_TO_PORT_BEADS_RUST_TO_BEND2.md   # purpose, pins, scope, exclusions, risks
│   ├── PORT_STATE.md                         # phase, pasted gate lines, next action
│   ├── EXISTING_BEADS_RUST_STRUCTURE.md      # the spec (Phase 1); spec-parts/ holds the extractor brief
│   ├── OPEN_QUESTIONS.md, DISCREPANCIES.md   # the OQ and DISC registers
│   ├── FEATURE_PARITY.md                     # the board (Phase 4)
│   └── PROPOSED_ARCHITECTURE.md, NUMERIC_PLAN.md, PIN.toml, PORT_REPORT.md, PARITY_RUNBOOK.md
├── goldens/    # cases.tsv, MANIFEST.txt, <case>.out/.err/.exit, fixtures/, scenarios/
├── port/       # main.bend, LAWS.bend (human-owned), PROOF.bend, probes/
├── perf/       # experiment cards, the ledger, negative evidence
├── scripts/    # the harness (copied from the porting method; see scripts/ORIGIN.md)
├── legacy/     # gitignored: the original, to run and to cite by tag
└── toolchain/  # gitignored: retained Bend release, source, libfaketime
```

---

## Known Discrepancies

The register is `docs/DISCREPANCIES.md`. Twelve entries: seven `ACCEPTED` by the repository owner on 2026-09-20, and DISC-008 `RESOLVED` (a port bug, found by probe and repaired the same day) under the delegation quoted in each one; the owner can revoke any of them, which returns it to `OPEN`. DISC-009 to DISC-012 are `OPEN` (below the table), and until a DISC is accepted it counts as a bug. The impact figures are the register's own, measured on the corpus of the date each was written.

| Id | Class | Original | Port | Kill-switch | Measured impact |
|----|-------|----------|------|-------------|-----------------|
| DISC-001 | Nondeterminism | Timestamps and ids derive from the wall clock; `br` has no override | Identical bytes when `BEADS_BEND_NOW=<epoch seconds>` is set; unset, a mutation is stamped with the wall clock read through the custom effect `Clock.wall` (its per-engine precision is DISC-009, below the table). One environment read in the shell; the core never sees a clock | Unset the variable (the default) | 0 of 231 goldens differ because of it; without it no mutating case is reproducible |
| DISC-002 | Excluded | Takes three lock files and refuses to export when the on-disk JSONL changed since load | No lock files. Two concurrent port writers can lose an update | None inside Bend; serialize writers outside the tool. Repayment: a custom lock effect | 0 of 231; the exposure is concurrent agents on one workspace, which the corpus does not exercise |
| DISC-003 | Platform | Stages a temp file, fsyncs, publishes by rename, keeps a history backup | Same final bytes, written in place. A kill during the write can leave a truncated store; no backup exists | None inside Bend. Repayment: a custom `file_rename` effect | 0 of 231; crash windows are not observable in the harness |
| DISC-004 | Excluded | Leaves lock files and `.br_history/` in `.beads/` | Writes `issues.jsonl` and `last-touched` only | None | 0 of 231 |
| DISC-005 | OrderLeak | The candidate list of an ambiguous partial id is hash-random per process (six runs printed four orders) | Candidates in ascending byte order of the id, in the message and in `context.matches` | None is meaningful: there is no single original order | 1 of 231 unstable before the canonicalizer in `scripts/ws_inner.py`; byte-identical repeated runs after it. The exit code is never canonicalized |
| DISC-006 | Platform | `br version` reports its Rust toolchain, target triple and git branch (`br version 0.6.0 (release) (v0.6.0@b1cfebe)`) | `bn version 0.1.0 (bend 2.0.20) (port of br 0.6.0@b1cfebe)`, and a JSON report with the same facts; the three cases are compared through a shape canonicalizer applied to both sides | None: there is no truthful way to print another program's build metadata | 3 of 384 cases are compared by shape rather than byte for byte |
| DISC-007 | BugFix | `br --no-db --no-db list` is refused (a once-only option twice) | An explicit top-level `--no-db` is accepted, so a script that calls `br --no-db list` keeps working when the port stands in | None | 0 of 384 (the register's figure; the corpus is now 1009 cases) |
| DISC-008 | Platform | `br --no-db count` answers on a store of any size (its own is 4.5 MB) | Was: the JS lane faulted above about 30 KB of store. **RESOLVED** the same day — the cause was the port's own shell joining its read chunks with `List.concat`, which the emitted JavaScript walks one stack frame per element; the shell now answers a single chunk as it is and reads 64 MiB at a time, and the JS lane carries 5,000 records | not applicable (repaired, not diverged) | 0 of 384 cases (the register's figure); the repair is locked in by fixture `large` and the three `edge_large_*` cases. A second JS fault, on a text member of 64 KB or more, was repaired in the load path on 2026-09-24 (bead `bb-rvt`) |

Four entries are `OPEN`, each waiting for the repository owner to accept it, reject it, or choose a canonicalizing wrapper:

- **DISC-009 (Platform), the wall clock's precision.** Bend 2.0.20 has no wall clock: `IO.now` is a monotonic millisecond ticker (OQ-004). The real clock is therefore a custom effect, `Clock.wall`, probed in `port/probes/clock/` and now wired into the shell: it loads on the interpreter, the C lane and the JS lane, with nanoseconds on C and milliseconds on the other two (OQ-009), and a run reads it once. An unpinned timestamp therefore prints 9 fraction digits on one lane and 3 on the others. Pinned runs, and so every golden, are unaffected.
- **DISC-010 (Nondeterminism).** With both `issue_prefix` and `prefix` configured, the original picks one at random; the capture of `prefix_config_both` holds one draw, and the port passes or fails that case with it.
- **DISC-011 (Nondeterminism).** `events_removed` of `delete --cascade --hard --json` varies between runs of the original; the case `delete_hard_cascade_json` is the one unstable case of the floor.
- **DISC-012 (Nondeterminism).** When the import refuses several records, the original names one of them at random; found by the real-store sweep of 2026-09-24.

### Open Questions

`docs/OPEN_QUESTIONS.md` holds the spec gaps. Resolved by running the original or the pinned runtime: OQ-001 (ordering over mixed-precision timestamps is chronological, id ascending breaks ties), OQ-002 (a mutation rewrites and normalizes every record), OQ-004 and OQ-009 (the clock, above). Resolved since: OQ-003 (the port's own `version` contract is DISC-006, and the three cases pass), and most of the register after it, each by a captured case; the newest are OQ-131 to OQ-136 (the real-store sweep, round 12, the markdown import, stored dependency metadata). As of 2026-09-25 `scripts/converge.sh` lists none open: the last twelve were resolved by running the original (OQ-012, OQ-023, OQ-042, OQ-074, OQ-081, OQ-106, OQ-129), by a second extraction pass over the pinned source (OQ-089, OQ-100, now evidence in DISC-009), or excluded with a class (OQ-005 `init`, OQ-091 a closed pipe); OQ-004's row was only misformatted. Every OQ is resolved or excluded before the parity gate converges.

---

## Troubleshooting

### `ws-run: bwrap (bubblewrap) is required` (exit 125)

**Cause:** the sandbox cannot start. Exit 125 is a sandbox or usage failure and is treated as INCONCLUSIVE by the harness, never as a case result. Install bubblewrap.

### `bend: unknown option --version (see bend --help)`

**Cause:** Bend 2.0.17 replaced `bend --version` with `bend version`, and the harness still asks the old spelling.

```bash
export BEND_CLI="$PWD/scripts/bend-cli.sh"
```

The wrapper itself exits 127 with `bend-cli: no bend at …` when `~/.bend/bin/bend` is absent: install the pinned release per PLAN §2b, or set `BEND_BIN`.

### The original hangs inside the sandbox

**Cause:** a fully frozen clock (monotonic time faked too) hangs `br`. The sandbox sets `DONT_FAKE_MONOTONIC=1` for that reason, and `scripts/ws_inner.py` bounds each step at 120 seconds. If you preload libfaketime by hand, set the same variable.

### `error: … exists; fixtures are never overwritten`, or `br --version` is not `br 0.6.0`

**Cause:** both protect the pin. Goldens depend on fixture bytes, so a changed fixture is a new name followed by a re-capture with `--repin`. A `br` whose version or sha256 differs from PLAN §2 is not the oracle, and captures taken with it are a different pin. The live source tree at `/dp/beads_rust` is 271 commits past the pin and is not the oracle either.

### A case fails once an implementation exists

```bash
scripts/first-divergence.sh <case> goldens/cases.tsv goldens -- <port command>
```

It names the divergence class (EXIT, MESSAGE, ORDER, NUMERIC, FORMAT, …) and the spec section to read. A failing case is a port bug or a spec gap, never a tolerance, and never a reason to re-capture.

---

## Limitations

These hold by design or by what Bend 2.0.20 offers, and they apply to the port once it exists. The full list of what is left out, with classes, is [Scope and Exclusions](#scope-and-exclusions).

| Limitation | Reason |
|------------|--------|
| **Single-writer** | No lock effect in Bend (DISC-002). Two concurrent writers on one workspace can lose an update. `br` remains the right tool for a swarm sharing a workspace |
| **Non-atomic write-back** | No rename or fsync effect (DISC-003). A kill during the write can truncate `issues.jsonl`; keep the file under version control |
| **No `beads.db`** | No SQLite binding. Everything that exists to manage the database (sync modes, doctor, history, migration) is excluded |
| **Unpinned timestamps differ by engine** | Bend 2.0.20 has no wall clock of its own; a mutation without `BEADS_BEND_NOW` reads the custom effect `Clock.wall`, which is nanosecond on C and millisecond on the interpreter and JS (OQ-009, DISC-009, `OPEN`), so an unpinned timestamp prints 9 fraction digits on C and 3 elsewhere. Its C side uses runtime internals with no ABI promise, so it is rebuilt and re-probed on every Bend pin move (PLAN §8) |
| **Conformance is bounded by the corpus** | 1327 cases is what "golden-tested" means here; behavior outside them is unclaimed, and the forms the port refuses with its own failure are listed in `docs/OPEN_QUESTIONS.md` |
| **No gpu lane on this host** | No CUDA device; the lane is recorded `MISSING` with that reason |

---

## FAQ

### Q: Can I use this instead of `br` today?

No. You can build it (`bend port/main.bend -o bn`) and it reproduces the original on the 1327 captured cases (two of them only while the original's random draw matches), but that is a corpus, not a certification: the parity gate has not converged (no open OQ, but four `OPEN` DISCs), the interpreter lane has not run on the current code, the performance phase and the report have not run, the exclusions below are real (no `beads.db`, no locks, no atomic write-back), and several uncaptured forms answer the port's own "not ported" failure instead of guessing. Use [`br`](https://github.com/Dicklesworthstone/beads_rust).

### Q: How does its speed compare with `br`?

Nothing has been measured, so nothing is claimed. `perf/EXPERIMENTS.md` records exploratory timings of the port against itself (single runs, other jobs on the host, no cv gate), which are not measurements. Phase 5 produces the measured comparison, and only under the incumbent contract: the pinned release binary, thread parity, interleaved runs, medians, cv ≤ 5% or the capture is refused and recorded as `NO_EVIDENCE`. PLAN §5 says it directly: no ratio is promised before it is measured.

### Q: Will `bv` and my other beads tooling work with it?

The contract is that the port writes the same `.beads/issues.jsonl` bytes as `br --no-db` for the same inputs, which is what those tools read. Interoperation with `bv` itself is not exercised by this corpus, so it is not claimed.

### Q: If goldens are empirical, what do the proofs buy?

They split the risk. Goldens say the *simple* code matches the original on the captured cases (1327 of 1327 today, two of them by the luck of a random draw). Laws say the *optimized* code equals the simple code for every input in the law's domain. So an optimization cannot introduce a behavior the goldens miss, and the goldens only ever have to vouch for code that is literal enough to review. The proofs do not cover compiler backends, effects, or the corpus's blind spots, and this README does not say they do.

### Q: Where is data stored?

In the contract, under `.beads/`:

```
.beads/
├── issues.jsonl    # the whole store in --no-db mode: one issue per line, ordered by id
├── last-touched    # the id used when update/close/show get no id
└── config.yaml     # optional; can set the id prefix
```

The original also leaves lock files and `.br_history/` there; the port does not (DISC-004).

---

## AI Agent Integration

This port is worked on mostly by AI coding agents. [AGENTS.md](AGENTS.md) is their mandate: the two equivalences, the gate commands, and the hard rules (goldens are never edited, `port/LAWS.bend` is human-owned, no file is ever deleted, `docs/PORT_STATE.md` is rewritten at the end of every session with pasted gate lines and one executable next action). `CONTRIBUTING.md` documents the same rules (adding a case, proposing a law, filing a DISC) for whoever changes the repository.

---

## What This Port Fed Back into the Method

The method is the `porting-to-bend2` skill; `scripts/` holds copies of its harness taken on 2026-09-20 (`scripts/ORIGIN.md`), plus this port's own sandbox. On 2026-09-22 what this port learned went back into the skill, alongside what the `toon_bend` port learned:

| Lesson from this port | What the skill now carries |
|------------------------|----------------------------|
| `br` is stateful and stamps the wall clock | a stateful-original guide and a sandbox template built from `scripts/ws-run.sh`, `scripts/ws_inner.py` and `scripts/make-fixture.sh` |
| Base has no exit-without-message, cwd, remove or wall clock | a custom-effects guide with the C and JS twins of `Sys.exit`, `Sys.cwd`, `Sys.remove` and the probed `Clock.wall` |
| Bend 2.0.17 renamed `--version`; 2.0.17+ print the checker's verdict as a header plus one `- <def>` line per def | a `bend-version.sh` wrapper, and every verdict parser reads the last line that is not a `- <def>` line |
| a proof book that imports the shell reaches foreign code and checks 5–9× slower | the scaffold puts the twins in `port/core/`, and the proof book imports only the core |
| the interpreter lane costs about 14.5 hours for this corpus, and C builds get OOM-killed | `lanes.sh --lanes` and `--interpreter-sample` (verdict `PARTIAL`, never `PASS`), and a build failure reported from its exit status |

Later the same day all five of this port's sessions were mined again into the skill's fourth pass of session lessons (P48–P80). The two with the most weight here: closing a form the port refused ("not ported yet") is Phase 3 work, never a find-fix round, so the rounds table above counts seven rounds and not ten; and every such closure was captured from the original first and passed on its first lane run (22/22, 9/9, 5/5, 16/16). The skill's `lanes.sh` now runs the interpreter lane last.

The copies here predate those changes and have not been re-copied: `scripts/lanes.sh` carries this port's `LANE_WRAP` block, and every gate line in `docs/PORT_STATE.md` was produced by these copies, so a re-copy is its own change with its gates re-run.

## About Contributions

Please don't take this the wrong way, but I do not accept outside contributions for any of my projects. I simply don't have the mental bandwidth to review anything, and it's my name on the thing, so I'm responsible for any problems it causes; thus, the risk-reward is highly asymmetric from my perspective. I'd also have to worry about other "stakeholders," which seems unwise for tools I mostly make for myself for free. Feel free to submit issues, and even PRs if you want to illustrate a proposed fix, but know I won't merge them directly. Instead, I'll have Claude or Codex review submissions via `gh` and independently decide whether and how to address them. Bug reports in particular are welcome. Sorry if this offends, but I want to avoid wasted time and hurt feelings. I understand this isn't in sync with the prevailing open-source ethos that seeks community contributions, but it's the only way I can move at this velocity and keep my sanity.

---

## License

MIT with an OpenAI/Anthropic rider: see [`LICENSE`](LICENSE). It is the same license text as `br` (beads_rust), the project this one ports.

---

<div align="center">
  <sub>Oracle: br 0.6.0. Target: Bend 2.0.20. Evidence: captured goldens and checked laws.</sub>
</div>
