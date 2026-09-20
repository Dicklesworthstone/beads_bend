# Numeric plan — the Bend 2 port of BEADS_RUST

<!-- Phase 2 document, written BEFORE any Bend arithmetic. Bend has U32
     (wrapping 32-bit words), F32, and Nat (exact, ≤ 2^48−1, and a source
     literal ≤ 4294967295n). Anything else in the original (Python int,
     i64/u64, f64, decimal) must be mapped here with its proof or golden. -->

## 1. Representations

| choice | when | proof | golden |
|---|---|---|---|
| `U32` wrapping | the original wraps at 32 bits (hashes, PRNGs, `& 0xFFFFFFFF`) | closed laws on small words; `U32.from_nat` is native (wraps mod 2^32) | bit-exact cases |
| `Nat` | counts, sums, sizes the spec bounds below 2^48 | conservation laws in Nat | large cases at the bound |
| two-word `U32` pair | 64-bit wrapping arithmetic in the original | round-trip and carry laws on the pair | boundary cases (2^32−1, 2^32, 2^63) |
| fixed point (`Nat` cents) | money / decimals with a fixed scale | scale invariant law | printed formats |
| `F32` | the original uses f64 for continuous outputs | none (no bitwise parity to f64) | **budgeted** class (§3) |

## 2. Inventory (one row per S7 clause)

| S7.n | quantity | original type | evidence of range | Bend rep | exact or budget | proof | golden |
|---|---|---|---|---|---|---|---|
| S7.1 | | | `<case that reaches the maximum>` | | exact | `law <name>` | `goldens/<case>` |

## 3. Output classes (the harness enforces both, separately)

| class | outputs | comparison |
|---|---|---|
| exact | every integer, string, count, hash, exit code, message | byte-identical on every lane |
| budgeted | `<continuous outputs from f64>` | within `<abs/rel>` of the original, measured over the corpus (DISC-<id>, class NumericWidth); still byte-identical across the port's own lanes |

If the budgeted class is empty, say so: "no budgeted outputs".

## 4. Printing contract

Integer printing: `Nat.show`, `U32.show` (decimal, no padding); float printing
is the shortest round-trip (up to 9 digits) with one known lane difference:
at a 9-digit tie the C lane rounds half-even and the JS/interpreter lane
half-up (`20713.8125` → `20713.812` vs `20713.813`), so a printed F32 needs
either a fixed-precision formatting def or a stated lane; integers never differ. Any
padding, precision or exponent form the original uses is implemented in
the core as a pure formatting def with closed goldens.

## 5. Bridges the proofs cannot cross (stated, not hidden)

- `U32.to_nat` of a large word and `Nat.read` of long digit strings explode
  the checker (Peano expansion): the wrap-vs-mod bridge between a Nat spec
  and a U32 fast twin is golden-tested, not law-proved, unless the law is
  stated in U32 with small already-parsed values.
- No U32 associativity lemma in Base: a proved reduction stays in Nat; the
  wrapped fold is bound by goldens.
