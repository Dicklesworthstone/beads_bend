# SHA-256 probe (FIPS 180-4) for the port's id generation and content hash.
# Words are U32 (wrapping add, shifts and bit operations are exact); bytes are
# List<&2, U32>; a String is encoded to UTF-8 here because Base has no encoder.
# Literals are decimal: Bend has no hex literals. Every operator group carries
# its own ( .. : U32): since 2.0.17 an annotation does not reach inside a call
# argument or a constructor field.
import Base

type H8 is Data:
  H8{a: U32, b: U32, c: U32, d: U32, e: U32, f: U32, g: U32, h: U32}

type W16 is Data:
  W16{w0: U32, w1: U32, w2: U32, w3: U32, w4: U32, w5: U32, w6: U32, w7: U32, w8: U32, w9: U32, w10: U32, w11: U32, w12: U32, w13: U32, w14: U32, w15: U32}

def Sha.rotr(+x: U32, n: Nat, m: Nat) -> U32:
  ((x >> n : U32) .|. (x << m : U32) : U32)

def Sha.big0(+x: U32) -> U32:
  (Sha.rotr(x, 2n, 30n) .^. Sha.rotr(x, 13n, 19n) .^. Sha.rotr(x, 22n, 10n) : U32)

def Sha.big1(+x: U32) -> U32:
  (Sha.rotr(x, 6n, 26n) .^. Sha.rotr(x, 11n, 21n) .^. Sha.rotr(x, 25n, 7n) : U32)

def Sha.small0(+x: U32) -> U32:
  (Sha.rotr(x, 7n, 25n) .^. Sha.rotr(x, 18n, 14n) .^. (x >> 3n : U32) : U32)

def Sha.small1(+x: U32) -> U32:
  (Sha.rotr(x, 17n, 15n) .^. Sha.rotr(x, 19n, 13n) .^. (x >> 10n : U32) : U32)

def Sha.ch(+e: U32, f: U32, g: U32) -> U32:
  ((e .&. f : U32) .^. (U32.not(e) .&. g : U32) : U32)

def Sha.maj(+a: U32, +b: U32, +c: U32) -> U32:
  ((a .&. b : U32) .^. (a .&. c : U32) .^. (b .&. c : U32) : U32)

def Sha.k() -> List<U32>:
  [1116352408, 1899447441, 3049323471, 3921009573, 961987163, 1508970993, 2453635748, 2870763221,
   3624381080, 310598401, 607225278, 1426881987, 1925078388, 2162078206, 2614888103, 3248222580,
   3835390401, 4022224774, 264347078, 604807628, 770255983, 1249150122, 1555081692, 1996064986,
   2554220882, 2821834349, 2952996808, 3210313671, 3336571891, 3584528711, 113926993, 338241895,
   666307205, 773529912, 1294757372, 1396182291, 1695183700, 1986661051, 2177026350, 2456956037,
   2730485921, 2820302411, 3259730800, 3345764771, 3516065817, 3600352804, 4094571909, 275423344,
   430227734, 506948616, 659060556, 883997877, 958139571, 1322822218, 1537002063, 1747873779,
   1955562222, 2024104815, 2227730452, 2361852424, 2428436474, 2756734187, 3204031479, 3329325298]

def Sha.init() -> H8:
  H8{1779033703, 3144134277, 1013904242, 2773480762, 1359893119, 2600822924, 528734635, 1541459225}

# One round: the state rotates; T1 and T2 as in FIPS 180-4 section 6.2.2.
def Sha.round(st: H8, +k: U32, +w: U32) -> H8:
  match st:
    case H8{+a, +b, +c, +d, +e, +f, +g, +h}:
      +t1 = (h + Sha.big1(e) + Sha.ch(e, f, g) + k + w : U32)
      +t2 = (Sha.big0(a) + Sha.maj(a, b, c) : U32)
      H8{(t1 + t2 : U32), a, b, c, (d + t1 : U32), e, f, g}

# The window holds W[t .. t+15]; a round reads W[t] and the window slides by
# one, appending W[t+16] = small1(W[t+14]) + W[t+9] + small0(W[t+1]) + W[t].
def Sha.first(w: W16) -> U32:
  match w:
    case W16{w0, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _}:
      w0

def Sha.slide(w: W16) -> W16:
  match w:
    case W16{w0, +w1, w2, w3, w4, w5, w6, w7, w8, +w9, w10, w11, w12, w13, +w14, w15}:
      nw = (Sha.small1(w14) + w9 + Sha.small0(w1) + w0 : U32)
      W16{w1, w2, w3, w4, w5, w6, w7, w8, w9, w10, w11, w12, w13, w14, w15, nw}

def Sha.rounds(ks: List<U32>, st: H8, +w: W16) -> H8:
  match ks:
    case Nil{}:
      st
    case Con{k, rest}:
      Sha.rounds(rest, Sha.round(st, k, Sha.first(w)), Sha.slide(w))

def Sha.add8(x: H8, y: H8) -> H8:
  match x y:
    case H8{a, b, c, d, e, f, g, h} H8{a2, b2, c2, d2, e2, f2, g2, h2}:
      H8{(a + a2 : U32), (b + b2 : U32), (c + c2 : U32), (d + d2 : U32), (e + e2 : U32), (f + f2 : U32), (g + g2 : U32), (h + h2 : U32)}

def Sha.compress(+st: H8, w: W16) -> H8:
  Sha.add8(st, Sha.rounds(Sha.k(), st, w))

