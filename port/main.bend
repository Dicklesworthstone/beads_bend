# BEADS_RUST — Bend 2 port: the IO SHELL. It gathers the inputs with one effect
# each, calls the pure core once (core/run.bend: Inputs -> Outcome) and performs
# the outcome. No decision about data is made here. This is the only file that
# reaches a foreign def, so PROOF.bend (which imports the core through LAWS.bend)
# keeps the plain verdict. Nothing here consults the original: the spec is
# docs/EXISTING_BEADS_RUST_STRUCTURE.md, the oracle is goldens/.
#
# Check:  bend PROOF.bend                  (laws)   — must print "All terms check."
# Run:    bend main.bend -- <args>         (interpreter lane)
# Build:  bend main.bend -o beads_rust     (C lanes);  bend main.bend -o x.js  (JS lane)
import Base
import ./core/run.bend as Run

# ---------------------------------------------------------------- core (pure)

# S0.1 the scaffold's placeholder twins, kept because LAWS.bend is human-owned and
# its law `fast_is_spec` names them; the first real fast twin arrives in Phase 5.
# S0.1 (spec twin)
def core_spec(x: Nat) -> Nat:
  x

# S0.1 (fast twin; law fast_is_spec binds it)
def core_fast(x: Nat) -> Nat:
  x

# ---------------------------------------------------------------- shell (IO)

# S8.36 (shell) leave with a code and NO message. IO.die always writes a line to
# stderr (probe port/probes/exit), which the original's --json errors never do.
def Sys.exit(code: U32) -> IO(Unit):
  import "./effs/sys_exit.c"
  import "./effs/sys_exit.js"

# S8.12 (shell) the current directory; Base has no effect for it
def Sys.cwd() -> IO(String):
  import "./effs/sys_cwd.c"
  import "./effs/sys_cwd.js"

# S8.1 (shell) IO.args answers List<&1, String>; the core takes List<&2, String>, and there is no upcast
def args_list(xs: List<String>) -> List<&2, String>:
  match xs:
    case Nil{}:
      Nil{}
    case Con{x, rest}:
      x <> args_list(rest)

# S8.12 (shell) the verdict of one probe: close what opened
def probed(r: Result<&1, &1, U32 & String, File>) -> IO(Bool):
  match r:
    case Done{file}:
      do IO<Bool>:
        File.close(file)
        return True{}
    case Fail{error}:
      IO.pure(Bool, False{})

# S8.12 (shell) does this path open for reading
def probe(path: String) -> IO(Bool):
  do IO<Bool>:
    r : Result<&1, &1, U32 & String, File> <- File.open(path, "r")
    found : Bool <- probed(r)
    return found

# S8.13 (shell) the chunks read so far (REVERSED) as one byte string
def joined_bytes(chunks: List<&2, List<&2, U32>>) -> List<&2, U32>:
  List.concat(&2, U32, List.reverse(&2, List<&2, U32>, chunks))

# S8.13 (shell) read a file to its end in 65536-byte chunks. The loop takes the PREVIOUS read's answer
# as a parameter and recurses on itself (no mutual recursion); fuel bounds it at 65536 chunks (4 GiB).
# An unreadable file, or one past the budget, answers the empty byte string after closing the handle.
def read_chunks(fuel: Nat, got: File & Result<&1, &1, U32 & String, List<&2, U32>>, chunks: List<&2, List<&2, U32>>) -> IO(List<&2, U32>):
  match fuel:
    case 0n:
      match got:
        case (f, other):
          do IO<List<&2, U32>>:
            File.close(f)
            return Nil{}
    case 1n+g:
      match got:
        case (f, Fail{e}):
          do IO<List<&2, U32>>:
            File.close(f)
            return Nil{}
        case (f, Done{Nil{}}):
          do IO<List<&2, U32>>:
            File.close(f)
            return joined_bytes(chunks)
        case (f, Done{c <> rest}):
          do IO<List<&2, U32>>:
            got2 : File & Result<&1, &1, U32 & String, List<&2, U32>> <- File.read_bytes(f, 65536)
            read_chunks(g, got2, (c <> rest) <> chunks)

# S8.13 (shell) the bytes of an opened file, or nothing when it did not open
def read_opened(r: Result<&1, &1, U32 & String, File>) -> IO(List<&2, U32>):
  match r:
    case Fail{error}:
      IO.pure(List<&2, U32>, Nil{})
    case Done{file}:
      do IO<List<&2, U32>>:
        got : File & Result<&1, &1, U32 & String, List<&2, U32>> <- File.read_bytes(file, 65536)
        read_chunks(65536n, got, Nil{})

# S8.13 (shell) the bytes of a file
def read_all(path: String) -> IO(List<&2, U32>):
  do IO<List<&2, U32>>:
    r : Result<&1, &1, U32 & String, File> <- File.open(path, "r")
    read_opened(r)

# S8.34 (shell) stderr, when there is any: print_err ends the text with one newline, as every error text does
def emit_err(text: String, empty: Bool) -> IO(Unit):
  match empty:
    case True{}:
      IO.pure(Unit, Unit{})
    case False{}:
      IO.print_err(String.trim_end(text))

# S8.36 (shell) exit 0 is a normal return; anything else leaves through Sys.exit
def leave(+code: U32, zero: Bool) -> IO(Unit):
  match zero:
    case True{}:
      IO.pure(Unit, Unit{})
    case False{}:
      Sys.exit(code)

# S8.34 S8.36 (shell) perform the outcome: stdout, then stderr, then the exit code
def perform(o: Run.Outcome) -> IO(Unit):
  match o:
    case Run.Outcome{out, +err, +code}:
      do IO<Unit>:
        IO.write(out)
        emit_err(err, String.is_empty(err))
        leave(code, U32.is_eq(code, 0))

# S8.1 S8.12 (shell) gather, call the core once, perform
def main() -> IO(Unit):
  do IO<Unit>:
    args : List<String> <- IO.args()
    workspace : Bool <- probe(".beads/issues.jsonl")
    cwd : String <- Sys.cwd()
    store : List<&2, U32> <- read_all(".beads/issues.jsonl")
    perform(Run.outcome(Run.Inputs{args_list(args), workspace, cwd, store}))
