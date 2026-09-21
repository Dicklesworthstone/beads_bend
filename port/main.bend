# BEADS_RUST — Bend 2 port: the IO SHELL. It gathers the inputs with one effect
# each, calls the pure core once (core/run.bend: Inputs -> Outcome) and performs
# the outcome. No decision about data is made here. This is the only file that
# reaches a foreign def, and PROOF.bend never imports it (the laws import the core
# only), so the proof book keeps the plain verdict and stays cheap to check. Nothing here consults the original: the spec is
# docs/EXISTING_BEADS_RUST_STRUCTURE.md, the oracle is goldens/.
#
# Check:  bend PROOF.bend                  (laws)   — must print "All terms check."
# Run:    bend main.bend -- <args>         (interpreter lane)
# Build:  bend main.bend -o beads_rust     (C lanes);  bend main.bend -o x.js  (JS lane)
import Base
import ./core/run.bend as Run

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

# S8.13 DISC-008 (shell) the chunks read so far (REVERSED) as one byte string. ONE chunk is answered as it
# is: `List.concat` and `++` walk their left operand with one JavaScript stack frame per element in the
# emitted runtime, which faults above about 30 000 elements (DISC-008), and a store that arrives in one read
# is the only shape the corpus and any plausible workspace produce
def joined_bytes(chunks: List<&2, List<&2, U32>>) -> List<&2, U32>:
  match chunks:
    case Con{one, Nil{}}:
      one
    case other:
      List.concat(&2, U32, List.reverse(&2, List<&2, U32>, other))

# S8.13 (shell) read a file to its end in 64 MiB chunks (DISC-008: one chunk, no join). The loop takes the PREVIOUS read's answer
# as a parameter and recurses on itself (no mutual recursion); fuel bounds it at 1024 chunks of 64 MiB. The fuel literal is kept SMALL on purpose: a Nat literal is a Peano numeral to the checker, and
# `65536n` here cost 15 s of every type-check (and so of every interpreter-lane case and every proof run).
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
            got2 : File & Result<&1, &1, U32 & String, List<&2, U32>> <- File.read_bytes(f, 67108864)
            read_chunks(g, got2, (c <> rest) <> chunks)

# S8.13 (shell) the bytes of an opened file, or nothing when it did not open
def read_opened(r: Result<&1, &1, U32 & String, File>) -> IO(List<&2, U32>):
  match r:
    case Fail{error}:
      IO.pure(List<&2, U32>, Nil{})
    case Done{file}:
      do IO<List<&2, U32>>:
        got : File & Result<&1, &1, U32 & String, List<&2, U32>> <- File.read_bytes(file, 67108864)
        read_chunks(1024n, got, Nil{})

# S8.13 (shell) the bytes of a file
def read_all(path: String) -> IO(List<&2, U32>):
  do IO<List<&2, U32>>:
    r : Result<&1, &1, U32 & String, File> <- File.open(path, "r")
    read_opened(r)

# S8.5 (shell) the value of one environment read; a variable that is not set answers the empty string
def env_value(r: Result<&1, &1, U32 & String, String>) -> String:
  match r:
    case Done{value}:
      value
    case Fail{error}:
      ""

# S8.5 (shell) the environment variables the core names (Run.env_names), each read once, in that order
def env_all(names: List<&2, String>) -> IO(List<&2, Run.Var>):
  match names:
    case Nil{}:
      IO.pure(List<&2, Run.Var>, Nil{})
    case Con{+name, rest}:
      do IO<List<&2, Run.Var>>:
        r : Result<&1, &1, U32 & String, String> <- IO.get_env(name)
        more : List<&2, Run.Var> <- env_all(rest)
        return Run.Var{name, env_value(r)} <> more

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

# S5.17 S8.30 (shell) remove one file, best effort; Base has no effect for it
def Sys.remove(path: String) -> IO(Unit):
  import "./effs/sys_remove.c"
  import "./effs/sys_remove.js"

# S8.30 (shell) the result of one write is not inspected (S5.17: a failed sidecar write never fails the command); close what opened
def written(got: File & Result<&1, &1, U32 & String, Unit>) -> IO(Unit):
  match got:
    case (file, result):
      File.close(file)

# S8.30 (shell) write a whole text into an opened file; a file that did not open is passed over
def write_opened(r: Result<&1, &1, U32 & String, File>, text: String) -> IO(Unit):
  match r:
    case Fail{error}:
      IO.pure(Unit, Unit{})
    case Done{file}:
      do IO<Unit>:
        got : File & Result<&1, &1, U32 & String, Unit> <- File.write(file, text)
        written(got)

# S5.1 S5.17 S8.30 (shell) one file change: the whole new text (the file is created or truncated), or a removal
def change(w: Run.Write) -> IO(Unit):
  match w:
    case Run.Write{path, None{}}:
      Sys.remove(path)
    case Run.Write{path, Some{text}}:
      do IO<Unit>:
        r : Result<&1, &1, U32 & String, File> <- File.open(path, "w")
        write_opened(r, text)

# S5.18 S8.30 (shell) the file changes in the order the core gave them: the store before the sidecar
def change_all(ws: List<&2, Run.Write>) -> IO(Unit):
  match ws:
    case Nil{}:
      IO.pure(Unit, Unit{})
    case Con{w, rest}:
      do IO<Unit>:
        change(w)
        change_all(rest)

# S8.30 S8.34 S8.36 (shell) perform the outcome: the files, then stdout, then stderr, then the exit code
def perform(o: Run.Outcome) -> IO(Unit):
  match o:
    case Run.Outcome{out, +err, +code, writes}:
      do IO<Unit>:
        change_all(writes)
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
    touched : List<&2, U32> <- read_all(".beads/last-touched")
    env : List<&2, Run.Var> <- env_all(Run.env_names())
    perform(Run.outcome(Run.Inputs{args_list(args), workspace, cwd, store, touched, env}))
