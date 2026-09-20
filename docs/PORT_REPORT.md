# Port report: BEADS_RUST → Bend 2   [SHIP | HOLD | BLOCK]   commit <sha>   <date>   bend <version>

<!-- Phase 6 document (SHIP-AND-CERTIFY). Every constant is computed from an
     artifact and pasted; every claim is proved / golden-tested / measured
     with the artifact named; anything else is deleted. Run
     scripts/claims-lint.sh on this file before committing it. -->

## Verdict

SHIP: every constant holds (table below).
HOLD: <the constants that fail, each with the owner and the predicate that would flip it>.
BLOCK: <a finding that invalidates the port's premise: an oracle-on-oracle run, an edited golden, a false law>.

## Constants (computed, never asserted)

| constant | value | evidence |
|---|---|---|
| 100% of cases pass on every lane | `<lanes.sh JSON line>` | `scripts/port-doctor.sh` |
| all laws check | `<All terms check. line>` (unsafe <n>, bend <version>) | `bend port/PROOF.bend` |
| law coverage | `<law-coverage.sh JSON line>` | `scripts/law-coverage.sh` |
| board FULL or DEBT, every exclusion classed | `<parity-board.sh verdict line>` | `scripts/parity-board.sh` |
| DISC register complete | <n> accepted, 0 OPEN | `docs/DISCREPANCIES.md` |
| floor unchanged since capture | `<floor.sh JSON line>` | `scripts/floor.sh` |
| MANIFEST unchanged since the clean tail | `<git log -1 -- goldens/MANIFEST.txt>` | git |
| evidence ≤ 24 h old on this commit | <dates from the doctor table> | `docs/PORT_STATE.md` |
| zero open high-severity findings | <the last two rounds> | PORT_STATE rounds table |
| convergence met for the tier | `<converge.sh JSON line>` | `scripts/converge.sh` |
| every perf claim has a pin, cv ≤ 5%, identical sha | `<incumbent-bench.sh JSON line(s)>` | `perf/` |
| claims lint | `<claims-lint.sh last line>` | `scripts/claims-lint.sh` |

## Claims

### Proved
- <law> — <one sentence>; `All terms check.` (unsafe <n>, bend <version>)

### Golden-tested
- <n> cases on interpreter, c-1t, c-<N>t, js[, gpu | gpu MISSING: <reason>]; MANIFEST <sha16>; <date>

### Measured
- <ratio>× vs the original on <input> (<pin>; cv <a>% / <b>%; sha equal; <host>; <date>)
- <ratio>× at <N> threads vs 1 (bench-speedup; same_output true; A/A <r>)

### Not claimed
- <every refused capture with its NE id and predicate>
- <every exclusion with its class>

## Discrepancies

<one line per accepted DISC: id, class, kill-switch, affected cases, impact, approver>

## Reproduce (an auditor gets the same lines)

```bash
git checkout <sha>
./scripts/floor.sh goldens/cases.tsv goldens --repeat 3 -- <original cmd>
./scripts/port-doctor.sh --threads <N> --original <original cmd> -- --switch BEADS_RUST_SPEC=1 --probe "<hot args>"
./scripts/converge.sh docs/PORT_STATE.md
${BEND_CLI:-bend} port/main.bend -o ./x && ./scripts/incumbent-bench.sh --runs 6 --pin "<pin>" --original <original cmd> <args> --port ./x --threads 1 --gpu off -- <args>
./scripts/claims-lint.sh docs/PORT_REPORT.md README.md perf/*.md
```
