# Plan to port BEADS_RUST to Bend 2

<!-- Phase 0 document. Filled before the spec; amended (never silently
     rewritten) as the port learns. Every number here is a gate somewhere. -->

## 1. Purpose

One paragraph: what BEADS_RUST does, who runs it, and why a Bend 2 port (which of
the three Bend properties the port is buying: proved fast twins, byte-
identical lanes, one C file for CPU/GPU).

## 2. The original, pinned (the truth pack)

| field | value |
|---|---|
| repository / path | `legacy/BEADS_RUST` (gitignored; an oracle, never a template) |
| commit / version | `<sha>` / `<version>` |
| toolchain to build it | `<compiler or interpreter and version>` |
| build command | `<exact>` |
| run command | `<exact, as used in goldens/MANIFEST.txt>` |
| threads / parallelism it uses | `<n or "single-threaded">` |
| nondeterminism floor | `scripts/floor.sh` over `<k>` runs: `<n stable / m unstable>` (unstable cases: see DISC) |
| goldens | `goldens/cases.tsv` (`<n>` cases), `goldens/MANIFEST.txt` sha256 `<first 16>` |
| rigor tier | T1 script-sized · T2 tool · T3 system (sets convergence minimums; see SKILL.md) |

### 2b. Bend, pinned (VERSION-DRIFT)

| field | value |
|---|---|
| `bend --version` | `<bend 2.0.x>` |
| how obtained | `<release binary (bend update, date)>` or a checkout at `<sha>` run as `bun <dir>/bend2/main.ts` (a checkout pin needs the sha: `--version` is a constant) |
| bun / clang | `<bun --version>` / `<clang --version \| head -1>` |
| verdict under this pin | `<All terms check[, with N unsafe annotations].>` = `<a>` @unsafe + `<b>` template instances (`scripts/list-instances.ts`) |
| drift check | `scripts/version-drift.sh --old "<previous cli>" --new "<this cli>"` → `<SAME \| DRIFT: …>` on `<date>` |

## 3. Scope

### In scope (each row becomes rows in FEATURE_PARITY.md)

| surface | original entry point | notes |
|---|---|---|
| `<command or API>` | `<file:function>` | |

### Excluded (each row is debt or infeasibility, never "later")

| feature | reason | class | debt? |
|---|---|---|---|
| `<feature>` | `<why>` | infeasible-numeric (U64/F64 needed) · mutation-dependent · exception-dependent · external-dependency · platform · out-of-scope | yes/no |

## 4. Reference Bend programs (imitate, do not invent)

- `bend2-mega-skill/assets/skeletons/cli_tool.bend` (args, exit codes, files)
- `bend2-mega-skill/assets/skeletons/laws_proof/` (LAWS/PROOF split)
- `bend2-mega-skill/assets/skeletons/parallel_kernel.bend` (balanced fork, one bang)
- `porting-to-bend2/assets/example-port/` (a complete port with goldens, laws and a fast twin)
- `<a Bend program in bendlang/bend demos/ or bench/ that resembles BEADS_RUST>`

## 5. Success criteria (numbers, each a gate)

| criterion | target | gate |
|---|---|---|
| conformance | 100% of `<n>` cases on interpreter, C 1T, C NT, JS (device if bang) | `scripts/lanes.sh` PASS |
| proofs | `All terms check.`, unsafe count ≤ `<k>` | `bend port/PROOF.bend` |
| parity board | FULL (or DEBT with every exclusion listed above) | `scripts/parity-board.sh` |
| discrepancies | every divergence a DISC entry with a kill-switch | `docs/DISCREPANCIES.md` |
| performance (after parity) | `<ratio>`× vs the original at thread parity, cv ≤ 5% | `scripts/incumbent-bench.sh --pin` |
| ledgers | every lever an experiment card and an outcome | `perf/` |

## 6. Phases and their artifacts

| phase | artifact | gate to leave |
|---|---|---|
| −1 fit screen | this file §3 and §7 | no infeasible feature in scope without an exclusion row |
| 0 truth pack | §2, goldens, MANIFEST, floor | floor STABLE (or DISC per unstable case) |
| 1 spec | `docs/EXISTING_BEADS_RUST_STRUCTURE.md` | spec self-containment review passed |
| 2 architecture | `docs/PROPOSED_ARCHITECTURE.md`, `docs/NUMERIC_PLAN.md`, `port/LAWS.bend` draft | every spec clause has a home (def) and an evidence kind (law/golden) |
| 3 reference port | `port/main.bend` spec twins, `port/PROOF.bend` | lanes PASS, All terms check. |
| 4 parity gate | `docs/FEATURE_PARITY.md`, DISC register, find-fix rounds | parity FULL/DEBT, convergence rule met |
| 5 performance | fast twins, `perf/` ledgers, incumbent numbers | every kept lever law-bound, cv-gated, ledgered |
| 6 certify | `docs/PORT_REPORT.md`, evidence bundle | claims taxonomy complete; SHIP/HOLD/BLOCK |

## 7. Risks and unknowns

| risk | where it bites | mitigation |
|---|---|---|
| 64-bit or float arithmetic in the original | NUMERIC_PLAN | two-word U32 with round-trip laws / declared F32 budget class |
| iteration-order leaks (dict/map/set) | spec §6 | explicit order carried beside the Map; stable sort with the original's tie-break |
| exceptions as control flow | core/shell split | Result/Maybe in the core; the shell maps to exit codes |
| loops without an evident measure | translation | fuel or structural descent; `@unsafe` counted, never hidden |
| original is nondeterministic | truth pack | floor.sh; canonicalizing wrapper as a DISC |
