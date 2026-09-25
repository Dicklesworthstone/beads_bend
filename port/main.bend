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

# S4.113 DISC-001 DISC-009 (shell) the wall clock as "<epoch seconds>.<nine digits>"; Bend 2.0.20 has none (IO.now
# is a monotonic ticker, OQ-004). Nanoseconds on C, microseconds on JS and the interpreter (DISC-009). Read once
# per run and handed to the core, which uses it only when BEADS_BEND_NOW is unset
def Clock.wall() -> IO(String):
  import "./effs/clock_wall.c"
  import "./effs/clock_wall.js"

# S4.381 S4.397 (shell) standard input read to its end; Base has no effect for it
def Sys.stdin() -> IO(String):
  import "./effs/sys_stdin.c"
  import "./effs/sys_stdin.js"

# S8.12 (shell) the current directory; Base has no effect for it
def Sys.cwd() -> IO(String):
  import "./effs/sys_cwd.c"
  import "./effs/sys_cwd.js"

# S1.2 S8.1 (shell) the command line with each argument's UTF-8 validity (IO.args faults on the JS lane on an invalid
# byte and hides it as U+FFFD on C; OQ-012); the core splits it (Run.argv_flags, Run.argv_texts)
def Sys.argv() -> IO(String):
  import "./effs/sys_argv.c"
  import "./effs/sys_argv.js"

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

# S8.34 S9.11 (shell) drop ONE trailing newline, and nothing else. `String.trim_end` also eats the trailing
# SPACE of `Error: Invalid issue ID format: ` (golden error_show_empty_id), which is part of the message
def drop_one_newline_rev(s: String) -> String:
  match s:
    case SNil{}:
      ""
    case SCon{Chr{+c}, +rest}:
      Bool.pick(String, U32.is_eq(c, 10), rest, SCon{Chr{c}, rest})

# S8.34 (shell) the text without its own final newline; `IO.print_err` adds one back
def without_last_newline(text: String) -> String:
  String.reverse(drop_one_newline_rev(String.reverse(text)))

# S8.34 (shell) stderr, when there is any: print_err ends the text with one newline, as every error text does
def emit_err(text: String, empty: Bool) -> IO(Unit):
  match empty:
    case True{}:
      IO.pure(Unit, Unit{})
    case False{}:
      IO.print_err(without_last_newline(text))

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
def change(+dir: String, w: Run.Write) -> IO(Unit):
  match w:
    case Run.Write{path, None{}}:
      Sys.remove(Run.relocated(dir, path))
    case Run.Write{path, Some{text}}:
      do IO<Unit>:
        r : Result<&1, &1, U32 & String, File> <- File.open(Run.relocated(dir, path), "w")
        write_opened(r, text)

# S5.18 S8.30 (shell) the file changes in the order the core gave them: the store before the sidecar
def change_all(+dir: String, ws: List<&2, Run.Write>) -> IO(Unit):
  match ws:
    case Nil{}:
      IO.pure(Unit, Unit{})
    case Con{w, rest}:
      do IO<Unit>:
        change(dir, w)
        change_all(dir, rest)

# S8.30 S8.34 S8.36 (shell) perform the outcome: the files, then stdout, then stderr, then the exit code
def perform(+dir: String, o: Run.Outcome) -> IO(Unit):
  match o:
    case Run.Outcome{out, +err, +code, writes}:
      do IO<Unit>:
        change_all(dir, writes)
        IO.write(out)
        emit_err(err, String.is_empty(err))
        leave(code, U32.is_eq(code, 0))

# S2.2 (shell) open each candidate directory in turn; the core picks the first that opened (Run.found)
def probe_all(paths: List<&2, String>) -> IO(List<&2, Bool>):
  match paths:
    case Nil{}:
      IO.pure(List<&2, Bool>, Nil{})
    case Con{p, rest}:
      do IO<List<&2, Bool>>:
        ok : Bool <- probe(p)
        oks : List<&2, Bool> <- probe_all(rest)
        return ok <> oks

# S4.397 (shell) the errno of a failed open or read
def side_failed(e: U32 & String) -> Run.Side:
  match e:
    case (code, words):
      Run.SideErr{code}

# S4.397 (shell) a named file after its first read: a failed read keeps its errno, anything else reads on to the end
def side_first(path: String, got: File & Result<&1, &1, U32 & String, List<&2, U32>>) -> IO(Run.Var):
  match got:
    case (f, Fail{e}):
      do IO<Run.Var>:
        File.close(f)
        return Run.side_var(path, side_failed(e))
    case (f, Done{bytes}):
      do IO<Run.Var>:
        all : List<&2, U32> <- read_chunks(1024n, (f, Done{bytes}), Nil{})
        return Run.side_var(path, Run.SideOk{all})

# S4.397 (shell) a named file once the open answered
def side_opened(path: String, r: Result<&1, &1, U32 & String, File>) -> IO(Run.Var):
  match r:
    case Fail{e}:
      IO.pure(Run.Var, Run.side_var(path, side_failed(e)))
    case Done{file}:
      do IO<Run.Var>:
        got : File & Result<&1, &1, U32 & String, List<&2, U32>> <- File.read_bytes(file, 67108864)
        side_first(path, got)

# S4.397 (shell) read one file the argv names, as the variable the core looks up
def side_read(+path: String) -> IO(Run.Var):
  do IO<Run.Var>:
    r : Result<&1, &1, U32 & String, File> <- File.open(path, "r")
    side_opened(path, r)

