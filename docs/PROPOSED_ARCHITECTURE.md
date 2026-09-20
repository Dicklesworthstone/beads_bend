# Proposed architecture — the Bend 2 port of BEADS_RUST

<!-- Phase 2 document. Derived from the spec and from reference Bend
     programs (bend2-mega-skill skeletons, the example port), not invented.
     Its whole job is the CORE/SHELL split: what is pure (and therefore
     provable) versus what is an effect (and therefore only golden-tested).
     Every spec clause gets a home and an evidence kind here. -->

## 1. Core / shell split

| clause group | lives in | kind | evidence |
|---|---|---|---|
| S4 algorithms, S3 data model, S5 formatting of values | core (pure defs) | spec twin (+ fast twin in Phase 5) | law + closed golden |
| S1 args, S2 file reads, S8 effects, S9 exit codes | shell (`do IO` in `main` and helpers) | one call per effect, no logic | golden (L3) |
| S5 assembly of the final text | core (`report_text`) | pure string | golden (L2/L3) |

Rule: the shell decides *whether* and *when*; the core decides *what*.
A shell def that contains a branch on data is a smell: move the branch
into a core def that returns a verdict (`Outcome`, `Result`).

## 2. Module map

| def / type | implements | twin kind | input owner | notes |
|---|---|---|---|---|
| `type <State>` | S3.n | data | | fields with their invariant |
| `<parse>` | S2.n | spec | consumes the String | returns `Result` |
| `<step>` | S4.n | spec | threads the state | the loop body |
| `<fast_step>` | S4.n | fast (Phase 5) | | law `fast_is_spec` |
| `<render>` | S5.n | spec | | pure text |
| `main`, `run_<cmd>` | S1, S8, S9 | shell | | maps `Result` to exit codes |

## 3. State threading and failure

- Mutation in the original → an explicit state value threaded through the
  loop (`step(state, x) -> State`); the accumulator is the first
  parameter or is marked `+` when reused.
- Exceptions → `Result<Error, Value>` or `Maybe` in the core; the shell
  maps `Fail{error}` to the exit code and message clause S9.n.
- Early return / break → a sticky `Outcome` carried through the fold.
- Globals → fields of the state or `~` template constants.

## 4. Loop measures

Every loop in the original and its measure in Bend (the checker refuses
loops without one; an `@unsafe` is a counted debt, never hidden).

| original loop | measure | Bend shape |
|---|---|---|
| `for x in xs` | the list | structural recursion |
| `while cond` | fuel `Nat` from the spec's limit, or a shrinking Nat | `case 1n+n:` |
| recursion on a tree | the tree | match |

## 5. Numeric plan

See `docs/NUMERIC_PLAN.md` (one row per S7 quantity).

## 6. Order plan

| S6 clause | Bend carrier | proof / golden |
|---|---|---|
| insertion-order dict | `Map` for lookup + an explicit key `List` for order | golden; `first_seen` law if cheap |
| stable sort with tie-break | `List.sort(~le)` with a less-or-equal `le` carrying the tie-break | golden |

## 7. Parallel shape plan (Phase 5, planned now)

Which S4 clause is the hot loop; whether it is a fold (needs an associative
combine, proved), a map (embarrassingly parallel), or sequential by nature;
the balanced-fork shape (`2^d` leaves, one bang at the root) and the seam
where the IO shell stops before the bang.

## 8. Law plan (drafts LAWS.bend)

| law | kind | clause | when provable |
|---|---|---|---|
| `fast_is_spec` per fast twin | equivalence | S4.n | Phase 5 |
| `decode(encode(x)) == x` | round trip | S2/S5 | Phase 3 |
| conservation of `<total>` | conservation | S4.n | Phase 3 |
| `golden_<case>` | closed golden | goldens/<case> | Phase 3, only cheap values |

## 9. Lanes and kill-switches

Lanes that must agree: interpreter, C 1T, C NT, JS, device if a bang
exists. Kill-switches: `~` template switch or one env read in `main`
selecting the spec twin (`BEADS_RUST_SPEC=1`) for every fast twin; each DISC
entry names its switch.

## 10. What is proved vs golden-tested (summary the README will repeat)

- Proved: …
- Golden-tested: …
- Measured: …
