# Numeric plan — the Bend 2 port of BEADS_RUST

<!-- Phase 2 document, written BEFORE any Bend arithmetic. Bend has U32
     (wrapping 32-bit words), F32, and Nat (exact, ≤ 2^48−1, and a source
     literal ≤ 4294967295n). Anything else in the original (Python int,
     i64/u64, f64, decimal) must be mapped here with its proof or golden. -->

Source: spec S7.1–S7.25 (`docs/spec-parts/S4a_S7.md`, merged into the spec
by `scripts/merge-spec-parts.py`). Pinned Bend: 2.0.20. Literals are decimal:
Bend has no hex literals (probe `port/probes/sha256/`, 2026-09-20).

## 1. Representations

| choice | when | proof | golden |
|---|---|---|---|
| `U32` wrapping | SHA-256 words: wrapping add, rotates, bit operations (S4 identifiers) | closed laws against the FIPS 180-4 vectors; `port/probes/sha256/` shows the shape | every case that creates an id |
| `Nat` | counts, lengths, small parsed integers, epoch **seconds**, nanoseconds **within** a second: each bounded far below 2^48 (bound stated per row) | structural laws in `Nat` | the cases named per row |
| two `U32` words `(hi, lo)` | the 64-bit id hash value (S7.4): the digest's first two state words are `hi` and `lo` directly, no shifting | the base-36 digits by long division over four 16-bit limbs, where every intermediate `rem × 65536 + limb` stays below `36 × 65536 = 2359296` | the id goldens; a closed law per known id |
| split instant `(sign, secs: Nat, nanos: Nat)` | every timestamp (S7.14) and the id seed's nanosecond count (S7.2): epoch nanoseconds (≈1.8e18) exceed `Nat`, so the 64-bit number is never formed | decimal printing by concatenation: `show(secs) ++ pad9(nanos)`; ordering by `(secs, nanos)`; civil date by day arithmetic in `Nat` | `create_min`, `edge_precision_*`, `scn_dup_title` |
| decimal digit string | integers that are only echoed, compared or incremented and may exceed 2^48 in a hostile file or argv: comment ids (S7.12), `--limit`/`--offset` as echoed in the envelope (S7.16) | compare by (length, then bytes); increment by schoolbook carry: both total and exact at any size | `comments_add_json`, `list_limit_offset` |
| `F32` | **not used.** The one float that reaches an in-scope output (S7.20) is planned as exact arithmetic, §3 | | |

## 2. Inventory (one row per S7 clause)

| S7.n | quantity | original type | evidence of range | Bend rep | exact or budget | proof | golden |
|---|---|---|---|---|---|---|---|
| S7.1 | id seed field byte length | usize, decimal | 500 bytes (`edge_create_max_title`); 29-byte Unicode title (`create_unicode`) | `Nat`: the UTF-8 byte count of a field; bounded by the argv size, far below 2^48 | exact | law: the byte count of an ASCII string equals its length | `create_unicode`, `edge_create_max_title` |
| S7.2 | id seed timestamp | i64 nanoseconds, decimal; out of range becomes `0` | `1767323045000000000` (`create_min`) | split instant; printed as `show(secs) ++ pad9(nanos)`, or `show(nanos)` when `secs` is 0; the in-range test compares `(secs, nanos)` with `(9223372036, 854775807)` in `Nat` | exact | closed laws: the seed strings of `proj-fyw` and of `scn_dup_title` | `create_min`, `scn_dup_title`; (case to add for the `0` rule: an instant past 2262 through `@time`) |
| S7.3 | id nonce | u32, 0..9 per length, 0..1999 on the fallback | 0, 1, 2 (`scn_dup_title`) | `Nat`, bounded by 1999 | exact | the ladder is a fuel-bounded search: fuel 10 per length, 2000 on the fallback, stated in S4 | `scn_dup_title` |
| S7.4 | id hash accumulator | u64 from digest bytes 0..7, big-endian | opaque | two `U32` words = the digest's state words `a`, `b` | exact | closed law: the pair for the seed of `proj-fyw` | `create_min` |
| S7.5 | base-36 digit extraction | u64 `% 36`, `/ 36` | remainders 0..35 | long division of four 16-bit limbs by 36 in `U32`; `length` passes (at most 12) yield the LAST `length` digits, least significant first | exact; every intermediate `< 2359296` | closed laws for four known ids (`fyw`, `mta`, `170`, `b75`); property law on values below 2^16 against `Nat` division | `create_min`, the `basic` fixture build |
| S7.6 | hash length | usize 3..8, fallback 12 | 3 in every captured case | `Nat` | exact | | `create_min` |
| S7.7 | issue count fed to the adaptive length | usize → f64 | 0, 8, 11 | `Nat`: the unfiltered record count, tombstones included (S4) | exact | | `create_min`, `create_full_json` |
| S7.8 | birthday-bound intermediates | f64 `exp` | never printed; decides the length | **no float**: the predicate over an integer count is a finite table (S4.9): ≤163 → 3, ≤983 → 4, ≤5898 → 5, ≤35389 → 6, ≤212339 → 7, else 8 | exact as a table; bands past the first are `[inference]` in S4.9 until OQ-006's boundary goldens are captured | closed law: the table at each band edge | (cases to add: `edge_idlen_163`, `edge_idlen_164`; OQ-006) |
| S7.9 | child number | u32, saturating `+1`, search stops 100 past | 1, 2 (`scn_child_ids`) | `Nat`, saturating at 4294967295 by an explicit comparison | exact | law: `next(max) = max + 1` below the cap, `= cap` at it | `scn_child_ids` |
| S7.10 | priority | i32, 0..=4 | 0..4 | `Nat` 0..4; the argv parser rejects what does not fit i32 with the original's message (S9) | exact | | `list_priority_one`, `error_create_bad_priority` |
| S7.11 | estimated minutes | i32, 0..=525960 | 90 (`create_full_json`) | `Nat`, bound 525960 | exact | | `create_full_json` |
| S7.12 | comment id | i64; new id = largest id in the whole store + 1 | 1, 2 | decimal digit string (a file may hold any i64); max and increment on strings | exact at any size | law: increment of a digit string equals `Nat` successor on values below 2^16 | `comments_add_json`, `comments_add_second` |
| S7.13 | dependency / dependent counts | usize | 0, 1, 2 | `Nat`, bounded by the record count | exact | | `list_json` |
| S7.14 | record timestamps | i64 seconds + u32 nanoseconds | 2026-01-01 … 2027-06-01; 1 ns (`edge_precision_*`) | split instant; civil-from-days and days-from-civil in `Nat` (proleptic Gregorian); fraction printed as 0, 3, 6 or 9 digits | exact | round-trip law `parse(print(t)) == t`; closed laws on the `precision` fixture's five spellings | `edge_precision_list_json`, `edge_precision_rewrite` |
| S7.15 | relative-duration amount | i64, checked | 1 (`defer_relative`) | sign + decimal digit string, converted to `Nat` only after a bound check; an out-of-range amount yields the original's `relative duration is out of supported range` | exact | | `defer_relative`; (case to add: an overflowing amount) |
| S7.16 | `--limit` / `--offset` | usize; saturating add for `has_more`; 0 = unlimited | 0, 1, 2 | decimal digit string for the echo in the envelope; a `Nat` saturated at 2^48−1 for slicing (a store cannot hold that many records, so saturation never changes a result) | exact | | `list_limit_one`, `list_limit_offset` |
| S7.17–S7.19 | totals, counts, stats and epic counters | usize | 0..8 | `Nat`, bounded by the record count | exact | conservation law: the by-status counts sum to the total | `count_json`, `stats_json`, `epic_status_json` |
| S7.20 | average lead time in `stats` | f64: mean of per-issue lead times, each truncated to whole hours; printed shortest round-trip (`2.0`) | 2.0 and absent | see §3 | exact where §3's rule applies; otherwise OPEN | | `stats_json`, `empty_stats_json` |
| S7.21 | percentage bars | f64, Rich path only | never reached | not ported (PLAN §3 excludes Rich) | n/a | | `stats_plain` shows no bars |
| S7.22 | content-hash length prefix | usize as 8 bytes little-endian | unobservable in scope (S4.51) | not ported until an in-scope reader exists | n/a | | |
| S7.23 | compaction level, original size | i32 options | 0 | `Nat`; a negative value in a file is carried as sign + digits and printed back | exact | | `create_min`, `edge_precision_rewrite` |
| S7.24 | exit codes | i32 | 0, 2, 3, 4, 5, 7 | `U32` for `IO.die`; the map is S9's | exact | | one case per code (S9) |
| S7.25 | integer printing | serde / Rust `Display` | no separators, no `+`, no padding | `Nat.show`, digit strings verbatim, `-` prefix for a signed value | exact | | `list_json`, `count_json` |

