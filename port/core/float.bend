# core/float — the binary64 arithmetic `stats` needs for the average lead time (S5.170, S6.34, S7.20, OQ-078):
# the double nearest a ratio of whole numbers, its shortest round-trip decimal as serde_json writes it (ryu), and
# Rust's `{:.1}`. The original divides two f64 values and prints the result; the port reproduces the bits by exact
# integer arithmetic. A number wider than a machine word is a little-endian list of base-256 limbs, normalized: no
# zero limb on top, and zero is the empty list. A double here is `m / 2^k` with 2^52 <= m < 2^53.
# Spec: docs/EXISTING_BEADS_RUST_STRUCTURE.md. Nothing here consults the original.
import Base

# ---------------------------------------------------------------- limbs

# S7.20 (spec twin) the higher limbs of a word (three at most)
def big_of_high(+n: U32) -> List<&2, U32>:
  Bool.pick(List<&2, U32>, U32.is_eq(n, 0), Nil{}, (n % 256 : U32) <> Bool.pick(List<&2, U32>, U32.is_eq((n / 256 : U32), 0), Nil{}, ((n / 256 : U32) % 256 : U32) <> Bool.pick(List<&2, U32>, U32.is_eq((n / 65536 : U32), 0), Nil{}, (n / 65536 : U32) <> Nil{})))

# S7.20 (spec twin) a word as limbs
def big_of(+n: U32) -> List<&2, U32>:
  Bool.pick(List<&2, U32>, U32.is_eq(n, 0), Nil{}, (n % 256 : U32) <> big_of_high((n / 256 : U32)))

# S7.20 (spec twin) the top zero limbs dropped from a list whose top is at the HEAD (a reversed number)
def drop_zeros(rev: List<&2, U32>) -> List<&2, U32>:
  match rev:
    case Nil{}:
      Nil{}
    case Con{+x, +rest}:
      Bool.pick(List<&2, U32>, U32.is_eq(x, 0), drop_zeros(rest), x <> rest)

# S7.20 (spec twin) a number normalized
def norm(a: List<&2, U32>) -> List<&2, U32>:
  List.reverse(&2, U32, drop_zeros(List.reverse(&2, U32, a)))

# S7.20 (spec twin) a carry run up a number
def carry_go(a: List<&2, U32>, +carry: U32) -> List<&2, U32>:
  match a:
    case Nil{}:
      Bool.pick(List<&2, U32>, U32.is_eq(carry, 0), Nil{}, carry <> Nil{})
    case Con{+x, ra}:
      ((x + carry : U32) % 256 : U32) <> carry_go(ra, ((x + carry : U32) / 256 : U32))

# S7.20 (spec twin) the sum of two numbers, limb by limb
def add_go(a: List<&2, U32>, b: List<&2, U32>, +carry: U32) -> List<&2, U32>:
  match a b:
    case Nil{} other:
      carry_go(other, carry)
    case Con{+x, ra} Nil{}:
      carry_go(Con{x, ra}, carry)
    case Con{+x, ra} Con{+y, rb}:
      (((x + y : U32) + carry : U32) % 256 : U32) <> add_go(ra, rb, (((x + y : U32) + carry : U32) / 256 : U32))

# S7.20 (spec twin) a + b
def add(a: List<&2, U32>, b: List<&2, U32>) -> List<&2, U32>:
  add_go(a, b, 0)

# S7.20 (spec twin) a borrow run up a number
def borrow_go(a: List<&2, U32>, +borrow: U32) -> List<&2, U32>:
  match a:
    case Nil{}:
      Nil{}
    case Con{+x, +ra}:
      Bool.pick(List<&2, U32>, (x >= borrow : U32), (x - borrow : U32) <> ra, ((x + 256 : U32) - borrow : U32) <> borrow_go(ra, 1))

# S7.20 (spec twin) one limb of a difference, borrowing 256 when the limb is short
def sub_step(fits: Bool, +x: U32, +need: U32, rest: List<&2, U32>) -> List<&2, U32>:
  Bool.pick(U32, fits, (x - need : U32), ((x + 256 : U32) - need : U32)) <> rest

# S7.20 (spec twin) the difference of two numbers, limb by limb (a >= b)
def sub_go(a: List<&2, U32>, b: List<&2, U32>, +borrow: U32) -> List<&2, U32>:
  match a b:
    case Nil{} _:
      Nil{}
    case Con{+x, ra} Nil{}:
      borrow_go(Con{x, ra}, borrow)
    case Con{+x, ra} Con{+y, rb}:
      sub_step((x >= (y + borrow : U32) : U32), x, (y + borrow : U32), sub_go(ra, rb, Bool.pick(U32, (x >= (y + borrow : U32) : U32), 0, 1)))

