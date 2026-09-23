# S4.397 probe: the Sys.stdin effect of port/effs/sys_stdin.{c,js} on every engine: standard input read to its
# end and printed back between brackets, so a missing trailing newline or a short read shows.
import Base

def Sys.stdin() -> IO(String):
  import "../../effs/sys_stdin.c"
  import "../../effs/sys_stdin.js"

def main() -> IO(Unit):
  do IO<Unit>:
    t : String <- Sys.stdin()
    IO.print("[" ++ t ++ "]")
