# beads_bend - Beads in Bend 2

<div align="center">

[![Status](https://img.shields.io/badge/status-Phase%203%20early%3A%207%20of%20235%20cases%20pass-red.svg)](#status)
[![Bend](https://img.shields.io/badge/bend-2.0.20%20%28pinned%29-blue.svg)](docs/PLAN_TO_PORT_BEADS_RUST_TO_BEND2.md)
[![Oracle](https://img.shields.io/badge/oracle-br%200.6.0%20%28pinned%29-orange.svg)](docs/PLAN_TO_PORT_BEADS_RUST_TO_BEND2.md)

</div>

A port of [`br` (beads_rust)](https://github.com/Dicklesworthstone/beads_rust), my Rust port of Steve Yegge's [beads](https://github.com/steveyegge/beads), to the [Bend 2](https://bend-lang.com) programming language. The contract being ported is `br --no-db`: the JSONL-only mode of the frozen "classic beads" architecture.

[Status](#status) | [TL;DR](#tldr) | [Commands](#commands) | [Scope and Exclusions](#scope-and-exclusions) | [Known Discrepancies](#known-discrepancies) | [Limitations](#limitations) | [FAQ](#faq)

<div align="center">
<h3>There is nothing to install</h3>

<p><em>No usable Bend implementation exists in this repository: an early core and shell pass 7 of the 235 conformance cases, and no command works yet. No binary, no install script, no release, no benchmark. What exists is the evidence base a port is judged against, and the first proved pieces of the port. Read <a href="#status">Status</a> before anything else.</em></p>
</div>

---

## Status

As of 2026-09-20 this project is early in Phase 3 of an eight-phase port method (fit screen, truth pack, spec, architecture, reference port, parity gate, performance, certify). The fit screen, the truth pack, a first pass of the spec and the architecture are done; the reference port has its first modules and its first passing cases; nothing after it has started. I would rather publish an honest, nearly empty shell than a README that describes software that does not exist.

| Artifact | State | Where |
|----------|-------|-------|
| The original, pinned | `br 0.6.0`, tag `v0.6.0`, commit `b1cfebe05437463e91a353cf2bedafac27266f5b`; the published release binary, 27,772,512 bytes, sha256 `21b967c1ae68df1a2e8eb2256d13b8e57d293d89e331933919076104832ddbc0` | [PLAN §2](docs/PLAN_TO_PORT_BEADS_RUST_TO_BEND2.md) |
| Bend, pinned | `bend 2.0.20` from the official installer; binary sha256 `fab9e564c578a0a15880d5fea561ac1612dba01265a5a219906b5888f3381d8c`; bun `1.4.2`; clang `21.1.8` | [PLAN §2b](docs/PLAN_TO_PORT_BEADS_RUST_TO_BEND2.md) |
| Hermetic oracle sandbox | exists: `scripts/ws-run.sh` and `scripts/ws_inner.py` (bubblewrap, tmpfs workspace, cleared environment, pinned instant) | `scripts/ws-run.sh --help` |
| Conformance cases | 235 cases in `goldens/cases.tsv`; `scripts/cases-lint.sh` verdict `OK` (0 errors, 0 notes) | `goldens/` |
| Goldens | 235 captured `.out` / `.err` / `.exit` triples from the pinned original; digests in `goldens/MANIFEST.txt` (sha256 `ae5b18770a62af73…`); 61 of them carry a dump of the resulting `.beads/issues.jsonl` | `goldens/` |
| Reproducibility floor | `{"repeat":3,"stable":235,"unstable":[],"inconclusive":[],"oracle_identity_checked":true,"verdict":"STABLE"}`, after the one hash-random output of the original was canonicalized (DISC-005) | `docs/PORT_STATE.md` |
| Fixtures and scenarios | 6 fixtures (`basic`, `basic_touched`, `conflict`, `empty`, `malformed`, `precision`) and 5 multi-step scenarios; the realistic fixtures are the original's own output | `goldens/fixtures/`, `goldens/scenarios/` |
| Spec (Phase 1) | **first pass done**: 874 numbered clauses with `file:line` provenance and a golden case each, merged from eight part files by `scripts/merge-spec-parts.py`; `scripts/spec-lint.py` reports 0 findings; a blind self-containment review predicted 10 of 10 sampled cases byte for byte from the spec alone (`docs/reviews/self-containment-1/`) and still found six clause contradictions, now open questions. The method's second and third extraction passes and the capture of the extractors' proposed cases have not run | `docs/EXISTING_BEADS_RUST_STRUCTURE.md`, `docs/spec-parts/`, `docs/OPEN_QUESTIONS.md` |
| Architecture, numeric plan (Phase 2) | written: one pure function `run : Inputs -> Outcome` and a thin IO shell; every one of the 739 behavior clauses has a home def (`scripts/arch-lint.py`: PASS); no `F32` anywhere and no budgeted output class | `docs/PROPOSED_ARCHITECTURE.md`, `docs/NUMERIC_PLAN.md` |
| Bend implementation (Phase 3) | **early, and not usable**: ten core modules under `port/core/` (UTF-8, SHA-256, the id hash, instants, the JSON line lexer and member splitter, the 44-member record and its store line, the line decoder, store loading, error rendering, the dispatcher) and the IO shell `port/main.bend` with two custom effects (`Sys.exit`, `Sys.cwd`). There is **no argument parser and no command**: what runs end to end is the refusal with no workspace and the two store-load refusals (conflict markers, a malformed line). **7 of 235 conformance cases pass**; every real command answers the port's own "not ported yet" failure, so nothing passes by accident | `port/`, `docs/PORT_STATE.md` |
| Laws and proofs | 27 closed laws, all proved by the checker computing both sides: SHA-256 against three published vectors, seven captured ids from their seeds (including `q`'s empty-creator seed and the nonce ladder), fifteen timestamp facts (the five spellings of fixture `precision` as the original wrote them back, calendar borrows and carries, refusals), and the exact store line of `create_min`. `bend port/PROOF.bend` prints `All terms check.` with 0 `@unsafe` under `bend 2.0.20`. A closed law covers one value; none of these is a quantified property | `port/LAWS.bend`, `port/PROOF.bend` |
| Feasibility probes | a wall-clock custom effect (OQ-009: it loads on the interpreter, C and JS engines; Bend 2.0.20 itself has no wall clock, OQ-004) and a SHA-256 over `U32` words whose four digests equal `hashlib`'s on all three engines (PLAN §8). Probes are not the port | `port/probes/` |
| Parity board (Phase 4) | skeleton: 29 in-scope rows (2 `partial`, 27 `missing`) and 13 classed exclusions; `scripts/parity-board.sh` reports `PARTIAL`. No find-fix round has run | `docs/FEATURE_PARITY.md` |
| Performance (Phase 5) | no measurement of any kind; `perf/EXPERIMENTS.md` is empty | `perf/` |
| Port report (Phase 6) | template | `docs/PORT_REPORT.md` |
| Binary, installer, release, license file, git remote | none | |

`docs/PORT_STATE.md` is the live copy of this table: it is rewritten at the end of every working session with the gate lines pasted verbatim, and it wins over this README when the two differ.

**Everything below that describes issue-tracker behavior describes the contract**: what `br --no-db` does, captured byte for byte, which the port must reproduce. None of it is something the port already does.

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
| **original == spec** | **Golden-tested.** The pinned original's stdout, stderr and exit code are captured per case; the port must produce the same bytes on every lane (interpreter, C at 1 thread, C at N threads, JS). Empirical, and bounded by the corpus | `goldens/cases.tsv`, `goldens/MANIFEST.txt`, `scripts/lanes.sh` | 235 cases captured, floor `STABLE`; no port to compare |
| **spec == fast** | **Law-proved.** Every optimized def (a *fast twin*) has the same signature as its literal, sequential *spec twin*, and a law `{fast(x) == spec(x)}` that `bend port/PROOF.bend` must check, ending in `All terms check.` | `port/LAWS.bend`, `port/PROOF.bend` | one scaffold law over a placeholder |

Nothing compares the original with a fast twin except the shipped binary on the goldens. What runs today is the left-hand side only: the pinned original, inside the hermetic sandbox, against its own captured goldens.

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

Run against the scaffold placeholder on 2026-09-20 it reported `FAIL`, with 1 of 235 cases passing on each of the four lanes. The harness works; there is no implementation for it to pass. Phase 3 produces one.

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
| Exists today | **Yes** (`br 0.6.0`) | **Yes** (same binary) | **No** (Phase 3 produces it) |
| Primary store | SQLite `beads.db`, mirrored to JSONL | `issues.jsonl` only | `issues.jsonl` only |
| Sync, doctor, history, schema migration | Yes | Database tooling; outside the contract | Excluded (no SQLite binding in Bend) |
| Cross-process write locks | Yes | Yes (lock sidecars observed) | Excluded: single-writer (DISC-002) |
| Atomic JSONL publication | Temp file, fsync, rename, history backup | Same | Excluded: written in place (DISC-003) |
| Output modes | Rich, Plain, JSON, TOON, Quiet | Same | Plain, JSON, Quiet |
| Reads git history | Reporting commands only | Same | Excluded (no subprocess effect in Bend) |
| Evidence of behavior | Its own test suites | 235 captured cases in this repository | Those same 235 cases on every lane, plus laws |

**When to use `br`:** always, today. It is the working tool.

**When to look at this repository:** you want to follow or audit a port done under the two-equivalences method, or you are an agent working on it.

---

## Building from Source

There is no binary to build. What can be set up today is the toolchain the evidence was captured with, and the gates that already run.

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

Results are the lines pasted in `docs/PORT_STATE.md` on 2026-09-20.

| Gate | Command | Last result |
|------|---------|-------------|
| Case table syntax | `scripts/cases-lint.sh goldens/cases.tsv` | `OK`: 235 cases, 0 errors, 0 notes |
| One case through the original | `scripts/ws-run.sh --oracle br --no-db :: [@fx=<fixture>] <br args…>` | The original's bytes in the sandbox |
| Capture | `scripts/golden-capture.sh goldens/cases.tsv goldens --timeout 60 -- scripts/ws-run.sh --oracle br --no-db ::` | A re-capture needs `--repin` or `--disc`; the last `--repin` (a sandbox fix) changed 0 of 705 golden hash lines |
| Floor | `scripts/floor.sh goldens/cases.tsv goldens --repeat 3 --timeout 60 -- scripts/ws-run.sh --oracle br --no-db ::` | `STABLE`, 235 of 235 |
| Laws | `(cd port && $BEND_CLI PROOF.bend)` | `All terms check.` (0 `@unsafe`; the scaffold's single law) |
| Lanes | `LANE_WRAP=$PWD/scripts/ws-run.sh scripts/lanes.sh goldens/cases.tsv goldens "$PWD/port/main.bend" --threads 8 --timeout 60 --interpreter-timeout 120` | `FAIL`: the scaffold placeholder passes 1 of 235 on every lane |
| Parity board | `scripts/parity-board.sh docs/FEATURE_PARITY.md` | `MALFORMED`: template rows |
| Wording | `scripts/claims-lint.sh docs/*.md perf/*.md README.md` | Scans claim-bearing documents for hedges and deferrals |

Not run, because there is nothing to run them on: `scripts/converge.sh` (no find-fix rounds before Phase 4) and `scripts/incumbent-bench.sh` (no port binary to measure before Phase 5). Each script prints its contract with `--help`.

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

The surface in scope, from PLAN §3. "Cases" counts the rows of `goldens/cases.tsv` whose argv invokes the command, error and edge cases included. Examples are captured argv; ids such as `proj-mta` belong to the `basic` fixture.

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
| `ready` | Open, unblocked, not deferred work; `--sort priority\|oldest`, `--include-deferred`, filters | `ready -l db --json` | 12 |
| `blocked` | Issues with open blocking dependencies | `blocked --json` | 4 |
| `search` | Text search over title and description, case-insensitive, with filters | `search work --status closed` | 9 |
| `count` | Count, optionally grouped (`--by-status`, `--by-priority`, `--by-type`, `--by-assignee`, `--by-label`) | `count --by-priority --json` | 9 |
| `stats` | Project statistics (without the commit-activity part, which runs git) | `stats --json` | 4 |
| `where`, `version` | Active `.beads` directory; version report (the port's own `version` contract is OQ-003) | `where --json` | 2 / 2 |

### Dependencies, Labels, Comments, Epics

| Command | Contract (`br --no-db`) | Example (captured) | Cases |
|---------|-------------------------|--------------------|-------|
| `dep add` / `dep remove` | Typed edges; refuses cycles (exit 5), self-dependency, missing ids; duplicate and `external:` edges | `dep add proj-ptp proj-mta -t related` | 11 / 2 |
| `dep list` / `dep tree` / `dep cycles` | Read the graph | `dep tree proj-uly --json` | 3 / 3 / 3 |
| `label add/remove/list/list-all/rename` | Label charset and limits | `label rename backend server --json` | 11 in total |
| `comments add` / `comments list` | Comment identity, `--author`, `-m` | `comments add proj-mta "Looks good."` | 7 / 3 |
| `epic status` | Epic rollups | `epic status --json` | 2 |
| `epic close-eligible` | In scope per PLAN §3 | none captured | 0: a case is captured before its board row can read `present` |

### Global Flags and Exit Codes in the Corpus

| Flag | Description |
|------|-------------|
| `--no-db` | JSONL-only mode: the whole contract |
| `--json` | JSON output; errors are a pretty-printed `{"error":{…}}` object on stdout |
| `--quiet` | Quiet mode (`list --quiet` prints nothing) |
| `--actor <name>` | Actor recorded on the mutation (`created_by` in case `actor_flag_create`) |

| Exit code | Cases | Examples in the corpus |
|-----------|-------|------------------------|
| 0 | 177 | success, including no-op outcomes such as `dep_add_duplicate` (`Dependency already exists: …`) and the `delete` preview |
| 2 | 16 | argument-parser usage errors; `NOT_INITIALIZED` (no `.beads/`) |
| 3 | 16 | `ISSUE_NOT_FOUND`, `AMBIGUOUS_ID`, `NOTHING_TO_DO` |
| 4 | 19 | `VALIDATION_FAILED`, `INVALID_PRIORITY`, no ids and no last-touched issue |
| 5 | 3 | `CYCLE_DETECTED`, self-dependency |
| 7 | 4 | `CONFIG_ERROR`: merge conflict markers or malformed JSON in `issues.jsonl` |

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
│  goldens/   235 cases: <case>.out .err .exit, MANIFEST.txt           │
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

The register is `docs/DISCREPANCIES.md`. All five entries are `OPEN` with the approver pending (the repository owner); until a DISC is accepted it counts as a bug. The impact figures are the register's own, measured on the 231-case corpus of that date.

| Id | Class | Original | Port | Kill-switch | Measured impact |
|----|-------|----------|------|-------------|-----------------|
| DISC-001 | Nondeterminism | Timestamps and ids derive from the wall clock; `br` has no override | Identical bytes when `BEADS_BEND_NOW=<epoch seconds>` is set; the real clock otherwise (see the note below the table). One environment read in the shell; the core never sees a clock | Unset the variable (the default) | 0 of 231 goldens differ because of it; without it no mutating case is reproducible |
| DISC-002 | Excluded | Takes three lock files and refuses to export when the on-disk JSONL changed since load | No lock files. Two concurrent port writers can lose an update | None inside Bend; serialize writers outside the tool. Repayment: a custom lock effect | 0 of 231; the exposure is concurrent agents on one workspace, which the corpus does not exercise |
| DISC-003 | Platform | Stages a temp file, fsyncs, publishes by rename, keeps a history backup | Same final bytes, written in place. A kill during the write can leave a truncated store; no backup exists | None inside Bend. Repayment: a custom `file_rename` effect | 0 of 231; crash windows are not observable in the harness |
| DISC-004 | Excluded | Leaves lock files and `.br_history/` in `.beads/` | Writes `issues.jsonl` and `last-touched` only | None | 0 of 231 |
| DISC-005 | OrderLeak | The candidate list of an ambiguous partial id is hash-random per process (six runs printed four orders) | Candidates in ascending byte order of the id, in the message and in `context.matches` | None is meaningful: there is no single original order | 1 of 231 unstable before the canonicalizer in `scripts/ws_inner.py`; byte-identical repeated runs after it. The exit code is never canonicalized |

A sixth entry is already known. Bend 2.0.20 has no wall clock: `IO.now` is a monotonic millisecond ticker (OQ-004). "The real clock" is therefore a custom effect, `Clock.wall`, probed in `port/probes/clock/`: it loads on the interpreter, the C lane and the JS lane, with nanoseconds on C and milliseconds on the other two (OQ-009). An unpinned timestamp would print 9 fraction digits on one lane and 3 on the others, which becomes a `Platform` DISC when the clock lands in Phase 3. Pinned runs, and so every golden, are unaffected.

### Open Questions

`docs/OPEN_QUESTIONS.md` holds the spec gaps. Resolved by running the original or the pinned runtime: OQ-001 (ordering over mixed-precision timestamps is chronological, id ascending breaks ties), OQ-002 (a mutation rewrites and normalizes every record), OQ-004 and OQ-009 (the clock, above). Open: OQ-003 (the port's own `version` contract; `version_plain` and `version_json` are captured), OQ-005 (`br --no-db init`), OQ-006 (exact issue counts at which the id length steps), OQ-007 (which empty optional strings survive a rewrite), OQ-008 (when `last-touched` is written). Every OQ is resolved or excluded before the parity gate converges.

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
| **Unpinned timestamps differ by lane** | No wall clock in Bend 2.0.20; the custom effect is nanosecond on C and millisecond on the interpreter and JS (OQ-009). Its C side uses runtime internals with no ABI promise, so it is rebuilt and re-probed on every Bend pin move (PLAN §8) |
| **Conformance is bounded by the corpus** | 235 cases is what "golden-tested" means here; behavior outside them is unclaimed |
| **No gpu lane on this host** | No CUDA device; the lane is recorded `MISSING` with that reason |

---

## FAQ

### Q: Can I use this instead of `br` today?

No. There is no implementation, and no name has been chosen for the port's binary (this README says "the port's binary" until the owner picks one). Use [`br`](https://github.com/Dicklesworthstone/beads_rust).

### Q: How does its speed compare with `br`?

Nothing has been measured, so nothing is claimed. Phase 5 produces the measured comparison, and only under the incumbent contract: the pinned release binary, thread parity, interleaved runs, medians, cv ≤ 5% or the capture is refused and recorded as `NO_EVIDENCE`. PLAN §5 says it directly: no ratio is promised before it is measured.

### Q: Will `bv` and my other beads tooling work with it?

The contract is that the port writes the same `.beads/issues.jsonl` bytes as `br --no-db` for the same inputs, which is what those tools read. Interoperation with `bv` itself is not exercised by this corpus, so it is not claimed.

### Q: If goldens are empirical, what do the proofs buy?

They split the risk. Goldens say the *simple* code matches the original on 235 captured cases. Laws say the *optimized* code equals the simple code for every input in the law's domain. So an optimization cannot introduce a behavior the goldens miss, and the goldens only ever have to vouch for code that is literal enough to review. The proofs do not cover compiler backends, effects, or the corpus's blind spots, and this README does not say they do.

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

## About Contributions

Please don't take this the wrong way, but I do not accept outside contributions for any of my projects. I simply don't have the mental bandwidth to review anything, and it's my name on the thing, so I'm responsible for any problems it causes; thus, the risk-reward is highly asymmetric from my perspective. I'd also have to worry about other "stakeholders," which seems unwise for tools I mostly make for myself for free. Feel free to submit issues, and even PRs if you want to illustrate a proposed fix, but know I won't merge them directly. Instead, I'll have Claude or Codex review submissions via `gh` and independently decide whether and how to address them. Bug reports in particular are welcome. Sorry if this offends, but I want to avoid wasted time and hurt feelings. I understand this isn't in sync with the prevailing open-source ethos that seeks community contributions, but it's the only way I can move at this velocity and keep my sanity.

---

## License

This repository has no LICENSE file. The license is the owner's decision, and this section names it once that file exists. `br` itself is MIT with an OpenAI/Anthropic rider; see its repository.

---

<div align="center">
  <sub>Oracle: br 0.6.0. Target: Bend 2.0.20. Evidence: captured goldens and checked laws.</sub>
</div>
