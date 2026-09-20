# AGENTS.md — beads_bend (the Bend 2 port of `br`)

> Guidelines for AI coding agents working in this Bend 2 port of the Rust CLI `br` (beads_rust).

Read this whole file, then `docs/PORT_STATE.md`, before any work. The machine-wide rules in `/data/projects/AGENTS.md` also apply here; nothing below relaxes them.

---

## RULE 0 - THE FUNDAMENTAL OVERRIDE PREROGATIVE

If I tell you to do something, even if it goes against what follows below, YOU MUST LISTEN TO ME. I AM IN CHARGE, NOT YOU.

---

## RULE NUMBER 1: NO FILE DELETION

**YOU ARE NEVER ALLOWED TO DELETE A FILE WITHOUT EXPRESS PERMISSION.** Even a new file that you yourself created, such as a test code file. You have a horrible track record of deleting critically important files or otherwise throwing away tons of expensive work. As a result, you have permanently lost any and all rights to determine that a file or folder should be deleted.

**YOU MUST ALWAYS ASK AND RECEIVE CLEAR, WRITTEN PERMISSION BEFORE EVER DELETING A FILE OR FOLDER OF ANY KIND.**

This port's harness is built so that nothing needs deleting:

- `scripts/ws-run.sh` runs every case in a bubblewrap tmpfs that vanishes with the process.
- `scripts/make-fixture.sh` refuses to overwrite an existing fixture.
- `scripts/golden-capture.sh` preserves all previous golden files in a backup directory under `TMPDIR` on a re-capture.
- `scripts/evidence-bundle.sh` refuses to overwrite an existing bundle.

Two machine-wide rules are restated because agents break them most:

- **Agent Mail process protection:** NEVER run `am service restart`, `am service stop`, `am doctor fix`, `am doctor repair`, `am doctor reconstruct`, or `kill` any `am`, `am serve-http` or `mcp-agent-mail` process. If `am` fails: retry once after a few seconds, then proceed WITHOUT agent-mail.
- **coding-agent-search data is sacred:** never delete, move, modify, truncate or overwrite anything under `~/.local/share/coding-agent-search/` or any `agent_search.db*` file.

---

## Irreversible Git & Filesystem Actions — DO NOT EVER BREAK GLASS

1. **Absolutely forbidden commands:** `git reset --hard`, `git clean -fd`, `rm -rf`, or any command that can delete or overwrite code/data must never be run unless the user explicitly provides the exact command and states, in the same message, that they understand and want the irreversible consequences.
2. **No guessing:** If there is any uncertainty about what a command might delete or overwrite, stop immediately and ask the user for specific approval. "I think it's safe" is never acceptable.
3. **Safer alternatives first:** When cleanup or rollbacks are needed, request permission to use non-destructive options (`git status`, `git diff`, `git stash`, copying to backups) before ever considering a destructive command.
4. **Mandatory explicit plan:** Even after explicit user authorization, restate the command verbatim, list exactly what will be affected, and wait for a confirmation that your understanding is correct. Only then may you execute it—if anything remains ambiguous, refuse and escalate.
5. **Document the confirmation:** When running any approved destructive command, record (in the session notes / final response) the exact user text that authorized it, the command actually run, and the execution time. If that record is absent, the operation did not happen.

In this repository "overwrite code/data" includes every file under `goldens/` and `port/LAWS.bend`: see "Goldens Are Captured, Never Typed or Edited" and "Code Editing Discipline".

---

## Git Branch: ONLY Use `main`, NEVER `master`

**The default branch is `main`.** `git branch -a` lists `main` and nothing else.

- **All work happens on `main`**
- **Never reference `master` in code or docs** — if you see `master` anywhere, it's a bug that needs fixing
- As of 2026-09-20 `git remote -v` prints nothing: this repository has no remote. See "Landing the Plane" for what that means at session end.
- `legacy/` and `toolchain/` are gitignored (`.gitignore`); never force-add them.

---

## Session Start

1. Read this file, whole.
2. Read `docs/PORT_STATE.md`: the phase, the last pasted gate outputs, the open items, the one executable next action.
3. Set the session environment (the line `docs/PORT_STATE.md` assumes for every command it records):
   ```bash
   cd /data/projects/beads_bend; export BEND_NO_TELEMETRY=1 BEND_CLI=$PWD/scripts/bend-cli.sh LANE_WRAP=$PWD/scripts/ws-run.sh
   ```
4. Compare `$BEND_CLI --version` with `docs/PLAN_TO_PORT_BEADS_RUST_TO_BEND2.md` §2b (`bend 2.0.20`). A mismatch is a `DRIFT:` line in `docs/PORT_STATE.md`, and `scripts/version-drift.sh` runs before any other gate.
5. Run `./scripts/pin-check.sh docs/PIN.toml`. GREEN: trust the gates. YELLOW: every claim made in the session carries the caveat the note names. RED: stop and re-pin or re-capture before any gate line is pasted.
6. Before non-trivial work, retrieve prior context (machine-wide protocol): `cm context "<task description>" --json`.
7. When a tool is unavailable (cass, a device, bun), record a `BLOCKER` line where the result would have gone; never skip silently.

---

## The Two Equivalences (never conflated)

```
original ==(goldens: captured cases and lanes)== spec twins ==(laws: stated domain)== fast twins
```

1. **original == spec** is *golden-tested*: `goldens/` holds the original's captured stdout, stderr and exit code per case in `goldens/cases.tsv`; `scripts/lanes.sh` must pass on every lane (interpreter, C at 1 and N threads, JS, the device when a bang exists). A failing case is a port bug or a spec gap, never a tolerance.
2. **spec == fast** is *law-proved*: every fast twin is bound to its spec twin in `port/LAWS.bend`, and `bend port/PROOF.bend` (`$BEND_CLI port/PROOF.bend` when a non-default CLI is set, which is always the case in this port) must print `All terms check.` The unsafe count from that output and `bend --version` are stated beside every parity or performance claim.

A claim says which equivalence it rests on. "Proved" means a law; "golden-tested" means the harness on named lanes; "measured" means an interleaved, cv-gated capture with a checksum. Nothing else is a claim.

Nothing compares the original with a fast twin except the shipped binary on the goldens.

The left equality is empirical and bounded by the corpus. A quantified law covers its stated inputs and premises in Bend's logical semantics; a closed law covers one value. Neither establishes that compiled runtime intermediates fit `Nat`'s 48-bit representation, that effects succeed, or that compiler backends are correct. State trusted laws, unsafe definitions, dispatcher bounds and any unproved representation bridge separately.

---

## The Oracle: the Released `br 0.6.0` Binary, NEVER the Live Tree

| field | value (source: PLAN §2) |
|---|---|
| oracle artifact | the published release binary `~/.local/bin/br`, `br 0.6.0`, 27,772,512 bytes |
| sha256 | `21b967c1ae68df1a2e8eb2256d13b8e57d293d89e331933919076104832ddbc0` (check: `sha256sum ~/.local/bin/br`) |
| pinned commit | `b1cfebe05437463e91a353cf2bedafac27266f5b`, tag `v0.6.0` |
| contract | `br --no-db <args>` inside the pinned environment (see "The Hermetic Sandbox") |
| tag snapshot of the source | `legacy/BEADS_RUST_v0.6.0/` (gitignored) |
| the live tree | `/dp/beads_rust`, also reachable as the symlink `legacy/BEADS_RUST`: 271 commits past the pin and edited concurrently by other agents. **It is NOT the oracle.** |

Rules:

- **The original is a behavior oracle, not a template.** It is run (capture, floor, incumbent) and never read during implementation. Implementation reads `docs/EXISTING_BEADS_RUST_STRUCTURE.md` (the spec).
- **`legacy/` is never opened while implementing** (Phase 3 onward): not with an editor, not with `rg`, not with `ast-grep`, not with `warp_grep`.
- **Never read, build, run or cite `/dp/beads_rust` or `legacy/BEADS_RUST`.** A binary built from the live tree is a different program from the oracle. Never modify anything under `/dp/beads_rust`.
- **Phase 1 spec extraction** is the one activity that reads the original's source, and it reads only the tag snapshot `legacy/BEADS_RUST_v0.6.0/` under `docs/spec-parts/EXTRACTOR_BRIEF.md`. Where the source and a golden disagree, the golden wins.
- **A spec gap is an `OQ-` entry** in `docs/OPEN_QUESTIONS.md`, resolved by *running* the original on a new case and capturing it, then amending the spec clause. Each entry names the case that resolved it.
- **The original is run only through the sandbox:** `scripts/ws-run.sh --oracle br --no-db :: [@fx=<fixture>] <br args…>`.
- **No oracle-on-oracle.** The only sanctioned self-run of the original against its goldens is `scripts/floor.sh`.
- **Never run `br upgrade`.** The oracle is the file at `~/.local/bin/br`; replacing it changes the pin. The same binary serves this repository's own issue tracking (see "Beads (br)"); use it, never replace it.
- A new original version is a re-pin: PLAN §2 and `docs/PIN.toml`, then `scripts/floor.sh`, then `scripts/golden-capture.sh … --repin "<reason>"`, with every changed MANIFEST hash explained.

