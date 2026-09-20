# core/scaffold — the scaffold's placeholder twins. LAWS.bend is human-owned and its first law,
# `fast_is_spec`, names them; the first real fast twin arrives in Phase 5. They live in the core,
# not in the shell, so that the proof book never imports main.bend: a book in which one def
# reaches both a foreign effect and the large core costs the 2.0.20 checker tens of seconds.
import Base

# S0.1 (spec twin)
def core_spec(x: Nat) -> Nat:
  x

# S0.1 (fast twin; law fast_is_spec binds it)
def core_fast(x: Nat) -> Nat:
  x
