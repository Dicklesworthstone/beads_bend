# Port state — BEADS_RUST → Bend 2

<!-- Read FIRST on every resume; rewritten at the END of every session.
     Facts only, each with the command that produced it. No "should",
     no "later". -->

## Where we are

| field | value |
|---|---|
| phase | −1 fit · 0 truth pack · 1 spec · 2 architecture · 3 reference port · 4 parity gate · 5 performance · 6 certify |
| tier | T1 · T2 · T3 |
| bend | `<version>` (`<release \| checkout sha>`); drift vs the previous pin: `<SAME \| DRIFT: …>` (VERSION-DRIFT) |
| last updated | `<date>` by `<agent>` |

## Last gate outputs (paste, do not paraphrase)

| gate | command | result | date |
|---|---|---|---|
| lanes | `scripts/lanes.sh goldens/cases.tsv goldens port/main.bend` | `<JSON last line>` | |
| proofs | `bend port/PROOF.bend` (or `$BEND_CLI port/PROOF.bend`) | `<last line + unsafe count>` | |
| parity | `scripts/parity-board.sh docs/FEATURE_PARITY.md` | `<verdict line>` | |
| floor | `scripts/floor.sh … --repeat 3` | `<verdict>` | |
| incumbent | `scripts/incumbent-bench.sh --pin …` | `<ratio, cv, verdict>` | |

## Open items

| id | what | blocks | owner |
|---|---|---|---|
| OQ-`<n>` | | phase `<n>` | |
| DISC-`<n>` | | | |
| NE-`<n>` (retry predicate) | | | |

## Find-fix rounds (Phase 4/5)

| round | lens | new genuine findings | fixed | clean? | date |
|---|---|---|---|---|---|

Convergence (computed by `scripts/converge.sh docs/PORT_STATE.md`): T1 ≥ 3
rounds and ≥ 1 clean at the end; T2 ≥ 5 and ≥ 2 consecutive clean at the end and ≥ 1 non-author round; T3
≥ 10 with the last two rounds clean; a clean round has < 3 new genuine
findings and no unresolved finding from that round; a dirty or reopened
round resets the clean streak. Every OQ is resolved or excluded; no OPEN DISC. Current: `<paste
converge.sh's JSON line>`.

## Next action (one line, executable)

`<the exact command or the exact clause to work on>`