---

## Goldens Are Captured, Never Typed or Edited

- `scripts/golden-capture.sh` writes `goldens/<case>.out`, `.err`, `.exit` and `goldens/MANIFEST.txt`. No agent types or edits any of them, by hand or by script.
- Re-capture only when the contract changes (a new original pin, or an accepted `DISC-` entry), through `--repin "<reason>"` or `--disc DISC-nnn`. **Never to make a red case green.**
- Every re-capture diffs `goldens/MANIFEST.txt`; every changed hash is explained as a clause change, a DISC, or a bug in the original. No hash changes silently.
- **No skip.** A missing golden, an unrunnable case or an empty manifest is FAIL.
- A case name in `goldens/cases.tsv` is an identifier and is never renamed.

The commands, verbatim from the header of `goldens/cases.tsv`:

```bash
# Capture
scripts/golden-capture.sh goldens/cases.tsv goldens --timeout 60 -- scripts/ws-run.sh --oracle br --no-db ::
# Floor
scripts/floor.sh goldens/cases.tsv goldens --repeat 3 -- scripts/ws-run.sh --oracle br --no-db ::
# Check
LANE_WRAP=scripts/ws-run.sh scripts/lanes.sh goldens/cases.tsv goldens "$PWD/port/main.bend"
```

A re-capture adds `--repin "<reason>"` or `--disc DISC-nnn` before the `--`.

### Adding a case

1. Add a row to `goldens/cases.tsv`: `name<TAB>argv` (a JSON string array). Leading pseudo-arguments select the inputs: `@fx=<name>`, `@time=<UTC>`, `@scn=<name>`.
2. `./scripts/cases-lint.sh goldens/cases.tsv` → OK.
3. Capture with `--repin "new case <name>"`; the printed MANIFEST diff must name only the new case.
4. Name the case in the spec clause it exercises (`docs/EXISTING_BEADS_RUST_STRUCTURE.md`).
5. Run the lanes. PASS, or the failure is your finding.

`goldens/MANIFEST.txt` records the capture command (`scripts/ws-run.sh --oracle br --no-db ::`) and the sha256 of `scripts/ws-run.sh`. The sandbox is part of the contract: a change to `scripts/ws-run.sh` or `scripts/ws_inner.py` is made only together with a re-capture under `--repin` or `--disc`, and the MANIFEST diff is read. The precedent is in the MANIFEST header: `recapture: repin: harness fix: ws-run.sh binds TMPDIR read-write for the interpreter lane; oracle bytes unchanged`.

---

## The Hermetic Sandbox (`scripts/ws-run.sh`)

`br` is stateful (a `.beads/` directory), writes the absolute workspace path into records, and derives ids and timestamps from the wall clock. A case is reproducible only when every run sees the same world. `scripts/ws-run.sh` gives the original and every port lane that world, identically:

| element | value |
|---|---|
| isolation | bubblewrap (`bwrap`): `--tmpfs /mnt`, `--clearenv`, `--die-with-parent`; the root filesystem is bound read-only; `/tmp` and `TMPDIR` stay writable (`scripts/lanes.sh` builds its binaries there) |
| workspace | always `/mnt/proj`, fresh per run (so `source_repo_path` is `/mnt/proj` and the derived prefix is `proj`) |
| environment | `PATH`, `HOME=/mnt/home`, `USER=tester`, `TZ=UTC`, `NO_COLOR=1`, `RUST_LOG=error`, `BEND_NO_TELEMETRY=1`, `BEND_BIN`, `WS_ROOT` |
| clock, original | `--oracle` preloads libfaketime (`toolchain/faketime/root/usr/lib/x86_64-linux-gnu/faketime/libfaketime.so.1`) with `FAKETIME=<absolute>` and `DONT_FAKE_MONOTONIC=1` (a fully frozen clock hangs `br`) |
| clock, port | `BEADS_BEND_NOW=<epoch seconds>`, read once in the shell; the core never sees a clock (DISC-001). libfaketime reaches only the C lane, which is why the instant enters as an environment read |
| default instant | `2026-01-02 03:04:05` UTC; `@time=<YYYY-MM-DD hh:mm:ss>` overrides it |
| inputs | `@fx=<name>` copies `goldens/fixtures/<name>.jsonl` to `.beads/issues.jsonl` (default: empty; `none` = no `.beads/` at all); `@scn=<name>` runs `goldens/scenarios/<name>.scn` step by step |
| state dump | when a run changes the store, `--- .beads/issues.jsonl ---` (and `last-touched`) follow the command's stdout, so a read-only command that rewrites the store fails its golden |
| canonicalizer | `canon` in `scripts/ws_inner.py` sorts only the candidate lists of an `Ambiguous ID` message (DISC-005), identically for the original and the port; the exit code is never canonicalized |
| exit | the CLI's exit code (single step) or 0 (scenario; each step prints its own `[exit N]`); 125 = sandbox or usage failure (INCONCLUSIVE in conform) |

Usage, from `scripts/ws-run.sh --help`:

```
ws-run.sh [--oracle] <inner command…> :: <case args…>
  --oracle   the inner command is the original: preload libfaketime
  case args  [@fx=<fixture>] [@time=<YYYY-MM-DD hh:mm:ss>] <argv of the CLI…>
             or  @scn=<scenario>  (goldens/scenarios/<scenario>.scn, multi-step)
```

Rules:

- Never run the original against a real directory to "see what it does" and paste the result into the spec. Run it through the sandbox, as a case, and capture it.
- Never add a second clock seam, a second workspace path or an environment variable to the port to make a case pass. `BEADS_BEND_NOW` is the one test seam, and it is a DISC with the variable as its switch.
- The sandbox workspace `/mnt/proj/.beads/` has nothing to do with this repository's own issue tracker.

### Fixtures are never overwritten

- Fixtures live in `goldens/fixtures/`; scenarios in `goldens/scenarios/`.
- The realistic fixtures are the original's own output: `scripts/make-fixture.sh <fixture-name> <scenario-name>` runs a scenario through the original in the sandbox and saves the store it leaves. The scenario file is the fixture's provenance.
- `scripts/make-fixture.sh` **refuses to overwrite an existing fixture**. Goldens depend on fixture bytes, so a changed fixture is a new name plus a `golden-capture.sh --repin`. Never edit a fixture in place.

---

## Toolchain: Bend 2, bun, clang

We only use the **pinned Bend 2 release** in this project, NEVER whatever `bend` happens to be on `PATH`.

| tool | pin (source: PLAN §2b) |
|---|---|
| Bend | `bend 2.0.20`, release binary at `~/.bend/bin/bend`, sha256 `fab9e564c578a0a15880d5fea561ac1612dba01265a5a219906b5888f3381d8c`; retained artifact `toolchain/bend-2.0.20-linux-x64.tar.gz`; matching source `toolchain/bend-v2.0.20-src/` |
| bun | `1.4.2` (the JS lane) |
| clang | `Ubuntu clang version 21.1.8 (6ubuntu1)` (the C lanes) |
| host | `Linux x86_64`, 8 cores; no CUDA: the gpu lane is MISSING, and a MISSING lane states its reason |
| bubblewrap, python3 | required by `scripts/ws-run.sh` |
| libfaketime | 0.9.10, under `toolchain/faketime/` |

Rules:

- **Every Bend invocation goes through `scripts/bend-cli.sh`**: `export BEND_CLI=/data/projects/beads_bend/scripts/bend-cli.sh`. Bend 2.0.17 replaced `bend --version` with `bend version`; the wrapper translates that one spelling and passes every other argument through unchanged, so the harness runs unmodified. `BEND_BIN` overrides the binary.
- **`BEND_NO_TELEMETRY=1` always.** The wrapper, `scripts/lanes.sh`, `scripts/port-doctor.sh` and `scripts/ws-run.sh` set it; set it yourself for any direct call.
- **`bend update` is never run inside a port session.** A new Bend version is a pin move: `scripts/version-drift.sh --old "<pinned cli>" --new "<new cli>"`, then PLAN §2b, `docs/PIN.toml [bend]` and the version in every claim.
- **`toolchain/` is gitignored, retained on purpose, and read-only reference.** It holds the release artifact, the source the Bun tools match, the 2.0.16 tree used for the drift check, and libfaketime. Never edit anything under it.
- **The harness scripts are copies.** `scripts/ORIGIN.md`: copied from the `porting-to-bend2` skill on 2026-09-20; update by re-copying, never by editing here. The port's own files are `scripts/ws-run.sh`, `scripts/ws_inner.py`, `scripts/make-fixture.sh`, `scripts/bend-cli.sh`, and the `LANE_WRAP` block in `scripts/lanes.sh` (marked "this port's addition").

