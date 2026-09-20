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
