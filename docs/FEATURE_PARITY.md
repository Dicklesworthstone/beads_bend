# Feature parity — the Bend 2 port of BEADS_RUST

<!-- Generated from the spec's in-scope rows and kept current by hand after
     every gate run. `scripts/parity-board.sh docs/FEATURE_PARITY.md`
     computes the verdict: FULL, PARTIAL, DEBT (exclusions exist) or
     MALFORMED (a "present" row with neither a golden nor a law). Rules:
     partial never rounds up; excluded is debt; a present feature names
     its evidence. Statuses: present | partial | missing | excluded | n/a. -->

Last gate run: `<date>` · lanes: `scripts/lanes.sh` → `<PASS/FAIL>` (interpreter, c-1t, c-<N>t, js`<, gpu>`) ·
proofs: `bend port/PROOF.bend` (or `$BEND_CLI port/PROOF.bend`) → `All terms check.` with `<n>` unsafe · board: `<FULL/PARTIAL/DEBT>`.

| feature | original ref | port def | goldens | laws | status | notes |
|---|---|---|---|---|---|---|
| `<command or behavior>` | S1.1 `file:line` | `run_<cmd>` | `case_a, case_b` | `fast_is_spec` | missing | flip to present when the goldens and laws named here exist |
| `<behavior>` | S4.2 | `<def>` | `case_c` | none | missing | golden-tested only (shell) |
| `<behavior>` | S10.1 | `<def>` | `case_d` | none | missing | bug-compatible per S10.1 |
| `<feature>` | S1.4 | - | - | - | excluded | PLAN §3: infeasible-numeric (u64 file offsets) |

(The scaffolded board reads PARTIAL until rows are filled; a row whose
feature cell is still `<…>` is reported as PLACEHOLDER by `parity-board.sh`.)

## Proof coverage

| kind | count | list |
|---|---|---|
| fast == spec laws | `<n>` | |
| round-trip / conservation laws | `<n>` | |
| closed goldens as laws | `<n>` | |
| `@unsafe` defs | `<n>` | each with its comment and bead |

## Lanes

| lane | cases | verdict | date |
|---|---|---|---|
| interpreter | `<n>/<n>` | PASS | |
| c-1t | | | |
| c-<N>t | | | |
| js | | | |
| gpu (`--gpu on`) | | PASS · MISSING (no device: stated) | |