### Drift already recorded against the skills (PLAN §2b)

Both Bend skills were written against 2.0.13/2.0.16. Under 2.0.20 (PLAN §2b and §8, OQ-004, OQ-009):

- `base.bend` differs in 62 lines; effects gained `tcp_poll`.
- Since 2.0.17 an operator takes its type only from its own `( .. : T)`; a bare operator is no longer `Nat`.
- Since 2.0.17 a template instance no longer counts as unsafe, and the verdict names the defs that rely on `@unsafe` or a foreign def: `All terms check, but N defs rely on unsafe or foreign code:` plus one `- <def>` line each, on every engine.
- **Bend 2.0.20 has no wall clock.** `IO.now()` is a monotonic millisecond ticker. An unpinned run needs a custom effect (`Clock.wall`, probed in `port/probes/clock/`); nanoseconds on C, milliseconds on the interpreter and JS.
- A custom effect's C side uses runtime internals with no ABI promise: it is rebuilt and re-probed on every Bend pin move.
- File effects are `open`, `read`, `read_bytes`, `read_at`, `size`, `write`, `write_bytes`, `close`: no existence test, mkdir, rename, fsync or exclusive create.
- `scripts/interp-lane.sh` strips a one-line compiler note (2.0.16); 2.0.20 prints several lines when a foreign def is reachable. The first Phase 3 lane run of the shell is the check (`docs/PORT_STATE.md`, item DRIFT).

When a skill reference and the pinned `bend guide` disagree, the pinned CLI wins and the disagreement is written down (PLAN §8 for the toolchain, an OQ for behavior). Runtime questions are settled the way spec gaps are: by a probe under `port/probes/` run on every engine, never by recollection.

---

## Code Editing Discipline

### No Script-Based Changes

**NEVER** run a script that processes/changes code files in this repo. Brittle regex-based transformations create far more problems than they solve.

- **Always make code changes manually**, even when there are many instances
- For many simple changes: use parallel subagents
- For subtle/complex changes: do them methodically yourself

The only files a script writes here are the ones its contract names: `scripts/golden-capture.sh` writes goldens and the MANIFEST; `scripts/make-fixture.sh` writes a new fixture; `scripts/evidence-bundle.sh` writes a new bundle.

### No File Proliferation

If you want to change something or add a feature, **revise existing code files in place**.

**NEVER** create variations like:
- `mainV2.bend`
- `main_improved.bend`
- `main_enhanced.bend`

New files are reserved for **genuinely new functionality** that makes zero sense to include in any existing file. The bar for creating new files is **incredibly high**.

A fast twin is not a file variation: it is a second def with the same signature beside its spec twin, bound to it by a law.

### Bend Specifics

1. **Read `bend guide` for the installed version before writing Bend** (`$BEND_CLI guide`; the Base library is `$BEND_CLI base`). The syntax moved: no `if`, little inference, no user mutual recursion, `law` not `assert`, `{==}` not `{=}`. Read the `bend2-mega-skill` SKILL.md "First 30 Seconds" at Phase 3, before writing Bend.
2. **Core and shell.** The port is a PURE CORE (spec twins, then fast twins bound to them by laws) and an IO SHELL (args, files, stdout, exit codes) that only calls the core. The shell decides whether and when; the core decides what. A shell def that branches on data is a smell: move the branch into a core def that returns a verdict. PLAN §8 records that the core and the shell live in **separate files**, and `port/PROOF.bend` imports only the core: a program that reaches a foreign def changes the checker's verdict text. Nothing in `port/` consults the original.
3. **Spec twin first.** A spec twin is the literal, sequential, obviously-correct translation of one spec clause. Fast twins come in Phase 5, one law each. No lever without `{fast == spec}` proved.
4. **A `# S<n.m>` clause tag above every def.** Every def names the spec clause it implements. A def with no clause is either missing a clause (an OQ) or does not belong.
5. **`port/LAWS.bend` is human-owned:** add laws, never weaken or delete one. A law the checker cannot prove is a finding about the code or the spec. A requested behavior that conflicts with a law needs an explicit explanation and an agreed resolution; never change the law silently to fit the code. Every law names the spec clause it encodes. To propose one, append `# PROPOSED: <law text>` with its clause. `port/PROOF.bend` is the agent's file: `def Laws.<name>(params)` fills each law; lemmas go above their first use. Bend refuses a `PROOF.bend` beside a `LAWS.bend` it does not import.
6. **`@unsafe` needs a comment naming the measure that was not expressible and a bead;** the count is reported, never hidden. A smaller count after downgrading is not stronger proof.
7. **Numeric plan before arithmetic; order carried explicitly.** `docs/NUMERIC_PLAN.md` is written before any Bend arithmetic: `U32` where the original wraps, `Nat` below 2^48 with the bound stated, two `U32` words for 64-bit, `F32` only as a budgeted class. Insertion order is a key list beside the Map. The encoding contract is written down.
8. **The checker's shape rules:** affine by default (one use per live variable unless `+`); a `match` scrutinizes only a parameter or a pattern-bound field; recursion descends left to right (`Nat.sub` and `U32` decrements do not establish descent: prefer structural recursion or fuel); definitions resolve in source order; no mutual recursion (one def with a phase parameter).
9. **Know the walls:** `Nat` ≤ 2^48−1, arity ≤ 255, JS deep recursion. PLAN §7 names where they bite this port (the 44-field Issue record, a 4.5 MB `issues.jsonl`).
10. **One lever, one clause, one fix at a time; the first divergence first.** Three strikes on one case → an OQ, and move on.

---

## Bug-Compatibility Is the Default

beads_rust's own AGENTS.md says it does not care about backwards compatibility. For this port's observable contract the rule is the opposite: **the port reproduces the original byte for byte, bugs included.**

- A deliberate divergence from the original is a `DISC-` entry in `docs/DISCREPANCIES.md` with a class, a kill-switch, the affected cases and a measured impact. **No silent fixes.** Until accepted it is a bug.
- A DISC is approved by someone who did not implement it. The DISC approver is the repository owner (PLAN §7).
- Goldens are re-captured for an accepted DISC only through the canonicalizing wrapper the entry names, with `--disc DISC-nnn`.
- `ACCEPTED`, `REVERTED` and `RESOLVED` entries keep their historical text and original evidence.
- DISC-001 through DISC-005 are all `OPEN` with `Approver: pending (repository owner)` as of 2026-09-20. An OPEN DISC blocks convergence (`scripts/converge.sh`).

Inside the port's own code the beads_rust rule still holds: no compatibility shims, no wrapper defs for superseded defs. Fix the def.

---

## Checker and Gates (CRITICAL)

**After any substantive change to `port/`, you MUST run the checker:**

```bash
$BEND_CLI port/PROOF.bend      # must print: All terms check.
```

Only `All terms check.` is green. Any longer verdict (`All terms check, but N defs rely on unsafe or foreign code:` under the 2.0.20 pin) exits 0 and is a partial green: report the count and every def it names. `port/PROOF.bend` is green at every commit. `docs/PORT_STATE.md` records the same gate as `(cd port && $BEND_CLI PROOF.bend)`.

### Gates (paste their last lines into PORT_STATE; never paraphrase)

| gate | command |
|---|---|
| the pin | `./scripts/pin-check.sh docs/PIN.toml` before any gate is trusted (GREEN / YELLOW / RED) |
| proofs | `$BEND_CLI port/PROOF.bend` → `All terms check.`, with the unsafe count from the same output and `$BEND_CLI --version` |
| lanes | `LANE_WRAP=scripts/ws-run.sh scripts/lanes.sh goldens/cases.tsv goldens "$PWD/port/main.bend"` (interpreter, c-1t, c-Nt, js; last line JSON; a lane that cannot be built is MISSING, and MISSING never passes). The run recorded in `docs/PORT_STATE.md` adds `--threads 8 --timeout 60 --interpreter-timeout 120` |
| everything at once | `./scripts/port-doctor.sh --threads <N> --original <original cmd> -- --switch BEADS_RUST_SPEC=1 --probe "<hot args>"` (proof, lanes, board, floor, kill-switch parity; last line JSON, verdict GREEN or RED). In this port `<original cmd>` is `scripts/ws-run.sh --oracle br --no-db ::` and the lanes need `LANE_WRAP=scripts/ws-run.sh` in the environment |
| one failing case | `./scripts/first-divergence.sh <case> goldens/cases.tsv goldens -- <port command>` (the divergence class and the spec section to read) |
| parity board | `./scripts/parity-board.sh docs/FEATURE_PARITY.md` (FULL, PARTIAL or DEBT; `partial` never rounds up, `excluded` is debt) |
| law coverage | `./scripts/law-coverage.sh` (every law proved, no ghost citation) |
| convergence | `./scripts/converge.sh docs/PORT_STATE.md` (computed from the rounds table and the OQ/DISC registers beside it) |
| the state file | `./scripts/state-check.sh docs/PORT_STATE.md` before ending a session (no placeholders, gate lines pasted, one executable next action) |
| the words | `./scripts/claims-lint.sh docs/*.md perf/*.md README.md` before committing any claim. `claims-lint.sh` fails on a missing requested file and no `README.md` exists as of 2026-09-20: until one does, pass `docs/*.md perf/*.md` |

