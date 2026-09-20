# Plan to port BEADS_RUST to Bend 2

<!-- Phase 0 document. Filled before the spec; amended (never silently
     rewritten) as the port learns. Every number here is a gate somewhere. -->

## 1. Purpose

`br` (beads_rust) is a local-first issue tracker for git repositories, used
mostly by AI coding agents: issues with priorities, types, labels, comments
and typed dependencies; `ready`/`blocked` queries over the dependency graph;
a git-friendly `.beads/issues.jsonl` export. The original keeps its primary
state in a SQLite database (the pure-Rust `fsqlite` engine) and mirrors it to
JSONL. It also ships a JSONL-only mode, `br --no-db`, in which
`issues.jsonl` is the whole store: every invocation loads it, answers, and
(for mutations) writes it back.

This port implements that JSONL-only contract natively in Bend 2. Bend has no
SQLite binding and no subprocess effect, so the DB-backed paths are outside
what a Bend shell can carry (§3); the JSONL contract is the part of beads that
other tools (`bv`, git merges, agents reading `--json`) actually consume.
What the port buys from Bend: byte-identical behavior on every lane
(interpreter, C at 1 and N threads, JS) against captured goldens, and
law-proved equivalence for every optimized twin (id hashing, sorting,
blocked-set propagation, JSON encoding) introduced in Phase 5.

## 2. The original, pinned (the truth pack)

