# core/id — the hash part of an issue id (S4.1–S4.6).
# seed bytes -> SHA-256 -> the first 8 digest bytes as one 64-bit value ->
# base 36 -> the LAST `length` characters. The 64-bit value is never formed:
# it is four 16-bit limbs, and base 36 is long division by 36, where every
# intermediate rem * 65536 + limb stays below 36 * 65536 = 2359296
# (docs/NUMERIC_PLAN.md S7.4, S7.5). Nothing here consults the original.
import Base
import ./bytes.bend as Bytes
import ./sha256.bend as Sha

# S7.4 (data) a 64-bit value as four 16-bit limbs, most significant first
type Limbs is Data:
  Limbs{l3: U32, l2: U32, l1: U32, l0: U32}

# S7.5 (data) one limb's quotient and remainder by 36
type QR is Data:
  QR{q: U32, r: U32}

# S7.5 (data) the quotient limbs and the final remainder of one division by 36
type Step is Data:
  Step{quo: Limbs, last: U32}

# S4.1 (spec twin) one length-prefixed part: the BYTE length in decimal, `:`, the bytes
def part(+value: List<&2, U32>) -> List<&2, U32>:
  List.append(&2, U32, Bytes.utf8(Nat.show(List.length(&2, U32, value))), 58 <> value)

# S4.1 S4.2 S4.3 (spec twin) the seed: title, description, creator, the
# created_at nanosecond count in decimal, the nonce in decimal, in that order
def seed(title: String, description: String, creator: String, nanos: String, nonce: Nat) -> List<&2, U32>:
  List.append(&2, U32, part(Bytes.utf8(title)), List.append(&2, U32, part(Bytes.utf8(description)), List.append(&2, U32, part(Bytes.utf8(creator)), List.append(&2, U32, part(Bytes.utf8(nanos)), part(Bytes.utf8(Nat.show(nonce)))))))

# S4.4 (spec twin) digest bytes 0..7, most significant first, are exactly the
# state words a and b: four 16-bit limbs, no shifting past 32 bits
def limbs(st: Sha.H8) -> Limbs:
  match st:
    case Sha.H8{+a, +b, _, _, _, _, _, _}:
      Limbs{(a >> 16n : U32), (a .&. 65535 : U32), (b >> 16n : U32), (b .&. 65535 : U32)}

# S7.5 (spec twin) quotient and remainder of one intermediate (< 2359296) by 36
def qr(+cur: U32) -> QR:
  QR{(cur / 36 : U32), (cur % 36 : U32)}

# S7.5 (spec twin) long division, last limb
def div36_d(q3: U32, q2: U32, q1: U32, s0: QR) -> Step:
  match s0:
    case QR{q0, r0}:
      Step{Limbs{q3, q2, q1, q0}, r0}

# S7.5 (spec twin) long division, third limb
def div36_c(q3: U32, q2: U32, s1: QR, l0: U32) -> Step:
  match s1:
    case QR{q1, r1}:
      div36_d(q3, q2, q1, qr(((r1 * 65536 : U32) + l0 : U32)))

# S7.5 (spec twin) long division, second limb
def div36_b(q3: U32, s2: QR, l1: U32, l0: U32) -> Step:
  match s2:
    case QR{q2, r2}:
      div36_c(q3, q2, qr(((r2 * 65536 : U32) + l1 : U32)), l0)

# S7.5 (spec twin) long division, first limb
def div36_a(s3: QR, l2: U32, l1: U32, l0: U32) -> Step:
  match s3:
    case QR{q3, r3}:
      div36_b(q3, qr(((r3 * 65536 : U32) + l2 : U32)), l1, l0)

# S4.5 (spec twin) value / 36 and value mod 36
def div36(v: Limbs) -> Step:
  match v:
    case Limbs{l3, l2, l1, l0}:
      div36_a(qr(l3), l2, l1, l0)

# S4.5 (spec twin) the quotient of a step
def quo_of(s: Step) -> Limbs:
  match s:
    case Step{quo, _}:
      quo

# S4.5 (spec twin) the remainder of a step
def last_of(s: Step) -> U32:
  match s:
    case Step{_, last}:
      last

# S4.5 (spec twin) unwrap a digit's character
def digit_char(got: Maybe<&2, Char>) -> Char:
  match got:
    case Some{c}:
      c
    case None{}:
      '?'

# S4.5 (spec twin) the base-36 alphabet, lowercase, index 0 is `0`, index 35 is `z`
def digit(n: U32) -> Char:
  digit_char(String.get("0123456789abcdefghijklmnopqrstuvwxyz", U32.to_nat(n)))

# S4.5 S4.6 (spec twin) the LAST n base-36 digits, most significant first.
# Remainders come least significant first, so each is consed in front; a
# value that runs out yields `0` digits, which is S4.6's left padding.
def digits36(n: Nat, +v: Limbs, acc: String) -> String:
  match n:
    case 0n:
      acc
    case 1n+p:
      digits36(p, quo_of(div36(v)), SCon{digit(last_of(div36(v))), acc})

# S4.4 S4.5 S4.6 (spec twin) the hash part of an id for a seed and a length
def hash36(+seed_bytes: List<&2, U32>, length: Nat) -> String:
  digits36(length, limbs(Sha.digest(seed_bytes)), SNil{})

# S4.8 S4.9 (spec twin) route on the band verdicts, narrowest band first
def length_pick(b3: Bool, b4: Bool, b5: Bool, b6: Bool, b7: Bool) -> Nat:
  match b3 b4 b5 b6 b7:
    case True{} _ _ _ _:
      3n
    case False{} True{} _ _ _:
      4n
    case False{} False{} True{} _ _:
      5n
    case False{} False{} False{} True{} _:
      6n
    case False{} False{} False{} False{} True{}:
      7n
    case False{} False{} False{} False{} False{}:
      8n

# S4.8 S4.9 S7.8 (spec twin) the hash length for a store of `count` records (tombstones included,
# S4.10). The original evaluates a birthday bound in 64-bit floats; over an integer count that
# predicate is this finite table, so no float exists in the port (docs/NUMERIC_PLAN.md S7.8).
# The first band (3 up to 163 records) is what every captured case exercises; the later edges are
# S4.9's computed values and stay [inference] until OQ-006's boundary goldens are captured.
# The count is a U32: a Nat of this size inside a law would be a Peano numeral.
def length_for(+count: U32) -> Nat:
  length_pick((count <= 163 : U32), (count <= 983 : U32), (count <= 5898 : U32), (count <= 35389 : U32), (count <= 212339 : U32))