If a gate is red, **carefully understand and resolve each issue**. A red gate is not negotiated. Convergence is computed, not felt: this port is tier **T3** (PLAN §2): at least 10 find-fix rounds with the last two clean, at least one non-author round, every OQ resolved or excluded, no OPEN DISC.

---

## Testing

### Testing Policy

There are no unit-test files in this port. Evidence comes in two kinds and nothing else:

- **Goldens** (original == spec): every case in `goldens/cases.tsv` compares stdout, stderr and the exit code byte for byte, on every lane.
- **Laws** (`port/LAWS.bend`): `fast == spec` for every fast twin; round trip (`decode(encode(x)) == x`) for every codec the spec names; conservation; closed goldens (a small original input whose expected output is pasted from `goldens/`); refutation. What does not belong in a law: anything the checker must normalize through a large Peano `Nat`; those stay in `goldens/`.

The corpus must cover:
- Happy path
- Edge cases (empty store, max values, boundary conditions)
- Error conditions and usage errors

`./scripts/cases-lint.sh goldens/cases.tsv` flags an absent usage, empty, error or edge/large class.

**Every lane, every time.** Interpreter, C at 1 and N threads, JS: identical bytes. A lane difference is a bug, never a tolerance.

### Case Categories (name prefixes in `goldens/cases.tsv`)

| Prefix | Focus Areas |
|--------|-------------|
| `usage_` | argv shapes the argument parser refuses: no command, unknown command or flag, missing values |
| `error_` | error paths: no workspace, ambiguous ids, refused mutations; plain and `--json` forms |
| `empty_` | every query against an empty store |
| `create_`, `q_`, `update_`, `close_`, `reopen_`, `defer_`, `undefer_`, `delete_` | mutations; their goldens carry the `--- .beads/issues.jsonl ---` dump |
| `show_`, `list_`, `search_`, `count_`, `stats_`, `where_`, `version_` | queries, filters, sort keys, the JSON envelope |
| `ready_`, `blocked_`, `dep_`, `epic_` | the dependency graph |
| `label_`, `comments_`, `actor_` | labels, comments, the `--actor` flag |
| `edge_` | boundary inputs: the `precision` fixture (OQ-001, OQ-002), the maximum title |
| `scn_` | multi-step scenarios from `goldens/scenarios/` |

The case count is `grep -vc '^#' goldens/cases.tsv` and must equal the count in the `goldens/MANIFEST.txt` header (235 on 2026-09-20).

### Test Fixtures

`goldens/fixtures/` holds `basic`, `basic_touched`, `conflict`, `empty`, `malformed` and `precision`. `goldens/scenarios/` holds `build_basic`, `child_ids`, `dup_title`, `last_touched` and `lifecycle`. See "Fixtures are never overwritten".

---

## Documents and Registers — Amend, Never Rewrite

| Document | Role |
|----------|------|
| `docs/PLAN_TO_PORT_BEADS_RUST_TO_BEND2.md` | The plan: §2 the original pinned, §2b Bend pinned, §3 scope and exclusions, §5 success criteria, §6 phases, §7 risks, §8 dated amendments. Every number in it is a gate somewhere |
| `docs/PIN.toml` | The pin as data for `scripts/pin-check.sh`. When it and PLAN §2 disagree, pin-check is RED until they agree |
| `docs/EXISTING_BEADS_RUST_STRUCTURE.md` | **THE SPEC**, the contract of the port: clauses `S<section>.<n>`, each with provenance and at least one case. After reading it an implementer must NOT need the original's source. WHAT, never HOW. Phase 1 extractor outputs land in `docs/spec-parts/` |
| `docs/PROPOSED_ARCHITECTURE.md` | Phase 2: the core/shell split; every spec clause gets a home (def) and an evidence kind (law/golden) |
| `docs/NUMERIC_PLAN.md` | Phase 2, before any Bend arithmetic: representations, the S7 inventory, exact versus budgeted output classes, the printing contract |
| `docs/FEATURE_PARITY.md` | The parity board read by `scripts/parity-board.sh`; a `present` row names its goldens and laws |
| `docs/DISCREPANCIES.md` | The `DISC-` register |
| `docs/OPEN_QUESTIONS.md` | The `OQ-` register |
| `docs/PORT_STATE.md` | Read FIRST on every resume; rewritten at the END of every session |
| `docs/PORT_REPORT.md`, `docs/PARITY_RUNBOOK.md`, `CONTRIBUTING.md` | Phase 6 outputs; scaffold templates until then |
| `perf/EXPERIMENTS.md`, `perf/EXPERIMENT-CARD.md`, `perf/PERF-LEDGER.md`, `perf/NEGATIVE-EVIDENCE.md` | The performance ledgers (Phase 5) |

Rules:

- **Amend, never rewrite.** These documents are amended as the port learns, never silently rewritten. PLAN §8 is the pattern: a dated row naming the section, the amendment and its evidence; a section is edited in place only where a "pending" cell was filled. Registers keep their historical entries and original evidence. The one exception is `docs/PORT_STATE.md`, which is rewritten at the end of every session.
- **Exclusions are debt or infeasibility, never a deferral.** Every feature the port does not carry is a row in PLAN §3 "Excluded" with a reason, a class and a debt flag, and an `excluded` row on the board. With exclusions present the board's best verdict is DEBT; never say that parity is complete or total.
- The port's contract is **`br --no-db`**: same argv, same stdout, stderr and exit code, same resulting `.beads/issues.jsonl` bytes, in Plain and JSON output modes. The SQLite store and everything that reaches it is excluded by class (PLAN §3).

---

## Claims: Proved / Golden-Tested / Measured

Claims are tagged **proved** / **golden-tested** / **measured** with their artifact, or deleted (`scripts/claims-lint.sh`).

- Never report a number without its JSON line.
- Never report a proof without the verdict line, the unsafe count and `$BEND_CLI --version`.
- Gate lines are pasted, never paraphrased.

**Parity claim:**

```
Parity: <FULL | DEBT (n exclusions: …) | PARTIAL>   commit <sha>   <date>   bend <version>
Golden-tested: <n>/<n> cases on interpreter, c-1t, c-<N>t, js[, gpu | gpu MISSING: <reason>]   MANIFEST <sha16>
Proved: <laws> — <verdict line verbatim> (unsafe <k> = <a> @unsafe + <b> template instances)   bend <version>[ @<sha>]
Discrepancies: <none | DISC-… (class)>   Open: <OQ-…>
Rounds: <r> (<c> clean, <a> non-author) — converge.sh: <CONVERGED for T<t> | NOT_CONVERGED: …>
```

**Performance claim:**

```
<ratio>× vs <original @ pin> on <input>, <port lane/threads> vs <original threads>: medians of <k> interleaved pairs,
cv <a>% / <b>%, stdout sha equal, verdict MEASURED (incumbent-bench JSON: …)   host <cpu, cores, os>   <date>
Law: <fast_is_spec> — <verdict line> (unsafe <k> = <a> @unsafe + <b> instances, bend <version>)   Kill-switch: <X_SPEC=1> parity PASS   Ledger: <PERF-LEDGER row | NE-…>
Not claimed: <refused captures with predicates>
```

Anything that does not fit these shapes is not said. **As of 2026-09-20 neither shape can be filled: no Bend implementation of `br` exists (see "beads_bend — This Project"). Never say the port is working, complete, fast or verified.**

---

## Performance Levers (Phase 5, not before the parity gate)

