# Rollback of <EXP-id> (commit `<sha>`)

<!-- Written by scripts/evidence-bundle.sh at Phase 5. Two rollbacks exist
     for every lever, because every fast twin ships behind its spec twin
     (CORE-SHELL-SPLIT "Kill-switches live in the shell"). -->

## Now (runtime, no rebuild)

`<X_SPEC> <binary> -- <hot args>`: the kill-switch selects the spec twin.
The law `{fast == spec}` covers the proved core inputs. Verify the shell's
switch wiring using the complete stdout, stderr and exit-status comparison
in `rerun.sh`; runtime inputs must satisfy the recorded feature contract.

## Source (the lever is withdrawn)

1. `git revert <sha>` (the lever's commit; the spec twin and the law stay).
2. Move the PERF-LEDGER row to `perf/NEGATIVE-EVIDENCE.md` with outcome
   `NEGATIVE(reverted)`, the capture line that decided it, and a retry
   predicate in one of the eight forms (never "later").
3. Keep the law: it is still true, and a future lever binds to it.
4. `./scripts/lanes.sh` and `bend port/PROOF.bend` again; paste both lines
   into `docs/PORT_STATE.md`.
