# BEADS_RUST — the laws. HUMAN-OWNED: an agent may add a law, never weaken or
# delete one. Every law names the spec clause it encodes. Kinds:
#   fast == spec   binds every fast twin to its spec twin (the perf campaign
#                  may only change a fast twin; the law keeps it honest)
#   round trip     decode(encode(x)) == x for every codec the spec names
#   conservation   a quantity the spec says is preserved (totals, counts)
#   closed golden  a small original input whose expected output is pasted
#                  from goldens/ — the checker computes both sides
#   refutation     an impossible case is impossible ({a != b})
# What does NOT belong here: anything the checker must normalize through
# a large Peano Nat (U32.to_nat of a big word, Nat.read of long digit
# strings, whole-report renders); those stay in goldens/ and conform.sh.
import Base
import ./main.bend as L
import ./core/bytes.bend as Bytes
import ./core/sha256.bend as Sha

# S0.1 the fast twin equals the spec twin, for every input. One `for` per
# line, the goal last; `+x` when the proof needs x more than once.
law fast_is_spec:
  for x: Nat
  {L.core_fast(x) == L.core_spec(x) : Nat}

# S4.4 closed golden: SHA-256 of the empty message (FIPS 180-4 / NIST vector)
law sha_empty:
  {Sha.hex(Sha.digest(Bytes.utf8(""))) == "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855" : String}

# S4.4 closed golden: SHA-256 of "abc" (FIPS 180-4 appendix B.1)
law sha_abc:
  {Sha.hex(Sha.digest(Bytes.utf8("abc"))) == "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad" : String}

# S4.4 closed golden: the 56-byte message of FIPS 180-4 appendix B.2, which pads to TWO blocks
law sha_two_blocks:
  {Sha.hex(Sha.digest(Bytes.utf8("abcdbcdecdefdefgefghfghighijhijkijkljklmklmnlmnomnopnopq"))) == "248d6a61d20638b8e5c026930c3e6039a33ce45964ff2167f6ecedd419db06c1" : String}