- Before any performance lever: sweep `perf/NEGATIVE-EVIDENCE.md` (`rg -i '<lever>' perf/`, or `./scripts/graveyard-sweep.sh "<lever>"`) and honor the retry predicate; write the experiment card in `perf/EXPERIMENTS.md` **before** the lever; capture with the cv gate and the A/A arm; a refused capture is `NO_EVIDENCE`.
- Every outcome, including losses, gets a ledger entry with a retry predicate.
- Forbidden in ledgers: "later", "if it seems important", "we should revisit", "tracked elsewhere".
- A speedup number against the original needs the incumbent contract in `docs/PLAN_TO_PORT_BEADS_RUST_TO_BEND2.md` (commit, toolchain, flags, threads) and `scripts/incumbent-bench.sh` with `--pin`; otherwise it is a maintenance number.
- The fast twin sits behind the kill-switch `BEADS_RUST_SPEC=1`, and its `{fast == spec}` law is proved before any capture.
- No perf number without an artifact: interleaved, medians, cv ≤ 5% or refused, identical stdout, laws green, fingerprint, ledgered. No ratio is promised before it is measured (PLAN §5).

---

## Bend Documentation

If you aren't 100% sure how a Bend construct or Base function behaves, **read the pinned sources** before writing it:

- `$BEND_CLI guide` and `$BEND_CLI base` for the installed version
- `toolchain/bend-v2.0.20-src/` (the matching source, with `demos`, `bench` and `tests`)
- the `bend2-mega-skill` and `porting-to-bend2` skills, checked against the pin (see "Drift already recorded")
- the reference programs PLAN §4 names: imitate, do not invent

bend2.dev is unofficial. `bend guide`, `bend base`, the repository and the papers are the authority.

---

## beads_bend — This Project

**This is the project you're working on.** beads_bend is a port of `br` (beads_rust), a local-first, dependency-aware issue tracker CLI used mostly by AI coding agents, to the Bend 2 programming language. The original keeps its primary state in SQLite and mirrors it to `.beads/issues.jsonl`; it also ships a JSONL-only mode, `br --no-db`, in which `issues.jsonl` is the whole store. **This port implements that JSONL-only contract natively in Bend 2.** Bend has no SQLite binding and no subprocess effect, so the DB-backed paths are outside what a Bend shell can carry (PLAN §3).

### Current State (2026-09-20)

`docs/PORT_STATE.md` is the authority for the phase, the gate lines and the open items; it changes every session and this section does not. What a reader must not get wrong, each fact with its check:

| fact | how to check |
|---|---|
| **No Bend implementation of `br` exists.** `port/main.bend`, `port/LAWS.bend` and `port/PROOF.bend` hold the scaffold's identity placeholder only (`core_spec`, `core_fast`, law `fast_is_spec`). The lanes gate reads FAIL for that reason | read the three files; `docs/PORT_STATE.md` "Last gate outputs" |
| Phase 1 (spec) is in progress. Phase −1 (fit screen) and Phase 0 (truth pack: 235 goldens, floor STABLE) are done. Phases 2 through 6 have not started | `docs/PORT_STATE.md`; `git log --oneline` |
| The spec `docs/EXISTING_BEADS_RUST_STRUCTURE.md` is still the scaffold template; extractor parts are landing in `docs/spec-parts/` | read the spec; `ls docs/spec-parts` |
| `docs/PIN.toml`, `docs/FEATURE_PARITY.md` (board verdict MALFORMED), `docs/NUMERIC_PLAN.md`, `docs/PROPOSED_ARCHITECTURE.md` and `port.env` still hold scaffold placeholders. `port.env` names `ORIGINAL="python3 legacy/ORIGINAL.py"` and `SWITCH=X_SPEC=1`; neither is this port's value, so `scripts/port.sh` is not usable yet | `rg -n '<' docs/PIN.toml`; read `port.env` |
| DISC-001 through DISC-005 are OPEN, approver pending | `docs/DISCREPANCIES.md` |
| The gpu lane is MISSING: no CUDA device on this host | PLAN §2b |
| No `.beads/` directory, no `README.md`, no `.github/workflows/`, no git remote | `ls -a`; `git remote -v` |

### Phases (PLAN §6)

| phase | artifact | gate to leave |
|---|---|---|
| −1 fit screen | PLAN §3 and §7 | no infeasible feature in scope without an exclusion row |
| 0 truth pack | PLAN §2, goldens, MANIFEST, floor | floor STABLE (or DISC per unstable case) |
| 1 spec | `docs/EXISTING_BEADS_RUST_STRUCTURE.md` | spec self-containment review passed |
| 2 architecture | `docs/PROPOSED_ARCHITECTURE.md`, `docs/NUMERIC_PLAN.md`, `port/LAWS.bend` draft | every spec clause has a home (def) and an evidence kind (law/golden) |
| 3 reference port | `port/main.bend` spec twins, `port/PROOF.bend` | lanes PASS, All terms check. |
| 4 parity gate | `docs/FEATURE_PARITY.md`, DISC register, find-fix rounds | parity DEBT, convergence rule met |
| 5 performance | fast twins, `perf/` ledgers, incumbent numbers | every kept lever law-bound, cv-gated, ledgered |
| 6 certify | `docs/PORT_REPORT.md`, evidence bundle | claims taxonomy complete; SHIP/HOLD/BLOCK |

### Architecture (the intended shape; `docs/PROPOSED_ARCHITECTURE.md` is unfilled, and nothing below is implemented)

```
argv, env (BEADS_DIR, BEADS_BEND_NOW), .beads/issues.jsonl, .beads/last-touched
    │
    ▼
IO SHELL (`do IO`; one call per effect, no logic; its own file)        evidence: goldens
    │   args → workspace discovery → read store → [core] → write store → stdout/stderr → exit code
    ▼
PURE CORE (spec twins; fast twins in Phase 5; imported by LAWS/PROOF)  evidence: laws + closed goldens
    ├── JSONL decode / normalize / validate, byte-exact encode
    ├── id generation (SHA-256 → base36, adaptive length) and content hash
    ├── mutations: create, q, update, close, reopen, defer, undefer, delete
    ├── queries: show, list, search, count, stats
    ├── graph: ready, blocked, dep add/remove/list/tree/cycles, epic status/close-eligible
    ├── label, comments
    └── errors and exit codes 0–8; Plain, JSON and Quiet rendering
```

### Project Structure

```
beads_bend/
├── AGENTS.md                      # This mandate
├── CONTRIBUTING.md                # Phase 6 template (placeholders)
├── port.env                       # Knobs for scripts/port.sh (scaffold placeholders)
├── .github/CODEOWNERS             # Ownership template (<handles> unfilled)
├── assets/templates/evidence-pack/
├── docs/                          # See "Documents and Registers"
│   └── spec-parts/                # Phase 1 extractor outputs; EXTRACTOR_BRIEF.md
├── goldens/
│   ├── cases.tsv                  # name<TAB>argv (JSON string array)
│   ├── MANIFEST.txt               # sha256 per golden, capture command, identity
│   ├── MANIFEST.prev.txt          # The previous manifest, copied by a re-capture
│   ├── <case>.out|.err|.exit      # CAPTURED. Never typed, never edited
│   ├── fixtures/                  # Input stores. Never overwritten
│   └── scenarios/                 # Multi-step .scn files
├── legacy/                        # GITIGNORED. Never opened while implementing
│   ├── BEADS_RUST -> /dp/beads_rust   # The LIVE tree. NOT the oracle. Never read it
│   └── BEADS_RUST_v0.6.0/         # Tag snapshot, Phase 1 extraction only
├── perf/                          # Experiment cards and ledgers (Phase 5)
├── port/
│   ├── main.bend                  # Scaffold placeholder (core and shell split into separate files in Phase 3: PLAN §8)
│   ├── LAWS.bend                  # HUMAN-OWNED. Add, never weaken or delete
│   ├── PROOF.bend                 # The agent's proofs
│   └── probes/                    # Bend probes that settle runtime questions (clock: OQ-004, OQ-009)
├── scripts/                       # Harness (copies; see ORIGIN.md) + this port's sandbox
└── toolchain/                     # GITIGNORED. Pinned Bend artifact and source, libfaketime
```

### Key Files

| Area | Key Files | Purpose |
|------|-----------|---------|
| sandbox | `scripts/ws-run.sh`, `scripts/ws_inner.py` | One hermetic case run, identical for the original and every lane |
| capture | `scripts/golden-capture.sh`, `scripts/make-fixture.sh`, `scripts/floor.sh`, `scripts/cases-lint.sh`, `scripts/argv-explore.sh` | Freeze the original; build fixtures; measure its reproducibility; lint the manifest; map its argument surface |
| conformance | `scripts/lanes.sh`, `scripts/conform.sh`, `scripts/interp-lane.sh`, `scripts/first-divergence.sh` | Every lane against the goldens; the first divergence of one case |
| Bend CLI | `scripts/bend-cli.sh`, `scripts/version-drift.sh`, `scripts/pin-check.sh` | The pinned CLI; drift between two CLIs; the pin as a check |
| proofs | `scripts/law-coverage.sh`, `scripts/law-mutation.sh` | Laws, proofs and board citations reconciled; laws that survive a broken def are WEAK |
| documents | `scripts/spec-lint.py`, `scripts/arch-lint.py`, `scripts/parity-board.sh`, `scripts/state-check.sh`, `scripts/claims-lint.sh`, `scripts/converge.sh` | The Phase 1 and Phase 2 gates, the board, the state file, the words, convergence |
| everything | `scripts/port-doctor.sh`, `scripts/harness-selftest.sh` | Every gate in one report; the gates attacked with deliberate lies |
| performance | `scripts/incumbent-bench.sh`, `scripts/graveyard-sweep.sh`, `scripts/evidence-bundle.sh`, `scripts/perf-tripwire.sh` | Phase 5 only |