# S4.397 (shell) read every file the core named (Run.side_files), in order
def side_all(paths: List<&2, String>) -> IO(List<&2, Run.Var>):
  match paths:
    case Nil{}:
      IO.pure(List<&2, Run.Var>, Nil{})
    case Con{p, rest}:
      do IO<List<&2, Run.Var>>:
        v : Run.Var <- side_read(p)
        more : List<&2, Run.Var> <- side_all(rest)
        return v <> more

# S4.381 S4.397 (shell) standard input, read only when the core says the argv names it (Run.wants_stdin)
def stdin_all(wanted: Bool) -> IO(List<&2, Run.Var>):
  match wanted:
    case False{}:
      IO.pure(List<&2, Run.Var>, Nil{})
    case True{}:
      do IO<List<&2, Run.Var>>:
        text : String <- Sys.stdin()
        return Run.stdin_var(text) <> Nil{}

# S8.1 S8.12 S8.13 S4.397 (shell) read the workspace's files and the files the argv names, call the core once, perform
def run_argv(+argv: List<&2, String>, +cwd: String, env: List<&2, Run.Var>, +dir: String) -> IO(Unit):
  do IO<Unit>:
    store : List<&2, U32> <- read_all(Run.inside(dir, "issues.jsonl"))
    touched : List<&2, U32> <- read_all(Run.inside(dir, "last-touched"))
    config : List<&2, U32> <- read_all(Run.inside(dir, "config.yaml"))
    sides : List<&2, Run.Var> <- side_all(Run.side_files(argv))
    input : List<&2, Run.Var> <- stdin_all(Run.wants_stdin(argv))
    wall : String <- Clock.wall()
    perform(dir, Run.outcome(Run.Inputs{argv, Bool.not(String.is_empty(dir)), Run.root_of(dir, cwd), store, touched, Run.Var{"BEADS_BEND_WALL", wall} <> Run.Var{"BEADS_BEND_DIR", dir} <> Run.file_var(".beads/config.yaml", config) <> List.append(&2, Run.Var, input, List.append(&2, Run.Var, sides, env))}))

# S8.1 (shell) run in the directory discovery settled on
def run_in(args: List<&2, String>, +cwd: String, env: List<&2, Run.Var>, +dir: String) -> IO(Unit):
  run_argv(args, cwd, env, dir)

# S2.5 (shell) test the target a directory's redirect names (the core names none, or one)
def redirect_tested(+dir: String, +bytes: List<&2, U32>) -> IO(Run.Redir):
  do IO<Run.Redir>:
    oks : List<&2, Bool> <- probe_all(Run.redirect_paths(dir, bytes))
    return Run.Redir{bytes, oks}

# S2.5 (shell) read a directory's `redirect` file (absent reads as nothing) and test its target
def redirect_probe(+dir: String) -> IO(Run.Redir):
  do IO<Run.Redir>:
    bytes : List<&2, U32> <- read_all(Run.inside(dir, "redirect"))
    redirect_tested(dir, bytes)

# S2.5 (shell) at most ten hops (S2.5): each reads and tests the redirect of the directory the core says the last one
# reached (without a redirect, or with a target that did not open, that is the same directory, so the hops settle);
# then the command runs where the core says, and a target that did not open is handed to the core, which refuses
def redirect_hops(fuel: Nat, args: List<&2, String>, +cwd: String, +env: List<&2, Run.Var>, +dir: String, +r: Run.Redir) -> IO(Unit):
  match fuel:
    case 0n:
      run_in(args, cwd, Run.Var{"BEADS_BEND_REDIRECT_ERROR", Run.redir_error(dir, r)} <> env, Run.redir_dir(dir, r))
    case 1n+g:
      do IO<Unit>:
        next : Run.Redir <- redirect_probe(Run.redir_dir(dir, r))
        redirect_hops(g, args, cwd, env, Run.redir_dir(dir, r), next)

# S2.5 (shell) the found workspace's redirect, followed
def redirect_read(args: List<&2, String>, +cwd: String, +env: List<&2, Run.Var>, +dir: String) -> IO(Unit):
  do IO<Unit>:
    first : Run.Redir <- redirect_probe(dir)
    redirect_hops(10n, args, cwd, env, dir, first)

# S2.1 S2.2 (shell) test the directories discovery names, then run in the first that opened
def discover(args: List<&2, String>, +cwd: String, +env: List<&2, Run.Var>) -> IO(Unit):
  do IO<Unit>:
    oks : List<&2, Bool> <- probe_all(Run.discovery(cwd, Run.env_of(env, "BEADS_DIR")))
    redirect_read(args, cwd, env, Run.found(Run.discovery(cwd, Run.env_of(env, "BEADS_DIR")), oks))

# S1.2 S8.1 (shell) the arguments as the core takes them, their validity flags handed over as `BEADS_BEND_ARGV_OK`
def started(+line: String, +cwd: String, +env: List<&2, Run.Var>) -> IO(Unit):
  discover(Run.argv_texts(line), cwd, Run.Var{"BEADS_BEND_ARGV_OK", Run.argv_flags(line)} <> env)

# S8.1 S8.12 (shell) gather what discovery needs, then discover
def main() -> IO(Unit):
  do IO<Unit>:
    line : String <- Sys.argv()
    cwd : String <- Sys.cwd()
    env : List<&2, Run.Var> <- env_all(Run.env_names())
    started(line, cwd, env)