| field | value |
|---|---|
| repository / path | `legacy/BEADS_RUST` → `/dp/beads_rust` (gitignored symlink; an oracle, never a template). The live tree is 271 commits past the pin and is edited concurrently by other agents: it is NOT the oracle. Spec citations use the tag (`git -C /dp/beads_rust show v0.6.0:<path>`) |
| commit / version | `b1cfebe05437463e91a353cf2bedafac27266f5b` / `br 0.6.0` (tag `v0.6.0`; `br version --json` reports this commit, branch `v0.6.0`, build `release`, features `["self_update"]`, target `x86_64-unknown-linux-gnu`) |
| oracle artifact | the published release binary `~/.local/bin/br`, 27,772,512 bytes, sha256 `21b967c1ae68df1a2e8eb2256d13b8e57d293d89e331933919076104832ddbc0` (size matches the README's v0.6.0 x86_64 GNU figure) |
| toolchain to build it | not rebuilt: the release artifact is the strong build (`rust_version 1.100.0-nightly`, release profile). Rebuilding HEAD would change the pin |
| run command | `br --no-db <args>` inside the pinned environment below (wrapper: `scripts/oracle.sh`, Phase 0) |
| pinned environment | `bwrap --die-with-parent --bind / / --tmpfs /mnt --chdir /mnt --clearenv` with `PATH`, `HOME=/mnt/home`, `USER=tester`, `TZ=UTC`, `NO_COLOR=1`, `RUST_LOG=error`; workspace always `/mnt/proj` (so `source_repo_path` is `/mnt/proj` and the derived prefix is `proj`); clock: `LD_PRELOAD=toolchain/faketime/root/usr/lib/x86_64-linux-gnu/faketime/libfaketime.so.1` (libfaketime 0.9.10, sha256 `062ef5e61774186b…`), `FAKETIME=<absolute>`, `DONT_FAKE_MONOTONIC=1` |
| why the environment is pinned | `br` has no fixed-clock override; ids are SHA-256 over title, description, creator, `created_at` nanoseconds and a nonce, so every `create` differs by wall clock. `create` also writes the absolute workspace path into the record. Measured 2026-09-20: two pinned runs byte-identical (`proj-vrm`); a fully frozen clock (monotonic faked too) hangs `br`, hence `DONT_FAKE_MONOTONIC=1` |
| threads / parallelism it uses | single-threaded per invocation for the in-scope surface (JSONL export has a parallel path, `BR_DISABLE_PARALLEL_JSONL_EXPORT`; to be measured in Phase 5) |
| nondeterminism floor | pending Phase 0: `scripts/floor.sh --repeat 3` over the captured cases |
| goldens | pending Phase 0: `goldens/cases.tsv`, `goldens/MANIFEST.txt` |
| rigor tier | **T3 system** (≈45 commands, a data format, a graph query semantics): ≥ 10 rounds, 2 consecutive clean, non-author rounds, stage goldens |

### 2b. Bend, pinned (VERSION-DRIFT)

| field | value |
|---|---|
| `bend version` | `bend 2.0.20` (2.0.17 replaced `bend --version` with `bend version`; `scripts/bend-cli.sh` translates that one spelling so the harness runs unmodified: `export BEND_CLI=/data/projects/beads_bend/scripts/bend-cli.sh`) |
| how obtained | official installer `https://bend-lang.com/install.sh` (script sha256 `7801aa7f12dd02d0…`) on 2026-09-20 → `~/.bend/bin/bend`, sha256 `fab9e564c578a0a15880d5fea561ac1612dba01265a5a219906b5888f3381d8c`. Retained release artifact: `toolchain/bend-2.0.20-linux-x64.tar.gz`, sha256 `dca589832e1645500ad258d27171ed6b5a30812bcc3088c9aedf437059be41e1` (equals the installer's `SHA_LINUX_X64`). Matching source for the Bun tools: `toolchain/bend-v2.0.20-src/` (tag tarball sha256 `aed470331b14a297…`). `toolchain/` is gitignored |
| bun / clang | `1.4.2` / `Ubuntu clang version 21.1.8 (6ubuntu1)`; host `Linux x86_64`, 8 cores; no CUDA (a `!` runs on the CPU pool: gpu lane MISSING) |
| verdict under this pin | scaffolded `port/PROOF.bend`: `All terms check.` (0 `@unsafe`). Since 2.0.17 a template instance no longer counts as unsafe and the verdict names the defs that rely on `@unsafe` or a foreign def |
| drift check | both skills were verified on 2.0.13/2.0.16. Against 2.0.16 (`toolchain/bend-981899d`, tree sha256 `75138be62e272ce9…`) on 2026-09-20: `guide/GUIDE.md`, `EFFECTS.md` identical; `base.bend` differs in 62 lines; effects gained `tcp_poll`; CHANGELOG 2.0.17 breaking change (an operator takes its type only from its own `( .. : T)`; a bare operator is no longer `Nat`). Evidence that the documented idioms survive: the porting skill's 32 cookbook probes `PASS` 32/32 on the interpreter and 32/32 on the C lane under 2.0.20. `version-drift.sh` proper runs once the port has gates to compare |

## 3. Scope

The port's contract is **`br --no-db`**: same argv, same stdout, stderr and
exit code, same resulting `.beads/issues.jsonl` bytes, in Plain and JSON
output modes.

### In scope (each row becomes rows in FEATURE_PARITY.md)

| surface | original entry point | notes |
|---|---|---|
| workspace discovery, `where`, `version` | `src/config/mod.rs`, `cli/commands/where.rs` | walk up for `.beads/`; `BEADS_DIR`; prefix from directory name or `config.yaml` |
| JSONL load / normalize / validate | `src/sync/mod.rs`, `src/model/mod.rs`, `src/validation/mod.rs` | struct-ordered keys, omitted optionals, `compaction_level` always emitted, RFC 3339 AutoSi timestamps, conflict-marker refusal |
| JSONL write-back | `src/sync/mod.rs` export | lines by id ascending (byte order); labels, dependencies, comments normalized; ephemeral and `-wisp-` ids excluded |
| id generation | `src/util/id.rs` | SHA-256 seed → first 8 bytes → base36 → last `len` chars; adaptive length (3–8) from the issue count; nonce ladder; child ids `<parent>.<n>` |
| content hash | `src/util/hash.rs` | SHA-256 over u64-LE length-prefixed fields |
| `create`, `q` | `cli/commands/create.rs`, `q.rs` | flags for type, priority, labels, assignee, description, deps, parent |
| `update`, `close`, `reopen`, `defer`, `undefer`, `delete` | `update.rs`, `close.rs`, `reopen.rs`, `defer.rs`, `delete.rs` | status rules, `closed_at` invariant, tombstones, `last-touched` |
| `show`, `list`, `search`, `count`, `stats` | `show.rs`, `list.rs`, `search.rs`, `count.rs`, `stats.rs` | filters, sort keys with id tie-break, `{issues,total,limit,offset,has_more}` envelope |
| `ready`, `blocked` | `ready.rs`, `blocked.rs`, `storage/sqlite.rs` blocked map | blocking types `blocks`, `conditional-blocks`, `waits-for`; parent→child propagation; epics blocked by open children; hybrid sort |
| `dep add/remove/list/tree/cycles` | `dep.rs`, `validation/mod.rs` | cycle refusal, self-dependency, duplicate edge |
| `label add/remove/list/list-all/rename`, `comments add/list` | `label.rs`, `comments.rs` | label charset and limits; comment identity |
| `epic status/close-eligible` | `epic.rs` | |
| errors and exit codes | `src/error/structured.rs`, `src/main.rs` | codes 0–8; pretty-printed `{"error":{…}}` on stdout in JSON mode; `Error:`/`Hint:` on stderr otherwise |
| output modes Plain, JSON, Quiet | `src/output/context.rs`, `src/format/` | piped stdout is Plain; glyph lines (`✓ ○ ●`) |

### Excluded (each row is debt or infeasibility, never "later")

| feature | reason | class | debt? |
|---|---|---|---|
| the SQLite store: `beads.db`, the default (non `--no-db`) mode, auto-import/auto-flush, dirty tracking, blocked cache table | the `fsqlite` engine (~54K lines of storage and schema) reaches every DB path; Bend has no SQLite binding and the file format is not golden-able through the shell | external-dependency | no |
| `doctor` (all subcommands), schema migration, `sync --import-only/--rebuild/--merge/--reconcile*`, `history` | repair and reconcile a SQLite database against JSONL | external-dependency | no |
| `init` creating `beads.db` | same; the port's `init` writes the JSONL-side files only (a DISC, Phase 4) | external-dependency | no |
| `serve` (MCP) | not compiled into the pinned binary (`features: ["self_update"]`): there is no oracle to capture | out-of-scope | yes |
| `upgrade`, `completions`, `agents`, `config edit` | network self-replacement, shell integration, `$EDITOR` subprocess | platform | no |
| `changelog`, `orphans`, `vcs-status`, commit activity in `stats` | run `git` as a subprocess; Bend has no subprocess effect | external-dependency | no |
| Rich (TTY) output | terminal detection and ANSI tables; a captured run is piped, hence Plain | platform | no |
| TOON output (`--format toon`, `BR_OUTPUT_FORMAT=toon`) | the `tru` encoder; reimplementable, not in the first certification | out-of-scope | yes |
| cross-process write locks, opener leases, the inode lock | `fcntl` byte locks and lock-file queues; Bend has no lock effect. The port is single-writer per invocation (a DISC with its impact stated) | concurrency-observable | no |
| temp file + `RENAME_EXCHANGE` publication, fsync, `.br_history/` backups | Bend's file effects are open/read/write/close; no rename or fsync | platform | yes (a custom effect would repay it) |
| `audit`, `capacity`, `gate`, `coordination`, `scheduler`, `query`, `lint`, `stale`, `graph`, `info`, `schema`, `capabilities`, `robot-docs`, `config list/get/set` | feasible; outside the first certification's surface | out-of-scope | yes |
| close policy workflows (`strict` transitions, gates, required fields) | configured per workspace in `config.yaml`; the default (non-strict) behavior is in scope | out-of-scope | yes |
| `clap` help and usage texts beyond the captured error shapes | generated by the argument-parser library; captured cases pin what is reproduced | external-dependency | yes |

## 4. Reference Bend programs (imitate, do not invent)

- `bend2-mega-skill/assets/skeletons/cli_tool.bend` (args, exit codes, files)
- `bend2-mega-skill/assets/skeletons/laws_proof/` (LAWS/PROOF split)
- `bend2-mega-skill/assets/skeletons/parallel_kernel.bend` (balanced fork, one bang)
- `porting-to-bend2/assets/example-port/` (a complete port with goldens, laws and a fast twin)
- to be chosen in Phase 2 from REPO-CORPUS-FOR-PORTERS: a JSON or text-parsing program and a hashing kernel in `toolchain/bend-v2.0.20-src/{demos,bench,tests}`

## 5. Success criteria (numbers, each a gate)

| criterion | target | gate |
|---|---|---|
| conformance | 100% of the captured cases on interpreter, C 1T, C NT, JS (gpu MISSING: no device) | `scripts/lanes.sh` PASS |
| proofs | `All terms check.`; every `@unsafe` named with its measure | `bend port/PROOF.bend` |
| parity board | DEBT with every exclusion above listed (FULL is not reachable: the SQLite rows are infeasible by class) | `scripts/parity-board.sh` |
| discrepancies | every divergence a DISC entry with a kill-switch | `docs/DISCREPANCIES.md` |
| performance (after parity) | measured against `br --no-db` at thread parity, cv ≤ 5%; no ratio is promised before it is measured | `scripts/incumbent-bench.sh --pin` |
| ledgers | every lever an experiment card and an outcome | `perf/` |

## 6. Phases and their artifacts

| phase | artifact | gate to leave |
|---|---|---|
| −1 fit screen | this file §3 and §7 | no infeasible feature in scope without an exclusion row |
| 0 truth pack | §2, goldens, MANIFEST, floor | floor STABLE (or DISC per unstable case) |
| 1 spec | `docs/EXISTING_BEADS_RUST_STRUCTURE.md` | spec self-containment review passed |
| 2 architecture | `docs/PROPOSED_ARCHITECTURE.md`, `docs/NUMERIC_PLAN.md`, `port/LAWS.bend` draft | every spec clause has a home (def) and an evidence kind (law/golden) |
| 3 reference port | `port/main.bend` spec twins, `port/PROOF.bend` | lanes PASS, All terms check. |
| 4 parity gate | `docs/FEATURE_PARITY.md`, DISC register, find-fix rounds | parity DEBT, convergence rule met |
| 5 performance | fast twins, `perf/` ledgers, incumbent numbers | every kept lever law-bound, cv-gated, ledgered |
| 6 certify | `docs/PORT_REPORT.md`, evidence bundle | claims taxonomy complete; SHIP/HOLD/BLOCK |

## 7. Risks and unknowns

| risk | where it bites | mitigation |
|---|---|---|
| the original has no clock seam; the port needs one to be golden-tested | every mutating case | oracle pinned with libfaketime (§2); the port reads a pinned instant from an environment variable in the shell only (a DISC of class test-seam, with the variable as its switch) |
| timestamp precision: `br` prints nanoseconds (AutoSi 0/3/6/9 digits); Bend's `now` effect precision is to be probed | unpinned runs only | NUMERIC_PLAN row; a DISC if the effect is coarser than nanoseconds |
| SHA-256 and a 64-bit → base36 conversion | ids, content hash | `U32` words for SHA-256 (bit-exact wrapping); the 8-byte value as two `U32` words with long division by 36; closed laws against published test vectors |
| `optimal_length` uses `f64` `exp` in a birthday bound | id length at issue-count thresholds | the predicate over integer `n` and `len ∈ 3..8` is a finite table; thresholds (n ≤ 163 at len 3, ≤ 983 at len 4, …) confirmed by boundary goldens, never by `F32` |
| JSON fidelity with `serde_json`: escaping, key order, omitted optionals, `Some("")` kept, unknown fields | every line of `issues.jsonl` and every `--json` output | a byte-exact encoder and a total decoder in the core; round-trip law `decode(encode(x)) == x`; encoding goldens (control characters, non-ASCII, surrogates) |
| order semantics inherited from SQL: `ORDER BY` on TEXT timestamps compares strings, not instants (mixed precision: `…05Z` sorts after `…05.1Z`); `COLLATE NOCASE` on titles | `list`, `ready`, `blocked` ordering | OQ resolved by running the original on mixed-precision fixtures; the comparator is specified from the captured order |
| `clap` argument parsing: abbreviations, `--flag=value`, combined shorts, error and suggestion texts, exit code 2 | every command | `argv-explore.sh` maps the signatures; the spec pins the reproduced subset; the rest is the exclusion row above |
| JS lane deep recursion; `Nat` ≤ 2^48−1; arity ≤ 255 | large `issues.jsonl` (the original's own is 4.5 MB); the 44-field Issue record | stack-safe folds; a large-input case on every lane; records compile since 2.0.19 (#843) |
| sidecars the original leaves in `.beads/` (`last-touched`, lock files, `.br_history/`) | `update`/`close` without an id read `last-touched` | `last-touched` in scope; the lock and history sidecars are exclusions |
| crash safety: no atomic rename in Bend's file effects | a kill during write-back can truncate `issues.jsonl` | exclusion row (debt: yes); stated in the README; a custom effect is the repayment |
| bug-compatibility versus fixes | every divergence | default bug-compatible; the DISC approver is the repository owner |