Every script answers `--help` with its contract and exit codes. Read it before the first use.

### Scope

In scope and excluded surfaces are the two tables of PLAN §3; do not restate them from memory. In scope, in one line: workspace discovery, `where`, `version`, JSONL load and write-back, id generation, content hash, `create`, `q`, `update`, `close`, `reopen`, `defer`, `undefer`, `delete`, `show`, `list`, `search`, `count`, `stats`, `ready`, `blocked`, `dep`, `label`, `comments`, `epic`, errors and exit codes, output modes Plain, JSON and Quiet.

### Key Design Decisions

- **The contract is `br --no-db`** — the JSONL contract is the part of beads that other tools (`bv`, git merges, agents reading `--json`) consume
- **A pinned release binary is the oracle** — not rebuilt: rebuilding would change the pin
- **Hermetic capture** — `br` has no fixed-clock override and writes the absolute workspace path, so every case runs in the sandbox
- **One test seam, `BEADS_BEND_NOW`** — read in the shell only (DISC-001)
- **No wall clock in Bend 2.0.20** — an unpinned run needs the custom effect `Clock.wall`; its precision differs by engine, a `Platform` DISC when it lands (PLAN §8)
- **Single writer, in-place write-back, no lock or history sidecars** — Bend's file effects are open, read, write, close, size; no rename, fsync or lock (DISC-002, DISC-003, DISC-004)
- **Ambiguous-id candidates in byte order** — the original's order is hash-random per process (DISC-005)
- **SHA-256 over `U32` words; the 64-bit → base36 value as two `U32` words** — PLAN §7
- **Id-length thresholds as a finite integer table confirmed by boundary goldens, never `F32`** — PLAN §7, OQ-006
- **Tier T3** — at least 10 find-fix rounds, the last two clean, non-author rounds, stage goldens

---

## Output Modes

The original supports Rich, Plain, JSON, TOON and Quiet output. The port's scope (PLAN §3):

| Mode | When Active | In the port |
|------|-------------|-------------|
| **Plain** | piped stdout, `NO_COLOR` (the sandbox sets `NO_COLOR=1`) | in scope; glyph lines (`✓ ○ ●`) included |
| **JSON** | `--json` or `--robot` | in scope; errors are a pretty-printed `{"error":{…}}` on stdout, `Error:`/`Hint:` on stderr otherwise |
| **Quiet** | `--quiet` or `-q` | in scope |
| **Rich** | TTY with colors | excluded (platform): a captured run is piped, hence Plain |
| **Toon** | `--format toon`, `BR_OUTPUT_FORMAT=toon` | excluded (out-of-scope, debt: yes) |

### For Coding Agents

**CRITICAL:** Always use `--json` or `--robot` flags when parsing `br` output programmatically. This concerns the installed `br 0.6.0` that tracks this repository's own issues.

```bash
# CORRECT - stable, parseable output
br list --json | jq '.issues[0]'
br ready --robot

# Narrower payload: name the keys you want
br list --json --fields id,title,status,priority,issue_type

# WRONG - output format may vary based on terminal state
br list | head -1
```

`--robot` is an alias for `--json`. The installed `br 0.6.0` has no `br ready --brief` (`br ready --help`); beads_rust's live AGENTS.md describes a newer tree.

---

## Beads (br) — Dependency-Aware Issue Tracking

Beads provides a lightweight, dependency-aware issue database and CLI (`br` - beads_rust) for selecting "ready work," setting priorities, and tracking status. It complements MCP Agent Mail's messaging and file reservations. Here it tracks the work of the port itself.

**Important:** `br` is non-invasive—it NEVER runs git commands automatically. You must manually commit changes after `br sync --flush-only`.

**Two roles, one binary.** `~/.local/bin/br` is both this repository's issue tracker and the port's oracle. As a tracker it runs from the repository root in its default mode. As the oracle it runs only as `br --no-db` inside `scripts/ws-run.sh --oracle`. Never mix the two: no tracker data is a fixture, and no sandbox run touches the tracker. As of 2026-09-20 this repository has no `.beads/` directory: the `br` commands below have no workspace here until one is initialized at the repository root (`br init`). Until then the open items live in the "Open items" table of `docs/PORT_STATE.md`.

Beads and the port's registers do different jobs:

| Item | Lives in |
|------|----------|
| a task, its status, priority and dependencies | a bead |
| a spec gap | an `OQ-` row in `docs/OPEN_QUESTIONS.md` (a bead may point at it) |
| a divergence from the original | a `DISC-` entry in `docs/DISCREPANCIES.md` |
| a lost or refused performance lever | an `NE-` entry in `perf/NEGATIVE-EVIDENCE.md` |
| every `@unsafe` | a comment in the source **and** a bead |

### Bead-graph hygiene policy

**Don't close beads with `Forced close due to cycle` or similar hedge text in the `close_reason`.** If a dependency cycle is in the way, resolve it first via:

- `br dep remove <issue> <depends-on>` — drop a single edge.
- `br update <issue> --parent ''` — clear a parent-child edge.
- Refactor the bead graph itself (split / merge / restructure).

Closing a bead under an unresolved cycle hides architectural debt and produces an audit-suspect close trail.

### Conventions

- **Single source of truth:** Beads for task status/priority/dependencies; Agent Mail for conversation and audit
- **Shared identifiers:** Use the Beads issue ID (`<id>`, as `br create` prints it) as Mail `thread_id` and prefix subjects with `[<id>]`
- **Reservations:** When starting a task, call `file_reservation_paths()` with the issue ID in `reason`

### Typical Agent Flow

1. **Pick ready work (Beads):**
   ```bash
   br ready --json  # Choose highest priority, no blockers
   ```
   Then read the detail of the one issue you picked with `br show <id>`.

2. **Reserve edit surface (Mail):**
   ```
   file_reservation_paths(project_key, agent_name, ["port/**"], ttl_seconds=3600, exclusive=true, reason="<id>")
   ```
   Reserve the narrowest surface. `port/main.bend` is one file shared by every implementer: reserve it for the shortest time that works, and never hold `goldens/**` or `port/LAWS.bend` unless the task is a capture or an owner-approved law.

3. **Announce start (Mail):**
   ```
   send_message(..., thread_id="<id>", subject="[<id>] Start: <title>", ack_required=true)
   ```

4. **Work and update:** Reply in-thread with progress

5. **Complete and release:**
   ```bash
   br close <id> --reason "Completed"
   br sync --flush-only  # Export to JSONL (no git operations)
   ```
   ```
   release_file_reservations(project_key, agent_name, paths=["port/**"])
   ```
   Final Mail reply: `[<id>] Completed` with summary

### Degraded Coordination When Agent Mail Is Unavailable

Agent Mail reservations are the normal collision-avoidance mechanism. If Agent Mail is red or unreachable, retry once after a few seconds, then keep moving, and make the weaker coordination state visible in `br` before touching code. **Never diagnose, repair or restart the Agent Mail service.**

1. **Claim with an explicit actor:**
   ```bash
   br update <id> --status in_progress --assignee "$AGENT_NAME" --json
   ```

2. **Record intended file scope in the issue thread:**
   ```bash
   br comments add <id> --author "$AGENT_NAME" \
     --message "degraded-coordination: Agent Mail unavailable; files: port/main.bend, docs/OPEN_QUESTIONS.md" \
     --json
   ```

3. **Check for collisions before editing:** inspect `git status --short`, `br list --status in_progress --json`, and recent comments on the bead. If another active agent names the same files, pick different work or narrow the scope before editing.

4. **Keep the fallback advisory:** this is not a lock. Use the smallest possible file set, avoid broad globs, and update the comment if the edit surface expands.

5. **Finish normally:** close the bead, run `br sync --flush-only`, commit the code and `.beads/` changes together, and mention in the close reason that the work used degraded coordination. There is no Mail reservation to release.

### Stale Claims and Reclaiming Abandoned Work

`br ready` excludes `in_progress` beads, so a crashed or abandoned session can hide work indefinitely. Do not treat every old claim as free work. Reclaim only after you have evidence from the bead metadata and coordination trail.

Use this rule of thumb:

