# BEADS_RUST — Bend 2 port. Structure: a PURE CORE (spec twins, then fast twins
# bound to them by laws in LAWS.bend) and an IO SHELL (args, files, stdout,
# exit codes) that only calls the core. Nothing here consults the original:
# the spec is docs/EXISTING_BEADS_RUST_STRUCTURE.md, the oracle is goldens/.
#
# Spec: every def below names the clause it implements (S<n>.<m>).
# Check:  bend PROOF.bend          (laws)    — must print "All terms check."
# Run:    bend main.bend -- <args> (interp)  — then bend main.bend -o beads_rust
import Base

# ---------------------------------------------------------------- core (pure)

# S0.1 the identity placeholder: replace with the first spec twin. A spec
# twin is the literal, sequential, obviously-correct translation of one
# clause; a fast twin is a second def with the same signature, and
# LAWS.bend states `{fast(x) == spec(x)}`.
# S0.1 (spec twin)
def core_spec(x: Nat) -> Nat:
  x

# S0.1 (fast twin; law fast_is_spec binds it)
def core_fast(x: Nat) -> Nat:
  x

# ---------------------------------------------------------------- shell (IO)

# usage text, verbatim from the original (exit code per S1.2)
# S1.2
def usage() -> IO(Unit):
  IO.die(Unit, 2, "usage: beads_rust <command> [args]")

# dispatch on the first argument. A `match` heads a def body (it is not a
# term inside `do`), so the shell is a chain of small defs like this.
# S1.1
def dispatch(args: List<&1, String>) -> IO(Unit):
  match args:
    case Nil{}:
      usage()
    case cmd <> rest:
      IO.print(Nat.show(core_fast(0n)))

# S8.1, S8.5 (the shell's entry: args in, exit code out)
def main() -> IO(Unit):
  do IO<Unit>:
    args : List<&1, String> <- IO.args()
    dispatch(args)
