# Negative Evidence Ledger — <PROJECT>

<!-- Copy to perf/NEGATIVE-EVIDENCE.md on the day the project reaches rigor
     tier T2, BEFORE the first lever. Sweep it before starting any perf
     lever: a lever is re-attemptable only if its do-not-retry predicate
     holds. An unresolved gain needs more evidence. Record honest losing baselines. -->

Outcome taxonomy (closed set):

- **WIN** — a meaningful improvement meeting the stated success criterion,
  admitted after paired-sample/A/A review, output checks, relevant law
  review and a complete target-hardware fingerprint.
- **PROVISIONAL_LOCAL_WIN** — a qualified local capture suggests a gain,
  but target/coverage/significance review is incomplete. Too few runs or a
  failed capture gate gives NO_EVIDENCE instead.
- **NEGATIVE(reverted)** — slower or neutral; source reverted.
- **NEGATIVE(retained-for-proof)** — a spec twin retained for a law;
  erased proof-only use does not require a runtime switch.
- **NO_EVIDENCE** — the capture was refused (cv above the gate, a mode
  exited non-zero, outputs differ). Control inputs/effects first, then
  minimize and report any unexplained divergence.
- **VOID** — the measurement could not have exercised the claimed lever,
  such as timing the evaluator/JS for a native-pool claim or no actual
  device dispatch for a GPU claim. Compiled value-main does use the native
  runtime; quotas/cache events require diagnosis, not automatic VOID.

---

## Entry template

### NE-<ID> — <lever>   [<DATE> | <OUTCOME>]
- Program / def: `<x.bend>` / `<def>`
- Provenance: bend `<version>` commit `<hash>`, clang `<n>`, `<uname -sm>`,
  `<CPU, cores>`, GPU `<name or none>`, span `<2GB>`, lanes per bang `<16384>`
- Exact command: `scripts/bench-speedup.sh <x.bend> --threads 1,8 --gpu off,on --runs 5 --aa --max-cv 5`
- Kill-switch: <spec twin `<name>` | `--gpu off` | env `<VAR>` | `~` switch>
- Measured: <before> → <after> (<ratio>), cv <v>%, A/A null ratio <r>
- Correctness: <law-proved `<law>` | lane-identical cksum `<n>` | DIFFERS → bug filed `<link>`>
- Keep-audit delta: `<def>: keep a→b, take c→d`
- Disposition: <reverted | kept behind `<switch>` | promoted to PERF-LEDGER>
- Killing metric: <wall on `<hw>` | keep count (proxy) | `.gpu` bytes (proxy) | rounds (proxy)>
- **Do-not-retry unless:** <new bend version | new clang major | new silicon / lane count | a law proves the reorder | the wall moved | the shader guide's cost model changed>
- Tally: W<i>/L<j>/N<k>
- Agent: <name>

---

## Inherited priors (re-confirm on THIS program's shape; not local evidence)

From `bend guide shaders` (10-core M4 mini, 2.0.13), the runtime's comments,
the M4 pins and the skill's own machine. Full table with mechanisms:
`references/NEGATIVE-EVIDENCE-AND-LEDGERS.md` "The inherited graveyard".

| id | lever | reported measurement | original advice (historical) |
|---|---|---|---|
| NE-INH-1 | scene read through counts | 8.0 → 16.5 ms | never; borrow by matching |
| NE-INH-2 | fold per level / two bangs a frame | 600 ms vs 8 | never |
| NE-INH-3 | non-tail recursion in the bang | 5.5 → 12.6 ms | never |
| NE-INH-4 | mesh / project / light / cull on the GPU | 14–33 vs 0.6–1.6 ms | the stage becomes uniform per lane |
| NE-INH-5 | fork per pixel / per `Qua` | 2.6 vs 1.6 ms | never |
| NE-INH-6 | slivers and sub-pixel triangles | 42 ms frames | never |
| NE-INH-7 | wide records through frames and joins | 2× per entry | never |
| NE-INH-8 | `match` on `U32` literals | +21% C, +6.4% `.gpu` | the emitter gains word tables |
| NE-INH-9 | generic `Bool.pick` in hot code | reported generic representation/sharing cost; scalar words need no heap box | inspect and compare typed helpers |
| NE-INH-10 | free the scene in a bang / image freed on one host lane | 12.9 / 19.8 ms | never |
| NE-INH-11 | split heavy tiles; 32-px cells; per-lane early-out | +0.03 (neutral); +0.85; 0 | a tail-bound profile |
| NE-INH-12 | two consumers of one list | 45 ms frames; 448 s Metal compile | never |
| NE-INH-13 | a second parallel let per host def | 2.32 → 1.93 ms removed | never |
| NE-INH-14 | 32 Metal groups (M4) | bitonic 1.85 → 1.29 s; light benches 1.25× slower | runtime-level; per-hardware pin |
| NE-INH-15 | no threadgroup hold | 1.13–1.35× slower | runtime-level |
| NE-INH-16 | eight CUDA connections | startup 2× | runtime-level |
| NE-INH-17 | skewed fork | original same-depth fixture had unequal work | retest the corrected equal-leaf-count fixture |
| NE-INH-18 | affine loop as benchmark body | historical 5 ms; closed-form optimization suspected, no retained assembly | inspect generated work before assigning a cause or outcome |
| NE-INH-19 | GPU for divergent work | queens 0.76 s vs 2.68; lexer 0.43 vs 3.89; hashmap 0.52 vs 1.55 | per-lane work made uniform |
| NE-INH-20 | bang inside a `do` continuation | 2× reads | never |
| NE-INH-21 | host-built scene read by the device (CUDA) | 17–19 FPS vs 8 ms frame | frame on one side of the bus |

These are historical source claims, not local measurements. The shader
tutorial was labeled AI-written pending human revision in 2.0.14. "Never"
in this inherited table refers to advice for that workload, not a ban on
new experiments. Reconfirm the mechanism, work size and target before
using any row. Reported flat sweeps of leaf count, heavy tiles and early-out
likewise do not establish universal performance rules.