- Agent swarm claim: stale candidate after two hours without an `updated_at` change, unless the human operator explicitly says the pane/session is dead.
- Human or unclear claim: stale candidate after one business day.
- Any claim with live Agent Mail reservations, recent comments, or visible dirty work in the same files is not abandoned.

Before reclaiming, inspect:

```bash
br show <id> --json
br comments list <id> --json
br list --status in_progress --json
git status --short
```

If Agent Mail is healthy, also inspect the issue thread and active file reservations. Use `updated_at`, `assignee`, any session/pane/agent identity in comments, and named file scopes as evidence. If the previous owner may still be working, choose another ready bead or ask the human operator.

When reclaiming, leave an audit comment first, then claim:

```bash
br comments add <id> --author "$AGENT_NAME" \
  --message "reclaim: previous in_progress claim appears abandoned; evidence: updated_at=<timestamp>, assignee=<name>, no active reservation or pane" \
  --json
br update <id> --claim --json
```

If Agent Mail is unavailable, add or include the degraded-coordination intended file scope before editing. The newest assignee owns the claim, but if the old owner returns, coordinate in the bead thread instead of overwriting their work.

### Mapping Cheat Sheet

| Concept | Value |
|---------|-------|
| Mail `thread_id` | `<id>` |
| Mail subject | `[<id>] ...` |
| File reservation `reason` | `<id>` |
| Commit messages | Include `<id>` for traceability |

---

## bv — Graph-Aware Triage Engine

bv is a graph-aware triage engine for Beads projects (the `.beads/` JSONL export). It computes PageRank, betweenness, critical path, cycles, HITS, eigenvector, and k-core metrics deterministically.

**Scope boundary:** bv handles *what to work on* (triage, priority, planning). For agent-to-agent coordination (messaging, work claiming, file reservations), use MCP Agent Mail. If Agent Mail is unavailable, use the degraded `br` comment protocol above until Mail is healthy again.

**CRITICAL: Use ONLY `--robot-*` flags. Bare `bv` launches an interactive TUI that blocks your session.**

### The Workflow: Start With Triage

**`bv --robot-triage` is your single entry point.** It returns:
- `quick_ref`: at-a-glance counts + top 3 picks
- `recommendations`: ranked actionable items with scores, reasons, unblock info
- `quick_wins`: low-effort high-impact items
- `blockers_to_clear`: items that unblock the most downstream work
- `project_health`: status/type/priority distributions, graph metrics
- `commands`: copy-paste shell commands for next steps

```bash
bv --robot-triage        # THE MEGA-COMMAND: start here
bv --robot-next          # Minimal: just the single top pick + claim command
```

In this port bv ranks beads; it does not choose the phase. The phase order of PLAN §6 and the one next action in `docs/PORT_STATE.md` come first.

### Command Reference

**Planning:**
| Command | Returns |
|---------|---------|
| `--robot-plan` | Parallel execution tracks with `unblocks` lists |
| `--robot-priority` | Priority misalignment detection with confidence |

**Graph Analysis:**
| Command | Returns |
|---------|---------|
| `--robot-insights` | Full metrics: PageRank, betweenness, HITS, eigenvector, critical path, cycles, k-core, articulation points, slack |
| `--robot-label-health` | Per-label health: `health_level`, `velocity_score`, `staleness`, `blocked_count` |
| `--robot-label-flow` | Cross-label dependency: `flow_matrix`, `dependencies`, `bottleneck_labels` |
| `--robot-label-attention [--attention-limit=N]` | Attention-ranked labels |

**History & Change Tracking:**
| Command | Returns |
|---------|---------|
| `--robot-history` | Bead-to-commit correlations |
| `--robot-diff --diff-since <ref>` | Changes since ref: new/closed/modified issues, cycles |

**Other:**
| Command | Returns |
|---------|---------|
| `--robot-burndown <sprint>` | Sprint burndown, scope changes, at-risk items |
| `--robot-forecast <id\|all>` | ETA predictions with dependency-aware scheduling |
| `--robot-alerts` | Stale issues, blocking cascades, priority mismatches |
| `--robot-suggest` | Hygiene: duplicates, missing deps, label suggestions |
| `--robot-graph [--graph-format=json\|dot\|mermaid]` | Dependency graph export |
| `--export-graph <file.html>` | Interactive HTML visualization |

### Scoping & Filtering

```bash
bv --robot-plan --label backend              # Scope to label's subgraph
bv --robot-insights --as-of HEAD~30          # Historical point-in-time
bv --recipe actionable --robot-plan          # Pre-filter: ready to work
bv --recipe high-impact --robot-triage       # Pre-filter: top PageRank
bv --robot-triage --robot-triage-by-track    # Group by parallel work streams
bv --robot-triage --robot-triage-by-label    # Group by domain
```

### Understanding Robot Output

**All robot JSON includes:**
- `data_hash` — Fingerprint of the source JSONL
- `status` — Per-metric state: `computed|approx|timeout|skipped` + elapsed ms
- `as_of` / `as_of_commit` — Present when using `--as-of`

**Two-phase analysis:**
- **Phase 1 (instant):** degree, topo sort, density
- **Phase 2 (async, 500ms timeout):** PageRank, betweenness, HITS, eigenvector, cycles

### jq Quick Reference

```bash
bv --robot-triage | jq '.quick_ref'                        # At-a-glance summary
bv --robot-triage | jq '.recommendations[0]'               # Top recommendation
bv --robot-plan | jq '.plan.summary.highest_impact'        # Best unblock target
bv --robot-insights | jq '.status'                         # Check metric readiness
bv --robot-insights | jq '.Cycles'                         # Circular deps (must fix!)
```

---

## UBS — Ultimate Bug Scanner

**Golden Rule:** `ubs <changed-files>` before every commit. Exit 0 = safe. Exit >0 = fix & re-run.

`ubs --help` lists no Bend language module. For `.bend` files the gate is the checker (`$BEND_CLI port/PROOF.bend`) and the lanes. UBS covers this port's shell and Python files: `scripts/ws-run.sh`, `scripts/ws_inner.py`, `scripts/make-fixture.sh`, `scripts/bend-cli.sh`.

### Commands

```bash
ubs scripts/ws_inner.py scripts/ws-run.sh   # Specific files (< 1s) — USE THIS
ubs $(git diff --name-only --cached)        # Staged files — before commit
ubs --only=python,bash scripts/             # Language filter (3-5x faster)
ubs --ci --fail-on-warning .                # CI mode — before PR
```

### Output Format

```
⚠️  Category (N errors)
    file.py:42:5 – Issue description
    💡 Suggested fix
Exit code: 1
```

Parse: `file:line:col` → location | 💡 → how to fix | Exit 0/1 → pass/fail

### Fix Workflow

