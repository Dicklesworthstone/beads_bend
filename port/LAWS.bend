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

# S0.1 the fast twin equals the spec twin, for every input. One `for` per
# line, the goal last; `+x` when the proof needs x more than once.
law fast_is_spec:
  for x: Nat
  {L.core_fast(x) == L.core_spec(x) : Nat}
