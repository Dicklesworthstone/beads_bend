# Reproducer (bend 2.0.20): the verdict "N defs rely on unsafe or foreign code"
# becomes expensive when ONE def reaches BOTH a foreign def and a large call
# graph. Measured on this port, 2026-09-20, `bend <file> --check-only`:
#   the whole core under a trivial main, no foreign def ............  3.5 s
#   the same plus one foreign def that nobody calls ................  5.1 s
#   the IO shell alone (two foreign defs, no core import) ..........  0.2 s
#   THIS FILE: main reaches Run.outcome and Sys.exit ............... 30.7 s
#   the core reached through a separate pure def (pure_part) ....... 16.2 s
# Consequences handled in this port: PROOF.bend never imports the shell (the
# scaffold twins moved to core/scaffold.bend: the proof gate went from 41 s to
# 27 s), and scripts/interp-lane.sh caches the compiler's note per book, because
# the interpreter lane type-checks the program for every case.
# To time it:  time bend probe_shell_time.bend --check-only
import Base
import ./core/run.bend as Run

def Sys.exit(code: U32) -> IO(Unit):
  import "./effs/sys_exit.c"
  import "./effs/sys_exit.js"

def show(o: Run.Outcome) -> String:
  match o:
    case Run.Outcome{out, err, code, writes}:
      out

def main() -> IO(Unit):
  do IO<Unit>:
    IO.print(show(Run.outcome(Run.Inputs{Nil{}, False{}, "", Nil{}, Nil{}, Nil{}})))
    Sys.exit(3)
