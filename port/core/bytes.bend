# core/bytes — byte strings for the pure core. A byte string is List<&2, U32>
# with every element in 0..255; Base has no UTF-8 encoder, and the id seed
# counts and hashes UTF-8 BYTES, never characters (S4.1, S7.1).
# Spec: docs/EXISTING_BEADS_RUST_STRUCTURE.md. Nothing here consults the original.
import Base

# S4.1 (spec twin) the four-byte form, code points 65536 and above
def utf8_four(+c: U32, acc: List<&2, U32>) -> List<&2, U32>:
  ((c .&. 63 : U32) .|. 128 : U32) <> ((((c >> 6n : U32) .&. 63 : U32) .|. 128 : U32) <> ((((c >> 12n : U32) .&. 63 : U32) .|. 128 : U32) <> (((c >> 18n : U32) .|. 240 : U32) <> acc)))

# S4.1 (spec twin) the three-byte form, code points 2048..65535
def utf8_three(+c: U32, acc: List<&2, U32>, fits: Bool) -> List<&2, U32>:
  match fits:
    case True{}:
      ((c .&. 63 : U32) .|. 128 : U32) <> ((((c >> 6n : U32) .&. 63 : U32) .|. 128 : U32) <> (((c >> 12n : U32) .|. 224 : U32) <> acc))
    case False{}:
      utf8_four(c, acc)

# S4.1 (spec twin) the two-byte form, code points 128..2047
def utf8_two(+c: U32, acc: List<&2, U32>, fits: Bool) -> List<&2, U32>:
  match fits:
    case True{}:
      ((c .&. 63 : U32) .|. 128 : U32) <> (((c >> 6n : U32) .|. 192 : U32) <> acc)
    case False{}:
      utf8_three(c, acc, (c < 65536 : U32))

# S4.1 (spec twin) one code point pushed onto a REVERSED byte accumulator
def utf8_push(+c: U32, acc: List<&2, U32>, fits: Bool) -> List<&2, U32>:
  match fits:
    case True{}:
      c <> acc
    case False{}:
      utf8_two(c, acc, (c < 2048 : U32))

# S4.1 (spec twin) the loop: the string is the measure, acc is reversed
def utf8_go(s: String, acc: List<&2, U32>) -> List<&2, U32>:
  match s:
    case SNil{}:
      List.reverse(&2, U32, acc)
    case SCon{Chr{+c}, t}:
      utf8_go(t, utf8_push(c, acc, (c < 128 : U32)))

# S4.1 (spec twin) the UTF-8 bytes of a string, in order
def utf8(s: String) -> List<&2, U32>:
  utf8_go(s, Nil{})

# ---------------------------------------------------------------- decoding

# S2.24 (data) the decoder's state: continuation bytes still needed, the scalar being built, the
# code points so far (REVERSED), the verdict
type Dec8 is Data:
  Dec8{need: Nat, acc: U32, out: List<&2, U32>, ok: Bool}

# S2.24 (data) the code points of a byte string, or the verdict that it is not UTF-8
type Decoded is Data:
  NotUtf8{}
  Utf8{codes: List<&2, U32>}

# S2.24 (spec twin) a lead byte: ASCII is a scalar by itself; 110xxxxx, 1110xxxx and 11110xxx open a
# sequence of one, two or three continuation bytes; anything else is not UTF-8
def lead(+b: U32, out: List<&2, U32>, ok: Bool, one: Bool, two: Bool, three: Bool, four: Bool) -> Dec8:
  match one two three four:
    case True{} _ _ _:
      Dec8{0n, 0, b <> out, ok}
    case False{} True{} _ _:
      Dec8{1n, (b .&. 31 : U32), out, ok}
    case False{} False{} True{} _:
      Dec8{2n, (b .&. 15 : U32), out, ok}
    case False{} False{} False{} True{}:
      Dec8{3n, (b .&. 7 : U32), out, ok}
    case False{} False{} False{} False{}:
      Dec8{0n, 0, out, False{}}

# S2.24 (spec twin) a continuation byte 10xxxxxx adds six bits; the last one completes the scalar
def cont(is_cont: Bool, left: Nat, +b: U32, +acc: U32, out: List<&2, U32>, ok: Bool) -> Dec8:
  match is_cont left:
    case False{} _:
      Dec8{0n, 0, out, False{}}
    case True{} 0n:
      Dec8{0n, 0, (((acc << 6n : U32)) .|. (b .&. 63 : U32) : U32) <> out, ok}
    case True{} 1n+p:
      Dec8{1n+p, (((acc << 6n : U32)) .|. (b .&. 63 : U32) : U32), out, ok}

# S2.24 (spec twin) one byte
def dec_step(st: Dec8, +b: U32) -> Dec8:
  match st:
    case Dec8{0n, acc, out, ok}:
      lead(b, out, ok, (b < 128 : U32), ((b >= 192 : U32) && (b < 224 : U32)), ((b >= 224 : U32) && (b < 240 : U32)), ((b >= 240 : U32) && (b < 248 : U32)))
    case Dec8{1n+p, acc, out, ok}:
      cont(((b >= 128 : U32) && (b < 192 : U32)), p, b, acc, out, ok)

# S2.24 (spec twin) the loop: the byte list is the measure
def dec_go(bs: List<&2, U32>, st: Dec8) -> Dec8:
  match bs:
    case Nil{}:
      st
    case Con{b, rest}:
      dec_go(rest, dec_step(st, b))

# S2.24 (spec twin) a text that ends inside a sequence, or met a bad byte, is not UTF-8
def dec_end(st: Dec8) -> Decoded:
  match st:
    case Dec8{0n, acc, out, True{}}:
      Utf8{List.reverse(&2, U32, out)}
    case _:
      NotUtf8{}

# S2.24 (spec twin) the code points of a UTF-8 byte string. The structure of every sequence is
# checked; overlong forms, surrogates and scalars past U+10FFFF are not refused yet (OQ register).
def decode(bs: List<&2, U32>) -> Decoded:
  dec_end(dec_go(bs, Dec8{0n, 0, Nil{}, True{}}))