# S7.20 (spec twin) a - b, for a >= b
def sub(a: List<&2, U32>, b: List<&2, U32>) -> List<&2, U32>:
  norm(sub_go(a, b, 0))

# S7.20 (spec twin) compare two numbers top limb first, both reversed and of equal length: 0 less, 1 equal, 2 greater
def cmp_rev(a: List<&2, U32>, b: List<&2, U32>) -> U32:
  match a b:
    case Con{+x, ra} Con{+y, rb}:
      Bool.pick(U32, (x < y : U32), 0, Bool.pick(U32, (x > y : U32), 2, cmp_rev(ra, rb)))
    case _ _:
      1

# S7.20 (spec twin) compare two normalized numbers: 0 less, 1 equal, 2 greater
def cmp(+a: List<&2, U32>, +b: List<&2, U32>) -> U32:
  Bool.pick(U32, Nat.is_lt(List.length(&2, U32, a), List.length(&2, U32, b)), 0, Bool.pick(U32, Nat.is_gt(List.length(&2, U32, a), List.length(&2, U32, b)), 2, cmp_rev(List.reverse(&2, U32, a), List.reverse(&2, U32, b))))

# S7.20 (spec twin) a number times a small word (s < 2^16)
def mul_small_go(a: List<&2, U32>, +s: U32, +carry: U32) -> List<&2, U32>:
  match a:
    case Nil{}:
      big_of(carry)
    case Con{+x, ra}:
      (((x * s : U32) + carry : U32) % 256 : U32) <> mul_small_go(ra, s, (((x * s : U32) + carry : U32) / 256 : U32))

# S7.20 (spec twin) a * s, for s < 2^16
def mul_small(a: List<&2, U32>, +s: U32) -> List<&2, U32>:
  norm(mul_small_go(a, s, 0))

# S7.20 (spec twin) a number one limb up (times 256)
def shifted(a: List<&2, U32>) -> List<&2, U32>:
  match a:
    case Nil{}:
      Nil{}
    case Con{x, rest}:
      0 <> Con{x, rest}

# S7.20 (spec twin) a * b: each limb of b scales a, one limb further up each time
def mul(+a: List<&2, U32>, b: List<&2, U32>) -> List<&2, U32>:
  match b:
    case Nil{}:
      Nil{}
    case Con{+y, rb}:
      add(mul_small(a, y), shifted(mul(a, rb)))

# S7.20 (spec twin) a * base^n (base 2, 5 or 10)
def mul_pow(n: Nat, a: List<&2, U32>, +base: U32) -> List<&2, U32>:
  match n:
    case 0n:
      a
    case 1n+p:
      mul_pow(p, mul_small(a, base), base)

# S7.20 (data) a quotient and a remainder
type QR is Data:
  QR{q: List<&2, U32>, r: U32}

# S7.20 (spec twin) long division by a small word (d < 2^24), top limb first; the quotient is built bottom-first
def div_go(rev: List<&2, U32>, +d: U32, +r: U32, q: List<&2, U32>) -> QR:
  match rev:
    case Nil{}:
      QR{norm(q), r}
    case Con{+x, rest}:
      div_go(rest, d, (((r * 256 : U32) + x : U32) % d : U32), (((r * 256 : U32) + x : U32) / d : U32) <> q)

# S7.20 (spec twin) a / d and a % d, for 0 < d < 2^24
def divmod(a: List<&2, U32>, +d: U32) -> QR:
  div_go(List.reverse(&2, U32, a), d, 0, Nil{})

# S7.20 (spec twin) is a number odd
def is_odd(a: List<&2, U32>) -> Bool:
  match a:
    case Nil{}:
      False{}
    case Con{+x, rest}:
      U32.is_eq((x % 2 : U32), 1)

# S7.20 (spec twin) the quotient of a division
def qr_q(qr: QR) -> List<&2, U32>:
  match qr:
    case QR{q, r}:
      q

# S7.20 (spec twin) the remainder of a division
def qr_r(qr: QR) -> U32:
  match qr:
    case QR{q, r}:
      r

# S7.20 (spec twin) the decimal digits of a number, most significant first, pushed onto `acc`: one digit peeled per
# step until nothing is left; the fuel is three per limb (a limb holds under three decimal digits)
def digits_go(fuel: Nat, +a: List<&2, U32>, +acc: String) -> String:
  match fuel:
    case 0n:
      acc
    case 1n+f:
      Bool.pick(String, List.is_empty(&2, U32, a), acc, digits_go(f, qr_q(divmod(a, 10)), SCon{Chr{(qr_r(divmod(a, 10)) + 48 : U32)}, acc}))

