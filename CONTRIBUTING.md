# Contributing to the Bend 2 port of BEADS_RUST

<!-- Phase 6 output for a port that will outlive its authors (SHIP-AND-CERTIFY
     "What to ship"). AGENTS.md is the agent-facing mandate; this is the
     human contributor's version of the same rules. The remaining `<…>` words
     below are syntax placeholders inside commands, not unfilled fields. -->

> **Outside contributions are not merged.** The owner's policy, stated in `README.md` ("About Contributions"), applies here:
> issues are welcome, and a PR may illustrate a proposed fix, but it will not be merged. This file is the working
> agreement for the people and agents who DO change this repository: the owner and the agents working for them.
> `AGENTS.md` is the agent-facing version of the same rules.

## 1. The two equivalences

The port is correct in two separable senses, and every claim says which one
it rests on. **original == spec** is golden-tested: `goldens/` holds the
original's captured stdout, stderr and exit code per case, and
`./scripts/lanes.sh` compares the port with them byte for byte on every lane
(interpreter, C at 1 and N threads, JS, the device when a bang exists).
**spec == fast** is law-proved: every fast twin is bound to its spec twin in
`port/LAWS.bend` and `bend port/PROOF.bend` prints `All terms check`. The
original under `legacy/` is an oracle to run, never a template to read: a
spec gap is an `OQ-` row resolved by running it on a new case.

## 2. Adding a case

1. Add a row to `goldens/cases.tsv`: `name<TAB>args[<TAB>stdin-file]`; the
   name is an identifier and is never renamed later.
2. `./scripts/cases-lint.sh goldens/cases.tsv` → OK.
3. `./scripts/golden-capture.sh goldens/cases.tsv goldens --repin "new case <name>" -- scripts/ws-run.sh --oracle br --no-db ::` (`<name>` is the new case's name);
   the printed MANIFEST diff must name only the new case.
4. Name the case in the spec clause it exercises (`docs/EXISTING_BEADS_RUST_STRUCTURE.md`).
5. `./scripts/lanes.sh goldens/cases.tsv goldens port/main.bend` → PASS, or the failure is your finding.

Goldens are never typed or edited by hand.

## 3. Proposing a law

Append `# PROPOSED: <law text>` to `port/LAWS.bend` with the clause it
proves (`# S<n>.<m>`); the law owner (the repository owner, @Dicklesworthstone) promotes it and the prover
fills `def Laws.<name>` in `port/PROOF.bend`. Laws are never weakened or
deleted. `./scripts/law-coverage.sh` must stay OK.

## 4. Filing a divergence (DISC)

Bug-compatibility is the default. A deliberate divergence is an entry in
`docs/DISCREPANCIES.md` with class, spec clause, original behavior (the
golden), port behavior, kill-switch, affected cases and measured impact,
approved by the repository owner, @Dicklesworthstone (never its implementer), then re-captured through
its wrapper with `--disc DISC-<n>`. Until accepted it is a bug.

## 5. Proposing a performance lever

Not before the parity gate. Then: `./scripts/graveyard-sweep.sh "<lever>"`,
the card in `perf/EXPERIMENTS.md` before the code, the fast twin behind
`BEADS_RUST_SPEC=1`, the `{fast == spec}` law proved, `keep-audit`, a capture with
the cv gate (`--aa --max-cv 5`), the ledger entry (a loss is
`perf/NEGATIVE-EVIDENCE.md` with a retry predicate), `lanes.sh` again. A
refused capture is NO_EVIDENCE, not a number.

## 6. What a pull request shows

Pasted, never paraphrased: the `lanes.sh` JSON line, the `bend port/PROOF.bend`
last line with `bend --version`, the `parity-board.sh` verdict line, and, for
a lever, the bench JSON line and the ledger entry. `./scripts/claims-lint.sh`
clean on every document touched. CI (`.github/workflows/port-gates.yml`) runs
the same gates; a red gate is not negotiated, it is fixed or the PR waits.
