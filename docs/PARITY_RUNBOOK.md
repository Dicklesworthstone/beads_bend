# Keeping BEADS_RUST-bend at parity (for maintainers)

<!-- Phase 6 output, written beside docs/PORT_REPORT.md (SHIP-AND-CERTIFY "What
     to ship"). Every <placeholder> is filled from the port's own artifacts;
     every command below exists in ./scripts/. A maintainer who has never read
     the porting-to-bend2 skill can keep this port honest with this file alone. -->

## 1. What "parity" means here

Every case in `goldens/cases.tsv` (`<n>` cases) prints identical stdout,
stderr and exit code on the interpreter, the C binary at 1 and `<N>`
threads, and the JS build (`gpu`: `<PASS on <device> | MISSING: <reason>>`).
`bend port/PROOF.bend` prints `<All terms check[, with k unsafe annotations].>`
(`<a>` `@unsafe` + `<b>` template instances under bend `<version>`). The
board (`docs/FEATURE_PARITY.md`) is `<FULL | DEBT>`; the exclusions, each
with its class and retry predicate: `<list, or none>`. A claim is one of
three kinds: proved (a law), golden-tested (the harness on named lanes),
measured (an interleaved, cv-gated capture). Nothing else is a claim.

## 2. The gates, in one command each

```bash
./scripts/pin-check.sh docs/PIN.toml                       # GREEN before anything else; YELLOW = caveat; RED = stop
./scripts/port-doctor.sh --threads <N> --original <original cmd> -- --switch BEADS_RUST_SPEC=1 --probe "<hot args>"   # proof, lanes, board, floor, kill-switch
./scripts/converge.sh docs/PORT_STATE.md                   # the tier's convergence rule, computed
./scripts/claims-lint.sh docs/*.md perf/*.md README.md     # the forbidden phrases
./scripts/harness-selftest.sh -- <original cmd>            # the gates are attacked and hold (verdict OK)
```

CI: `.github/workflows/port-gates.yml` runs them on every push and PR;
`perf-tripwire.yml` runs nightly on `<runner>` and opens an informational
issue on a TRIP (never a number).

## 3. When the original ships a new version

1. Re-pin: PLAN §2 and `docs/PIN.toml` (`commit`, `version_expect`).
2. `./scripts/floor.sh goldens/cases.tsv goldens --repeat 3 -- <original cmd>` → STABLE.
3. `./scripts/golden-capture.sh goldens/cases.tsv goldens --repin "BEADS_RUST <new version>" -- <original cmd>`.
4. Read the printed MANIFEST diff: every changed hash is a clause change
   (amend `docs/EXISTING_BEADS_RUST_STRUCTURE.md`), a DISC, or a bug in the
   original (an S10 row). No hash changes silently.
5. `./scripts/lanes.sh goldens/cases.tsv goldens port/main.bend --threads <N>`; fix the port to the new clauses.
6. `docs/PORT_STATE.md` rewritten; `./scripts/state-check.sh docs/PORT_STATE.md`.

Never edit a golden. Never re-capture to make a red case green.

## 4. When bend ships a new version

1. `./scripts/pin-check.sh` turns YELLOW on `bend_version`.
2. `./scripts/version-drift.sh --old "<pinned cli>" --new "<new cli>" --threads <N>` → SAME or the DRIFT list.
3. Re-run PROOF: the unsafe count can change with no source change (2.0.16
   counts template instances); re-state it as `unsafe k = a @unsafe + b instances, bend <v>`.
4. `assets/probes/base/run-base-probes.sh` (from the skill) for drift in the
   Base facts the port relies on; every DRIFT row is a reference to re-verify.
5. Update `docs/PIN.toml [bend]`, PLAN §2b, and the version in every claim.

## 5. How to add a behavior

A case row in `goldens/cases.tsv` (name is an identifier, never renamed) →
`golden-capture.sh --repin "new case <name>"` → a clause `S<n>.<m>` in the
spec naming the case → the def with `# S<n>.<m>` above it → a board row
(`present` only with the golden or a law named) → `lanes.sh` PASS. A case
with no clause is unexplained; a clause with no case is a hypothesis.

## 6. How to propose a divergence

`docs/DISCREPANCIES.md` entry `DISC-<n>` OPEN with class, spec clause,
original behavior (cite the golden), port behavior, kill-switch, affected
cases, measured impact → approver `<name>` (never the implementer) →
re-capture through the canonicalizing wrapper with `--disc DISC-<n>` → the
switch stays forever. A self-signed DISC is refused.

## 7. How to propose a law

Append `# PROPOSED: <law>` at the bottom of `port/LAWS.bend`; the law owner
(`<name>`) promotes it. Laws are never weakened or deleted: a law the checker
refuses is a finding about the code or the spec.

## 8. How to propose a lever

`./scripts/graveyard-sweep.sh "<lever words>"` → the card in
`perf/EXPERIMENTS.md` with the precommitted gate → the fast twin behind
`BEADS_RUST_SPEC=1` → `{fast == spec}` in `port/LAWS.bend`, proved → `keep-audit`
→ capture with `bench-speedup.sh --aa --max-cv 5` (and `incumbent-bench.sh
--pin` for a claim against the original) → the ledger (WIN → PERF-LEDGER
with `./scripts/evidence-bundle.sh EXP-<id>`; else NEGATIVE-EVIDENCE with a
retry predicate) → `lanes.sh` again. A refused capture is NO_EVIDENCE, never
a rounded number.

## 9. Words that fail the claims lint

Forbidden: `later` (as a deferral), `should be`, `probably`, `roughly`, `flaky`.
Forbidden: `usually passes`, `within noise` without a cv figure, `100% parity` beside an exclusion table.
Forbidden: `faster` without a number, `verified` without a law or a golden, an unsafe count without `bend --version`. `./scripts/claims-lint.sh`
is the executable list.

## 10. The one-line re-certification

```bash
./scripts/port-doctor.sh --threads <N> --original <original cmd> -- --switch BEADS_RUST_SPEC=1 --probe "<hot args>" && ./scripts/converge.sh docs/PORT_STATE.md && ./scripts/claims-lint.sh docs/*.md perf/*.md README.md
```

Its three last lines, pasted, are the certification (`docs/PORT_REPORT.md`
"Reproduce").