# S7.20 (spec twin) a number in decimal; zero is `0`
def decimal(+a: List<&2, U32>) -> String:
  Bool.pick(String, List.is_empty(&2, U32, a), "0", digits_go(Nat.mul(List.length(&2, U32, a), 3n), a, ""))

# S7.20 (spec twin) decimal digits as a number (every code point is a digit)
def parse_go(s: String, acc: List<&2, U32>) -> List<&2, U32>:
  match s:
    case SNil{}:
      acc
    case SCon{Chr{+c}, rest}:
      parse_go(rest, add(mul_small(acc, 10), big_of((c - 48 : U32))))

# ---------------------------------------------------------------- the nearest double (IEEE 754, round half to even)

# S7.20 (data) a positive double as `m / 2^k`, 2^52 <= m < 2^53
type Dbl is Data:
  Dbl{m: List<&2, U32>, k: Nat}

# S7.20 (spec twin) the least k at which p * 2^k reaches 2^52 * q (`pk` is p * 2^k); fuel bounds the search
def scale_go(fuel: Nat, +pk: List<&2, U32>, +k: Nat, +target: List<&2, U32>) -> Nat:
  match fuel:
    case 0n:
      k
    case 1n+f:
      Bool.pick(Nat, U32.is_ne(cmp(pk, target), 0), k, scale_go(f, mul_small(pk, 2), Nat.add(k, 1n), target))

# S7.20 (spec twin) the quotient rounded half to even: up past half, or at exactly half when it is odd
def rounded(qr: QR, +q: U32) -> List<&2, U32>:
  match qr:
    case QR{+m0, +r}:
      Bool.pick(List<&2, U32>, (((r * 2 : U32) > q : U32) || (U32.is_eq((r * 2 : U32), q) && is_odd(m0))), add(m0, big_of(1)), m0)

# S7.20 (spec twin) a mantissa that rounded up to 2^53 moves to the next binade: 2^52 with one power of two less
def carried(+m: List<&2, U32>, +k: Nat) -> Dbl:
  Bool.pick(Dbl, U32.is_eq(cmp(m, mul_pow(53n, big_of(1), 2)), 1), Dbl{mul_pow(52n, big_of(1), 2), Nat.sub(k, 1n)}, Dbl{m, k})

# S7.20 (spec twin) the double nearest p / q, for p > 0 below 2^53 * q and 0 < q < 2^24
def nearest_at(+p: List<&2, U32>, +q: U32, +k: Nat) -> Dbl:
  carried(rounded(divmod(mul_pow(k, p, 2), q), q), k)

# S7.20 (spec twin) the bit length of a limb (below 256)
def limb_bits(+x: U32) -> Nat:
  Bool.pick(Nat, (x >= 128 : U32), 8n, Bool.pick(Nat, (x >= 64 : U32), 7n, Bool.pick(Nat, (x >= 32 : U32), 6n, Bool.pick(Nat, (x >= 16 : U32), 5n, Bool.pick(Nat, (x >= 8 : U32), 4n, Bool.pick(Nat, (x >= 4 : U32), 3n, Bool.pick(Nat, (x >= 2 : U32), 2n, Bool.pick(Nat, (x >= 1 : U32), 1n, 0n))))))))

# S7.20 (spec twin) the bit length of a normalized number, from its top limb
def bits_rev(rev: List<&2, U32>, +below: Nat) -> Nat:
  match rev:
    case Nil{}:
      0n
    case Con{+x, rest}:
      Nat.add(limb_bits(x), Nat.mul(below, 8n))

# S7.20 (spec twin) the bit length of a number
def bits(+a: List<&2, U32>) -> Nat:
  bits_rev(List.reverse(&2, U32, a), Nat.sub(List.length(&2, U32, a), 1n))

# S7.20 (spec twin) the double nearest p / q. With p of bp bits and q of bq bits, the least k with p·2^k >= 2^52·q is
# 52 + bq − bp or one more, so the search starts one below that (or at 0) and needs three steps at most
def nearest(+p: List<&2, U32>, +q: U32) -> Dbl:
  nearest_at(p, q, scale_go(3n, mul_pow(Nat.sub(Nat.add(52n, bits(big_of(q))), Nat.add(bits(p), 1n)), p, 2), Nat.sub(Nat.add(52n, bits(big_of(q))), Nat.add(bits(p), 1n)), mul_pow(52n, big_of(q), 2)))

