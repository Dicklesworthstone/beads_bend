# core/sha256 — SHA-256 (FIPS 180-4) over U32 words, for the id hash (S4.4).
# Wrapping add, rotates and bit operations on U32 are exact. Literals are
# decimal: Bend has no hex literals. Every operator group carries its own
# ( .. : U32): since Bend 2.0.17 an annotation does not reach inside a call
# argument or a constructor field. Proven against published vectors in
# ../LAWS.bend. Spec: docs/EXISTING_BEADS_RUST_STRUCTURE.md.
import Base

# S4.4 (data) the eight working words a..h
type H8 is Data:
  H8{a: U32, b: U32, c: U32, d: U32, e: U32, f: U32, g: U32, h: U32}

# S4.4 (data) the sliding window W[t .. t+15] of the message schedule
type W16 is Data:
  W16{w0: U32, w1: U32, w2: U32, w3: U32, w4: U32, w5: U32, w6: U32, w7: U32, w8: U32, w9: U32, w10: U32, w11: U32, w12: U32, w13: U32, w14: U32, w15: U32}

# S4.4 (spec twin) rotate right by n; m is 32 - n
def rotr(+x: U32, n: Nat, m: Nat) -> U32:
  ((x >> n : U32) .|. (x << m : U32) : U32)

# S4.4 (spec twin) FIPS 180-4 (4.4)
def big0(+x: U32) -> U32:
  (rotr(x, 2n, 30n) .^. rotr(x, 13n, 19n) .^. rotr(x, 22n, 10n) : U32)

# S4.4 (spec twin) FIPS 180-4 (4.5)
def big1(+x: U32) -> U32:
  (rotr(x, 6n, 26n) .^. rotr(x, 11n, 21n) .^. rotr(x, 25n, 7n) : U32)

# S4.4 (spec twin) FIPS 180-4 (4.6)
def small0(+x: U32) -> U32:
  (rotr(x, 7n, 25n) .^. rotr(x, 18n, 14n) .^. (x >> 3n : U32) : U32)

# S4.4 (spec twin) FIPS 180-4 (4.7)
def small1(+x: U32) -> U32:
  (rotr(x, 17n, 15n) .^. rotr(x, 19n, 13n) .^. (x >> 10n : U32) : U32)

# S4.4 (spec twin) FIPS 180-4 (4.2)
def ch(+e: U32, f: U32, g: U32) -> U32:
  ((e .&. f : U32) .^. (U32.not(e) .&. g : U32) : U32)

# S4.4 (spec twin) FIPS 180-4 (4.3)
def maj(+a: U32, +b: U32, +c: U32) -> U32:
  ((a .&. b : U32) .^. (a .&. c : U32) .^. (b .&. c : U32) : U32)

# S4.4 (spec twin) the 64 round constants; the list is the rounds' measure.
# Named so that no pattern binder shares its name: imported as a module, a
# binder `k` would otherwise resolve to this def and be refused.
def round_constants() -> List<U32>:
  [1116352408, 1899447441, 3049323471, 3921009573, 961987163, 1508970993, 2453635748, 2870763221,
   3624381080, 310598401, 607225278, 1426881987, 1925078388, 2162078206, 2614888103, 3248222580,
   3835390401, 4022224774, 264347078, 604807628, 770255983, 1249150122, 1555081692, 1996064986,
   2554220882, 2821834349, 2952996808, 3210313671, 3336571891, 3584528711, 113926993, 338241895,
   666307205, 773529912, 1294757372, 1396182291, 1695183700, 1986661051, 2177026350, 2456956037,
   2730485921, 2820302411, 3259730800, 3345764771, 3516065817, 3600352804, 4094571909, 275423344,
   430227734, 506948616, 659060556, 883997877, 958139571, 1322822218, 1537002063, 1747873779,
   1955562222, 2024104815, 2227730452, 2361852424, 2428436474, 2756734187, 3204031479, 3329325298]

# S4.4 (spec twin) the initial hash value H(0)
def init() -> H8:
  H8{1779033703, 3144134277, 1013904242, 2773480762, 1359893119, 2600822924, 528734635, 1541459225}

# S4.4 (spec twin) one round, FIPS 180-4 section 6.2.2 step 3
def round(st: H8, +k: U32, +w: U32) -> H8:
  match st:
    case H8{+a, +b, +c, +d, +e, +f, +g, +h}:
      +t1 = (h + big1(e) + ch(e, f, g) + k + w : U32)
      +t2 = (big0(a) + maj(a, b, c) : U32)
      H8{(t1 + t2 : U32), a, b, c, (d + t1 : U32), e, f, g}

# S4.4 (spec twin) W[t], the oldest word of the window
def first(w: W16) -> U32:
  match w:
    case W16{w0, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _}:
      w0

# S4.4 (spec twin) slide by one: append W[t+16] = small1(W[t+14]) + W[t+9] + small0(W[t+1]) + W[t]
def slide(w: W16) -> W16:
  match w:
    case W16{w0, +w1, w2, w3, w4, w5, w6, w7, w8, +w9, w10, w11, w12, w13, +w14, w15}:
      nw = (small1(w14) + w9 + small0(w1) + w0 : U32)
      W16{w1, w2, w3, w4, w5, w6, w7, w8, w9, w10, w11, w12, w13, w14, w15, nw}

