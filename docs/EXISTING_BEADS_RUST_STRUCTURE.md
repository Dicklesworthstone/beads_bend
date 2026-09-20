# EXISTING BEADS_RUST STRUCTURE — THE SPEC

<!-- Phase 1 document. THE contract of the port. Rule: after reading this
     file, an implementer must NOT need the original's source. Behavior is
     described as WHAT (inputs → outputs, verbatim strings, exact numbers),
     never HOW (no "uses a dict", no code). Every clause is numbered
     S<section>.<n> and cites its provenance `file:line` in the original;
     port defs, laws and golden cases refer to clauses by number.
     Data (formats, strings, constants) is quoted verbatim. Algorithms are
     described behaviorally with an | input | output | examples table.
     A gap discovered later is an OQ entry, resolved by RUNNING the
     original on a new case (captured as a golden), then amended here. -->

Provenance: `legacy/BEADS_RUST` at commit `<sha>`; extracted `<date>`; extractors: `<agents>`.
Coverage: `<n>` files / `<m>` functions read; unread parts listed in §12.

## S1. Command-line surface

| S1.n | clause | provenance | cases |
|---|---|---|---|
| S1.1 | invocation forms, verbatim: `beads_rust <cmd> <args>` | `file:line` | |
| S1.2 | usage text (verbatim, each variant) and its exit code | | usage_none, usage_cmd |
| S1.3 | option parsing rules (order, repeats, `--flag value` vs `--flag=value`, unknown option behavior) | | |
| S1.4 | exit codes: 0 …, 1 …, 2 … (every path that can produce each) | | |
| S1.5 | environment variables read and their effect | | |

## S2. Inputs

| S2.n | clause | provenance | cases |
|---|---|---|---|
| S2.1 | file formats (grammar, encoding, line endings, BOM, trailing newline, empty file) | | |
| S2.2 | parsing rules, verbatim (what counts as a field, whitespace, quoting, escapes) | | |
| S2.3 | invalid input behavior: message (verbatim), which stream, exit code, whether processing continues | | |
| S2.4 | limits (max size, max fields) and what happens at them | | |

## S3. Data model

Types and their invariants as the outputs reveal them (not as the code
stores them). Note which values are unbounded (Python int), 64-bit, or
floating point: they feed NUMERIC_PLAN.md.

## S4. Algorithms (behavioral)

For each computation: purpose, inputs, outputs, an examples table, the
exact arithmetic (wrap width, rounding, division semantics, sign of modulo),
and the order of operations where it affects the result.

| S4.n | clause | examples (input → output) | provenance | cases |
|---|---|---|---|---|

## S5. Outputs

| S5.n | clause | provenance | cases |
|---|---|---|---|
| S5.1 | exact formats: separators, padding, alignment, trailing whitespace, final newline | | |
| S5.2 | number printing: integer width, float precision/shortest round-trip, negative zero, exponent form | | |
| S5.3 | which stream (stdout/stderr) each message uses | | |
| S5.4 | buffering/interleaving that the goldens depend on | | |

## S6. Order-leak inventory

Every place where an iteration or insertion order reaches an output.

| S6.n | structure | order the original exhibits | reaches output via | provenance | cases |
|---|---|---|---|---|---|
| S6.1 | `<dict/map/set/hash>` | insertion · sorted · hash (unstable) · arbitrary | | | |

Sort clauses: the comparator, its tie-break, and whether the sort is stable.

## S7. Numeric inventory

| S7.n | quantity | type in original | observed range / evidence | wrap or exact | provenance | cases |
|---|---|---|---|---|---|---|

## S8. Effect inventory

| S8.n | effect | when | failure behavior | provenance | cases |
|---|---|---|---|---|---|
| S8.1 | file read/write, stdin, args, env, clock, randomness, network, exit | | | | |

## S9. Error and edge behavior

A row per error path: trigger, message (verbatim), stream, exit code,
state of partial output at that moment.

## S10. Known bugs and oddities (to be reproduced, not fixed)

| S10.n | behavior | why it is a bug | reproduce with case | decision |
|---|---|---|---|---|
| S10.1 | | | `goldens/<case>` | bug-compatible (default) · DISC-<id> |

## S11. Performance characteristics of the original

Complexity per command, the hot loop, the threading model, memory
behavior, and a measured baseline on the incumbent inputs (thread count,
wall time, cv%) from `scripts/incumbent-bench.sh`.

## S12. Provenance and coverage

Files read, files skipped (and why), extraction passes (run 1/2/3),
open questions moved to `docs/OPEN_QUESTIONS.md`.