# ---------------------------------------------------------------- serde_json's spelling (ryu: the shortest round trip)

# S7.20 (spec twin) m * 5^k: the double's exact decimal digits, the point k digits from the right
def exact_digits(+d: Dbl) -> String:
  match d:
    case Dbl{m, +k}:
      decimal(mul_pow(k, m, 5))

# S7.20 (spec twin) is every digit a zero
def all_zeros(s: String) -> Bool:
  match s:
    case SNil{}:
      True{}
    case SCon{Chr{+c}, rest}:
      (U32.is_eq(c, 48) && all_zeros(rest))

# S7.20 (spec twin) the rest of the digits against one half of the last kept place: 0 below, 1 exactly, 2 above
def rest_half(rest: String) -> U32:
  match rest:
    case SNil{}:
      0
    case SCon{Chr{+c}, tail}:
      Bool.pick(U32, (c > 53 : U32), 2, Bool.pick(U32, (c < 53 : U32), 0, Bool.pick(U32, all_zeros(tail), 1, 2)))

# S7.20 (spec twin) is the first digit odd (the digit `1` is code 49)
def first_odd(s: String) -> Bool:
  match s:
    case SNil{}:
      False{}
    case SCon{Chr{+c}, rest}:
      U32.is_eq((c % 2 : U32), 1)

# S7.20 (spec twin) a kept prefix of digits as a number, rounded half to even by the digits after it
def round_prefix(+prefix: String, +rest: String) -> List<&2, U32>:
  Bool.pick(List<&2, U32>, (U32.is_eq(rest_half(rest), 2) || (U32.is_eq(rest_half(rest), 1) && first_odd(String.reverse(prefix)))), add(parse_go(prefix, Nil{}), big_of(1)), parse_go(prefix, Nil{}))

# S7.20 (spec twin) is c inside the rounding interval: both ends count when the mantissa is even (a tie rounds to it)
def within(+c: List<&2, U32>, +low: List<&2, U32>, +high: List<&2, U32>, inclusive: Bool) -> Bool:
  Bool.pick(Bool, inclusive, (U32.is_ne(cmp(c, low), 0) && U32.is_ne(cmp(c, high), 2)), (U32.is_eq(cmp(c, low), 2) && U32.is_eq(cmp(c, high), 0)))

# S7.20 (data) a decimal: its digits and the power of ten of the last one, biased by 1000
type Short is Data:
  Short{digits: String, xb: Nat}

# S7.20 (spec twin) the shortest digits that round back to the double: the exact digits `g` (the point `k` from the
# right) rounded to n = 1, 2, … significant digits, the first that falls inside the interval. `low` and `high` are
# the interval's ends times 10^(k+2); a candidate of n digits is scaled the same way by 10^(len - n + 2)
def shortest_go(fuel: Nat, +n: Nat, +g: String, +len: Nat, +k: Nat, +low: List<&2, U32>, +high: List<&2, U32>, +inclusive: Bool) -> Short:
  match fuel:
    case 0n:
      Short{g, Nat.sub(1000n, k)}
    case 1n+f:
      Bool.pick(Short, within(mul_pow(Nat.add(Nat.sub(len, n), 2n), round_prefix(String.take(g, n), String.drop(g, n)), 10), low, high, inclusive), Short{decimal(round_prefix(String.take(g, n), String.drop(g, n))), Nat.sub(Nat.add(len, 1000n), Nat.add(n, k))}, shortest_go(f, Nat.add(n, 1n), g, len, k, low, high, inclusive))

# S7.20 (spec twin) the search from one digit, with the exact digits and their count
def shortest_from(+g: String, +k: Nat, +low: List<&2, U32>, +high: List<&2, U32>, +inclusive: Bool) -> Short:
  shortest_go(17n, 1n, g, String.length(g), k, low, high, inclusive)

# S7.20 (spec twin) the rounding interval's ends of `m / 2^k`, times 10^(k+2): (4m ± 2)·5^(k+2), the lower end nearer
# (4m − 1) when m is the binade's first mantissa (the double below is half as far)
def shortest_of(+m: List<&2, U32>, +k: Nat) -> Short:
  shortest_from(decimal(mul_pow(k, m, 5)), k,mul_pow(Nat.add(k, 2n), sub(mul_small(m, 4), big_of(Bool.pick(U32, U32.is_eq(cmp(m, mul_pow(52n, big_of(1), 2)), 1), 1, 2))), 5), mul_pow(Nat.add(k, 2n), add(mul_small(m, 4), big_of(2)), 5), Bool.not(is_odd(m)))