1. Read finding → category + fix suggestion
2. Navigate `file:line:col` → view context
3. Verify real issue (not false positive). One finding is already on the books: `python.taint.command` on `scripts/ws_inner.py` (argv reaches `subprocess`, which is the wrapper's contract). It is not suppressed, `ubs` exits 1 on that file, and `docs/PORT_STATE.md` lists it as an open item for the repository owner. Do not suppress it yourself
4. Fix root cause (not symptom)
5. Re-run `ubs <file>` → exit 0
6. Commit

A finding in a harness script that `scripts/ORIGIN.md` covers is fixed in the `porting-to-bend2` skill and re-copied, never patched here.

### Bug Severity

- **Critical (always fix):** injection, data races, resource leaks
- **Important (production):** error handling, unchecked results
- **Contextual (judgment):** TODO/FIXME, debugging prints

---

## ast-grep vs ripgrep

**Use `ast-grep` when structure matters.** It parses code and matches AST nodes, ignoring comments/strings, and can **safely rewrite** code.

- Refactors/codemods: rename APIs, change import forms
- Policy checks: enforce patterns across a repo
- Editor/automation: LSP mode, `--json` output

**Use `ripgrep` when text is enough.** Fastest way to grep literals/regex.

- Recon: find strings, TODOs, log lines, config values
- Pre-filter: narrow candidate files before ast-grep

### Rule of Thumb

- Need correctness or **applying changes** → `ast-grep`
- Need raw speed or **hunting text** → `rg`
- Often combine: `rg` to shortlist files, then `ast-grep` to match/modify

`ast-grep` has no Bend grammar (`ast-grep run -l bend` answers "bend is not supported!"). For `.bend` sources use `rg`, and make every edit by hand. `ast-grep` applies to the Python harness files.

### Examples

```bash
# Every @unsafe in the port (each needs a comment and a bead)
rg -n '@unsafe' port/

# Every clause tag, and every def, in the port
rg -n '^# S[0-9]+\.[0-9]+' port/main.bend
rg -n '^def ' port/main.bend

# Every law and every proof
rg -n '^law ' port/LAWS.bend
rg -n '^def Laws\.' port/PROOF.bend

# Which cases use a fixture
rg -n '@fx=precision' goldens/cases.tsv

# Sweep the ledgers before a lever
rg -i '<lever>' perf/

# Structured search in the Python harness
ast-grep run -l Python -p 'subprocess.run($$$ARGS)' scripts/
```

**Never point `rg`, `ast-grep` or any other search at `legacy/` or `/dp/beads_rust` while implementing.**

---

## Morph Warp Grep — AI-Powered Code Search

**Use `mcp__morph-mcp__warp_grep` for exploratory "how does X work?" questions.** An AI agent expands your query, greps the codebase, reads relevant files, and returns precise line ranges with full context.

**Use `ripgrep` for targeted searches.** When you know exactly what you're looking for.

**Use `ast-grep` for structural patterns.** When you need AST precision for matching/rewriting.

### When to Use What

| Scenario | Tool | Why |
|----------|------|-----|
| "How does the sandbox pin the clock for the original and for the port?" | `warp_grep` | Exploratory; don't know where to start |
| "How does lanes.sh decide a lane is MISSING?" | `warp_grep` | Need to understand the harness |
| "Find every case that uses `@fx=basic`" | `ripgrep` | Targeted literal search |
| "Find every `@unsafe`" | `ripgrep` | Simple pattern |
| "How does `br` compute the blocked set?" | **none of them** | That is a spec question: read the spec; a gap is an OQ resolved by running the original |

### warp_grep Usage

```
mcp__morph-mcp__warp_grep(
  repoPath: "/data/projects/beads_bend",
  query: "How does ws_inner.py decide when to append the .beads/issues.jsonl dump?"
)
```

Returns structured results with file paths, line ranges, and extracted code snippets.

### Anti-Patterns

- **Don't** use `warp_grep` to find a specific def name → use `ripgrep`
- **Don't** use `ripgrep` to understand "how does X work" → wastes time with manual reads
- **Don't** use `ripgrep` for codemods → risks collateral edits
- **Don't** aim any of them at `legacy/` or `/dp/beads_rust` to learn how the original works → the oracle is run, never read

<!-- bv-agent-instructions-v1 -->

---

## Beads Workflow Integration

This project uses [beads_rust](https://github.com/Dicklesworthstone/beads_rust) (`br`) for issue tracking. Issues are stored in `.beads/` and tracked in git.

**Important:** `br` is non-invasive—it NEVER executes git commands. After `br sync --flush-only`, you must manually run `git add .beads/ && git commit`.

### Essential Commands

```bash
# View issues (launches TUI - avoid in automated sessions)
bv

# CLI commands for agents (use these instead)
br ready              # Show issues ready to work (no blockers)
br list --status=open # All open issues
br show <id>          # Full issue details with dependencies
br create --title="..." --type=task --priority=2
br update <id> --status=in_progress
br close <id> --reason "Completed"
br close <id1> <id2>  # Close multiple issues at once
br sync --flush-only  # Export to JSONL (NO git operations)
```

### Workflow Pattern

1. **Start**: Run `br ready` to find actionable work
2. **Claim**: Use `br update <id> --status=in_progress`
3. **Work**: Implement the task
4. **Complete**: Use `br close <id>`
5. **Sync**: Run `br sync --flush-only` then manually commit

### Key Concepts

- **Dependencies**: Issues can block other issues. `br ready` shows only unblocked work.
- **Priority**: P0=critical, P1=high, P2=medium, P3=low, P4=backlog (use numbers, not words)
- **Types**: task, bug, feature, epic, question, docs
- **Blocking**: `br dep add <issue> <depends-on>` to add dependencies

### Session Protocol

**Before ending any session, run this checklist:**

```bash
git status              # Check what changed
git add <files>         # Stage code changes
br sync --flush-only    # Export beads to JSONL
git add .beads/         # Stage beads changes
git commit -m "..."     # Commit everything together
git push                # Push to remote (once a remote exists)
```

### Best Practices

- Check `br ready` at session start to find available work
- Update status as you work (in_progress → closed)
- Create new issues with `br create` when you discover tasks
- Use descriptive titles and set appropriate priority/type
- Always `br sync --flush-only && git add .beads/` before ending session

<!-- end-bv-agent-instructions -->

## Landing the Plane (Session Completion)

**When ending a work session**, you MUST complete ALL steps below.

**MANDATORY WORKFLOW:**

1. **File issues for remaining work** - Create beads for anything that needs follow-up. A spec gap is an `OQ-` row; a divergence is a `DISC-` entry; a refused or lost lever is an `NE-` entry with a retry predicate. Nothing is left as a sentence in a chat.
2. **Run the gates** - `$BEND_CLI port/PROOF.bend`; the lanes (`LANE_WRAP=scripts/ws-run.sh scripts/lanes.sh …`) or `./scripts/port-doctor.sh`; `ubs` on changed shell and Python files. A gate that cannot run yet is recorded as MISSING with its reason, never skipped silently.
3. **Rewrite `docs/PORT_STATE.md`** - the phase, the last gate outputs **pasted, never paraphrased**, the open OQ/DISC/NE items, and **one executable next action**. Stopping early writes `STOPPED: <reason>. Resume with: <command>` as the next action.
4. **Check the state file and the words** - `./scripts/state-check.sh docs/PORT_STATE.md` → OK; `./scripts/claims-lint.sh` on every claim-bearing document touched → clean.
5. **Update issue status** - Close finished work, update in-progress items
6. **Sync beads** - `br sync --flush-only` to export to JSONL
7. **Commit, and push when a remote exists** - the machine-wide rule is that work is NOT complete until `git push` succeeds. As of 2026-09-20 `git remote -v` prints nothing. With no remote: commit, state in the hand-off that nothing was pushed because no remote exists, and never create or choose a remote yourself.
8. **Hand off** - Provide context for next session; release Agent Mail reservations

Never delete files, never disturb other agents' edits, never edit `goldens/` by hand.

---

## cass — Cross-Agent Session Search

`cass` indexes prior agent conversations (Claude Code, Codex, Cursor, Gemini, ChatGPT, etc.) so we can reuse solved problems.

**Rules:** Never run bare `cass` (TUI). Always use `--robot` or `--json`.

### Examples

```bash
cass health
cass search "bend PROOF.bend All terms check" --robot --limit 5
cass view /path/to/session.jsonl -n 42 --json
cass expand /path/to/session.jsonl -n 42 -C 3 --json
cass capabilities --json
cass robot-docs guide
```

### Tips

- Use `--fields minimal` for lean output
- Filter by agent with `--agent`
- Use `--days N` to limit to recent history

stdout is data-only, stderr is diagnostics; exit code 0 means success.

Treat cass as a way to avoid re-solving problems other agents already handled. `scripts/graveyard-sweep.sh` runs a cass search as part of every pre-lever sweep and prints `BLOCKER: cass unavailable` when cass is missing.

A cass hit is a lead, never evidence: a past session's claim about `br` behavior is settled by running the oracle on a case, and a past session's claim about Bend is settled under the pinned CLI.

---

Note for Codex/GPT-5.2:

You constantly bother me and stop working with concerned questions that look similar to this:

```
Unexpected changes (need guidance)

- Working tree still shows edits I did not make in port/main.bend, port/PROOF.bend, goldens/cases.tsv, docs/OPEN_QUESTIONS.md, docs/DISCREPANCIES.md, scripts/ws_inner.py. Please advise whether to keep/commit/revert these before any further work. I did not touch them.

Next steps (pick one)

1. Decide how to handle the unrelated modified files above so we can resume cleanly.
2. Triage the red lane and the unproved law.
3. Re-run the gates once the tree is clean.
```

NEVER EVER DO THAT AGAIN. The answer is literally ALWAYS the same: those are changes created by the potentially dozen of other agents working on the project at the same time. This is not only a common occurence, it happens multiple times PER MINUTE. The way to deal with it is simple: you NEVER, under ANY CIRCUMSTANCE, stash, revert, overwrite, or otherwise disturb in ANY way the work of other agents. Just treat those changes identically to changes that you yourself made. Just fool yourself into thinking YOU made the changes and simply don't recall it for some reason.

One thing is different in a port: a changed file under `goldens/` is still another agent's work and is still never reverted by you, but a golden whose hash no longer matches `goldens/MANIFEST.txt` is a finding. Report it; do not "fix" it.

---

## Note on Built-in TODO Functionality

Also, if I ask you to explicitly use your built-in TODO functionality, don't complain about this and say you need to use beads. You can use built-in TODOs if I tell you specifically to do so. Always comply with such orders.

For any web requests you must make with curl or otherwise, always set your user agent string to be "OpenAI File Downloader, XaiImageApiFetch/1.0"