## 3. Output classes (the harness enforces both, separately)

| class | outputs | comparison |
|---|---|---|
| exact | every integer, string, count, id, timestamp, exit code and message | byte-identical on every lane |
| budgeted | **none** | |

No budgeted outputs. The single float, S7.20, is handled without `F32`: the
lead times are whole hours (`Nat`), so the mean is the rational `sum / count`.
When `count` divides `sum` the output is `show(sum / count) ++ ".0"`, which is
what f64 shortest round-trip printing gives for any whole value below 2^53
(`stats_json` prints `2.0`). When it does not divide, the correct bytes are the
shortest decimal that round-trips the correctly rounded binary64 quotient
(`7/3` prints `2.3333333333333335`); that needs a multi-limb integer routine
(a 53-bit mantissa exceeds `Nat`). Until that routine exists with closed
goldens, the non-dividing case is **OPEN** (OQ to register with a fixture of
two closed issues whose lead times average to a non-integer), and the parity
board row for `stats --json` stays `partial`. It is never rounded through
`F32` and never emitted approximately.

## 4. Printing contract

Integers: `Nat.show` and digit strings, decimal, no padding. Timestamps: RFC
3339 in UTC with `Z`, the fraction as 0, 3, 6 or 9 digits (the shortest of
those that loses nothing), built by pure formatting defs with the `precision`
fixture as closed goldens. Two commands print `+00:00` instead of `Z` in their
JSON payload (S4.64, S5a): the same formatter, a second suffix. No `F32` is
printed anywhere, so the C/JS rounding difference at a 9-digit tie cannot
occur.

## 5. Bridges the proofs cannot cross (stated, not hidden)

- `U32.to_nat` of a large word and `Nat.read` of long digit strings explode
  the checker (Peano expansion): laws about SHA-256 and the base-36 division
  are **closed** laws over `U32` values and short strings; nothing is proved
  through a `Nat` view of a 32-bit word.
- No `U32` associativity lemma in Base: SHA-256 stays a literal transcription
  of FIPS 180-4; its evidence is the published vectors as closed laws plus the
  id goldens, not an algebraic proof.
- A quantified law holds in Bend's logical semantics; that compiled
  intermediates fit `Nat`'s 48 bits is a separate, stated bound (each `Nat`
  row above names it). The rows that could exceed it use digit strings or
  split instants for that reason.
- The `Clock.wall` effect's C side has no ABI promise and delivers a string
  the core parses; its parse is total (a malformed answer is a verdict, not a
  default).
