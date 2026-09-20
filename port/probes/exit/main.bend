# Probe: how can the port exit with a code and EXACT stream bytes?
# In --json mode the original writes the error envelope to stdout, nothing to
# stderr, and exits 3. IO.die always writes its message to stderr, so this
# probe measures (a) what IO.die(Unit, 3, "") leaves on stderr and (b) whether
# a custom Sys.exit effect exits silently with stdout intact, on every engine.
# Run with no argument for (a), with any argument for (b).
import Base

def Sys.exit(code: U32) -> IO(Unit):
  import "./sys_exit.c"
  import "./sys_exit.js"

def run(mode: List<String>) -> IO(Unit):
  match mode:
    case Con{m, rest}:
      do IO<Unit>:
        IO.write("{\"error\":1}\n")
        Sys.exit(3)
        IO.print("unreachable")
    case Nil{}:
      do IO<Unit>:
        IO.write("{\"error\":1}\n")
        IO.die(Unit, 3, "")

def main() -> IO(Unit):
  do IO<Unit>:
    args : List<String> <- IO.args()
    run(args)