# Sixteen words per block; a shorter tail cannot occur after padding.
def Sha.blocks(ws: List<U32>, st: H8) -> H8:
  match ws:
    case Con{w0, Con{w1, Con{w2, Con{w3, Con{w4, Con{w5, Con{w6, Con{w7, Con{w8, Con{w9, Con{w10, Con{w11, Con{w12, Con{w13, Con{w14, Con{w15, rest}}}}}}}}}}}}}}}}:
      Sha.blocks(rest, Sha.compress(st, W16{w0, w1, w2, w3, w4, w5, w6, w7, w8, w9, w10, w11, w12, w13, w14, w15}))
    case _:
      st

def Sha.words(bs: List<&2, U32>) -> List<U32>:
  match bs:
    case Con{b0, Con{b1, Con{b2, Con{b3, rest}}}}:
      ((b0 << 24n : U32) .|. (b1 << 16n : U32) .|. (b2 << 8n : U32) .|. b3 : U32) <> Sha.words(rest)
    case _:
      Nil{}

def Sha.be4(+x: U32) -> List<&2, U32>:
  [((x >> 24n : U32) .&. 255 : U32), ((x >> 16n : U32) .&. 255 : U32), ((x >> 8n : U32) .&. 255 : U32), (x .&. 255 : U32)]

def Sha.zeros(n: Nat) -> List<&2, U32>:
  match n:
    case 0n:
      Nil{}
    case 1n+p:
      0 <> Sha.zeros(p)

# message ++ 0x80 ++ zeros ++ the 64-bit big-endian BIT length; the zero count
# is (119 - len mod 64) mod 64. Lengths below 2^29 bytes keep the high word 0.
def Sha.pad(+bs: List<&2, U32>) -> List<&2, U32>:
  +len = U32.from_nat(List.length(&2, U32, bs))
  z = ((119 - (len % 64 : U32) : U32) % 64 : U32)
  tail = List.append(&2, U32, Sha.zeros(U32.to_nat(z)), List.append(&2, U32, Sha.be4((len >> 29n : U32)), Sha.be4((len << 3n : U32))))
  List.append(&2, U32, bs, 128 <> tail)

def Sha.digest(+bs: List<&2, U32>) -> H8:
  Sha.blocks(Sha.words(Sha.pad(bs)), Sha.init())

# UTF-8: one to four bytes per code point.
def Sha.utf8.four(+c: U32) -> List<&2, U32>:
  [((c >> 18n : U32) .|. 240 : U32), (((c >> 12n : U32) .&. 63 : U32) .|. 128 : U32), (((c >> 6n : U32) .&. 63 : U32) .|. 128 : U32), ((c .&. 63 : U32) .|. 128 : U32)]

def Sha.utf8.three(+c: U32, fits: Bool) -> List<&2, U32>:
  match fits:
    case True{}:
      [((c >> 12n : U32) .|. 224 : U32), (((c >> 6n : U32) .&. 63 : U32) .|. 128 : U32), ((c .&. 63 : U32) .|. 128 : U32)]
    case False{}:
      Sha.utf8.four(c)

def Sha.utf8.two(+c: U32, fits: Bool) -> List<&2, U32>:
  match fits:
    case True{}:
      [((c >> 6n : U32) .|. 192 : U32), ((c .&. 63 : U32) .|. 128 : U32)]
    case False{}:
      Sha.utf8.three(c, (c < 65536 : U32))

def Sha.utf8.one(+c: U32, fits: Bool) -> List<&2, U32>:
  match fits:
    case True{}:
      [c]
    case False{}:
      Sha.utf8.two(c, (c < 2048 : U32))

def Sha.utf8(s: String) -> List<&2, U32>:
  match s:
    case SNil{}:
      Nil{}
    case SCon{Chr{+c}, t}:
      List.append(&2, U32, Sha.utf8.one(c, (c < 128 : U32)), Sha.utf8(t))

def Sha.nibble(got: Maybe<&2, Char>) -> Char:
  match got:
    case Some{c}:
      c
    case None{}:
      '?'

def Sha.hex1(n: U32) -> Char:
  Sha.nibble(String.get("0123456789abcdef", U32.to_nat(n)))

def Sha.hex8(+x: U32) -> String:
  String.from_list([Sha.hex1((x >> 28n : U32)), Sha.hex1(((x >> 24n : U32) .&. 15 : U32)), Sha.hex1(((x >> 20n : U32) .&. 15 : U32)), Sha.hex1(((x >> 16n : U32) .&. 15 : U32)), Sha.hex1(((x >> 12n : U32) .&. 15 : U32)), Sha.hex1(((x >> 8n : U32) .&. 15 : U32)), Sha.hex1(((x >> 4n : U32) .&. 15 : U32)), Sha.hex1((x .&. 15 : U32))])

def Sha.hex(st: H8) -> String:
  match st:
    case H8{a, b, c, d, e, f, g, h}:
      Sha.hex8(a) ++ Sha.hex8(b) ++ Sha.hex8(c) ++ Sha.hex8(d) ++ Sha.hex8(e) ++ Sha.hex8(f) ++ Sha.hex8(g) ++ Sha.hex8(h)

def Sha.of(s: String) -> String:
  Sha.hex(Sha.digest(Sha.utf8(s)))

def main() -> IO(Unit):
  do IO<Unit>:
    IO.print(Sha.of(""))
    IO.print(Sha.of("abc"))
    IO.print(Sha.of("abcdbcdecdefdefgefghfghighijhijkijkljklmklmnlmnomnopnopq"))
    IO.print(Sha.of("Ünïcödé — “quotes” 日本語 🚀"))
