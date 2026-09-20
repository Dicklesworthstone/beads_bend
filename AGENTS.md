# AGENTS.md — the Bend 2 port of BEADS_RUST

Read this whole file, then `docs/PORT_STATE.md`, before any work.

## The two equivalences (never conflated)

1. **original == spec** is *golden-tested*: `goldens/` holds the original's
   captured stdout, stderr and exit code per case in `goldens/cases.tsv`;
   `scripts/lanes.sh` must pass on every lane (interpreter, C at 1 and N
   threads, JS, the device when a bang exists). A failing case is a port
   bug or a spec gap, never a tolerance.
2. **spec == fast** is *law-proved*: every fast twin is bound to its spec
   twin in `port/LAWS.bend`, and `bend port/PROOF.bend` (`$BEND_CLI
   port/PROOF.bend` when a non-default CLI is set) must print
   `All terms check.` The unsafe count from that output and `bend --version`
   are stated beside every parity or performance claim.

A claim says which equivalence it rests on. "Proved" means a law; "golden-
tested" means the harness on named lanes; "measured" means an interleaved,
cv-gated capture with a checksum. Nothing else is a claim.

## Gates (paste their last lines into PORT_STATE; never paraphrase)

| gate | command |
|---|---|
| everything at once | `./scripts/port-doctor.sh --threads <N> --original <original cmd> -- --switch BEADS_RUST_SPEC=1 --probe "<hot args>"` (proof, lanes, board, floor, kill-switch parity; last line JSON, verdict GREEN or RED) |
| one failing case | `./scripts/first-divergence.sh <case> goldens/cases.tsv goldens -- <port command>` (the divergence class and the spec section to read) |
| convergence | `./scripts/converge.sh docs/PORT_STATE.md` (computed from the rounds table and the OQ/DISC registers beside it) |
| the state file | `./scripts/state-check.sh docs/PORT_STATE.md` before ending a session (no placeholders, gate lines pasted, one executable next action) |
| the words | `./scripts/claims-lint.sh docs/*.md perf/*.md README.md` before committing any claim |

## Hard rules

- The original under `legacy/` is a behavior **oracle**, not a template.
  Implementation reads `docs/EXISTING_BEADS_RUST_STRUCTURE.md` (the spec). A spec
  gap is an `OQ-` entry in `docs/OPEN_QUESTIONS.md`, resolved by *running*
  the original on a new case and capturing it, then amending the spec.
- Goldens are captured, never typed or edited. Re-capture only when the
  contract changes (a new original commit, or an accepted `DISC-` entry),
  never to make a red case green. Every re-capture diffs `MANIFEST.txt`.
- Bug-compatibility is the default. A deliberate divergence from the
  original is a `DISC-` entry in `docs/DISCREPANCIES.md` with a class, a
  kill-switch, the affected cases and a measured impact. No silent fixes.
- `port/LAWS.bend` is human-owned: add laws, never weaken or delete one.
  A law the checker cannot prove is a finding about the code or the spec.
- `@unsafe` needs a comment naming the measure that was not expressible
  and a bead; the count is reported, never hidden.
- Before any performance lever: sweep `perf/NEGATIVE-EVIDENCE.md`
  (`rg -i '<lever>' perf/`) and honor the retry predicate; write the
  experiment card in `perf/EXPERIMENTS.md` **before** the lever; capture
  with the cv gate and the A/A arm; a refused capture is `NO_EVIDENCE`.
  Every outcome, including losses, gets a ledger entry with a retry
  predicate. Forbidden in ledgers: "later", "if it seems important", "we should revisit", "tracked elsewhere".
- A speedup number against the original needs the incumbent contract in
  `docs/PLAN_TO_PORT_BEADS_RUST_TO_BEND2.md` (commit, toolchain, flags, threads)
  and `scripts/incumbent-bench.sh` with `--pin`; otherwise it is a
  maintenance number.
- Never delete files, never disturb other agents' edits, never edit
  `goldens/` by hand. `docs/PORT_STATE.md` is updated at the end of every
  session with the phase, the last gate outputs and the next action.