# S4.4 (spec twin) the 64 rounds; the constant list is the measure
def rounds(ks: List<U32>, st: H8, +w: W16) -> H8:
  match ks:
    case Nil{}:
      st
    case Con{k, rest}:
      rounds(rest, round(st, k, first(w)), slide(w))

# S4.4 (spec twin) the feed-forward addition
def add8(x: H8, y: H8) -> H8:
  match x y:
    case H8{a, b, c, d, e, f, g, h} H8{a2, b2, c2, d2, e2, f2, g2, h2}:
      H8{(a + a2 : U32), (b + b2 : U32), (c + c2 : U32), (d + d2 : U32), (e + e2 : U32), (f + f2 : U32), (g + g2 : U32), (h + h2 : U32)}

# S4.4 (spec twin) one 512-bit block
def compress(+st: H8, w: W16) -> H8:
  add8(st, rounds(round_constants(), st, w))

# S4.4 (spec twin) sixteen words per block; a shorter tail cannot occur after padding
def blocks(ws: List<U32>, st: H8) -> H8:
  match ws:
    case Con{w0, Con{w1, Con{w2, Con{w3, Con{w4, Con{w5, Con{w6, Con{w7, Con{w8, Con{w9, Con{w10, Con{w11, Con{w12, Con{w13, Con{w14, Con{w15, rest}}}}}}}}}}}}}}}}:
      blocks(rest, compress(st, W16{w0, w1, w2, w3, w4, w5, w6, w7, w8, w9, w10, w11, w12, w13, w14, w15}))
    case _:
      st

# S4.4 (spec twin) big-endian words from bytes; acc is reversed (stack-safe on long inputs)
def words_go(bs: List<&2, U32>, acc: List<U32>) -> List<U32>:
  match bs:
    case Con{b0, Con{b1, Con{b2, Con{b3, rest}}}}:
      words_go(rest, ((b0 << 24n : U32) .|. (b1 << 16n : U32) .|. (b2 << 8n : U32) .|. b3 : U32) <> acc)
    case _:
      List.reverse(&1, U32, acc)

# S4.4 (spec twin) the four bytes of a word, most significant first
def be4(+x: U32) -> List<&2, U32>:
  [((x >> 24n : U32) .&. 255 : U32), ((x >> 16n : U32) .&. 255 : U32), ((x >> 8n : U32) .&. 255 : U32), (x .&. 255 : U32)]

# S4.4 (spec twin) n zero bytes
def zeros(n: Nat) -> List<&2, U32>:
  match n:
    case 0n:
      Nil{}
    case 1n+p:
      0 <> zeros(p)

# S4.4 (spec twin) message ++ 0x80 ++ zeros ++ the 64-bit big-endian BIT length.
# The zero count is (119 - len mod 64) mod 64. A message below 2^29 bytes keeps
# the length's high word 0 (NUMERIC_PLAN S7.1: an id seed is bounded by argv).
def pad(+bs: List<&2, U32>) -> List<&2, U32>:
  +len = U32.from_nat(List.length(&2, U32, bs))
  z = ((119 - (len % 64 : U32) : U32) % 64 : U32)
  tail = List.append(&2, U32, zeros(U32.to_nat(z)), List.append(&2, U32, be4((len >> 29n : U32)), be4((len << 3n : U32))))
  List.append(&2, U32, bs, 128 <> tail)

# S4.4 (spec twin) the digest of a byte string
def digest(+bs: List<&2, U32>) -> H8:
  blocks(words_go(pad(bs), Nil{}), init())

# S4.4 (spec twin) unwrap a nibble's character
def nibble(got: Maybe<&2, Char>) -> Char:
  match got:
    case Some{c}:
      c
    case None{}:
      '?'

# S4.4 (spec twin) one lowercase hex digit
def hex1(n: U32) -> Char:
  nibble(String.get("0123456789abcdef", U32.to_nat(n)))

# S4.4 (spec twin) eight lowercase hex digits of a word
def hex8(+x: U32) -> String:
  String.from_list([hex1((x >> 28n : U32)), hex1(((x >> 24n : U32) .&. 15 : U32)), hex1(((x >> 20n : U32) .&. 15 : U32)), hex1(((x >> 16n : U32) .&. 15 : U32)), hex1(((x >> 12n : U32) .&. 15 : U32)), hex1(((x >> 8n : U32) .&. 15 : U32)), hex1(((x >> 4n : U32) .&. 15 : U32)), hex1((x .&. 15 : U32))])

# S4.4 (spec twin) the 64-character lowercase hex form of a digest
def hex(st: H8) -> String:
  match st:
    case H8{a, b, c, d, e, f, g, h}:
      hex8(a) ++ hex8(b) ++ hex8(c) ++ hex8(d) ++ hex8(e) ++ hex8(f) ++ hex8(g) ++ hex8(h)