# S7.20 (spec twin) the leading zero digits of a text, counted
def zero_run(s: String) -> Nat:
  match s:
    case SNil{}:
      0n
    case SCon{Chr{+c}, rest}:
      Bool.pick(Nat, U32.is_eq(c, 48), Nat.add(zero_run(rest), 1n), 0n)

# S7.20 (spec twin) trailing zero digits moved into the exponent
def trimmed(s: Short) -> Short:
  match s:
    case Short{+d, +xb}:
      Short{String.take(d, Nat.sub(String.length(d), zero_run(String.reverse(d)))), Nat.add(xb, zero_run(String.reverse(d)))}

# S7.20 (spec twin) ryu's plain notation (the only one a lead time reaches): a whole number with `.0`, the point
# inside the digits, or `0.` and leading zeros
def placed(+d: String, +xb: Nat) -> String:
  Bool.pick(String, Nat.is_ge(xb, 1000n), d ++ String.repeat("0", Nat.sub(xb, 1000n)) ++ ".0", Bool.pick(String, Nat.is_gt(Nat.add(String.length(d), xb), 1000n), String.take(d, Nat.sub(Nat.add(String.length(d), xb), 1000n)) ++ "." ++ String.drop(d, Nat.sub(Nat.add(String.length(d), xb), 1000n)), "0." ++ String.repeat("0", Nat.sub(1000n, Nat.add(String.length(d), xb))) ++ d))

# S7.20 (spec twin) a decimal shown
def shown(s: Short) -> String:
  match s:
    case Short{d, xb}:
      placed(d, xb)

# S7.20 (spec twin) a positive double as serde_json writes it
def json_of(d: Dbl) -> String:
  match d:
    case Dbl{m, k}:
      shown(trimmed(shortest_of(m, k)))

# ---------------------------------------------------------------- Rust's `{:.1}` (round half to even on the exact value)

# S7.20 (spec twin) a count of tenths as `N.d`
def tenths_shown(+t: String) -> String:
  Bool.pick(String, Nat.is_lt(String.length(t), 2n), "0." ++ t, String.take(t, Nat.sub(String.length(t), 1n)) ++ "." ++ String.drop(t, Nat.sub(String.length(t), 1n)))

# S7.20 (spec twin) the integer part and the first fraction digit, rounded by the rest
def tenths_cut(+p: String, +k: Nat) -> String:
  Bool.pick(String, Nat.is_eq(k, 0n), p ++ "0", decimal(round_prefix(String.take(p, Nat.add(Nat.sub(String.length(p), k), 1n)), String.drop(p, Nat.add(Nat.sub(String.length(p), k), 1n)))))

# S7.20 (spec twin) exact digits padded so the integer part has at least one digit, then cut into the tenths kept and
# the digits after them
def tenths_digits(+g: String, +k: Nat) -> String:
  tenths_cut(String.repeat("0", Nat.sub(Nat.add(k, 1n), String.length(g))) ++ g, k)

# S7.20 (spec twin) a positive double with one fraction digit
def tenths_of(d: Dbl) -> String:
  match d:
    case Dbl{m, +k}:
      tenths_shown(tenths_digits(decimal(mul_pow(k, m, 5)), k))

# ---------------------------------------------------------------- the mean lead time (S5.170)

# S5.170 (spec twin) `sum as f64 / count as f64` for whole hours (0 < count < 2^24); zero is its own spelling
def mean_json(+sum: U32, +count: U32) -> String:
  Bool.pick(String, U32.is_eq(sum, 0), "0.0", json_of(nearest(big_of(sum), count)))

# S5.170 (spec twin) the mean in hours with one fraction digit
def mean_hours(+sum: U32, +count: U32) -> String:
  Bool.pick(String, U32.is_eq(sum, 0), "0.0", tenths_of(nearest(big_of(sum), count)))

# S5.170 (spec twin) a double moved down by 2^(k+3)
def days_shift(d: Dbl, +k: Nat) -> Dbl:
  match d:
    case Dbl{m, j}:
      Dbl{m, Nat.add(j, Nat.add(k, 3n))}

# S5.170 (spec twin) the mean divided by 24.0: m / 2^k / 24 is the double nearest (m / 3) / 2^(k+3)
def days_of(d: Dbl) -> String:
  match d:
    case Dbl{+m, +k}:
      tenths_of(days_shift(nearest(m, 3), k))

# S5.170 (spec twin) the mean in days with one fraction digit
def mean_days(+sum: U32, +count: U32) -> String:
  Bool.pick(String, U32.is_eq(sum, 0), "0.0", days_of(nearest(big_of(sum), count)))

