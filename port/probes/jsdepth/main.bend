# DISC-008 probe: how big a file can the JS lane read before the emitted
# runtime faults with `bend: memory fault (machine stack overflow?)`, and does
# the shape of the read change the wall? Three readers over the same file:
#   bytes   File.read_bytes into List<&2, U32>, the shape port/main.bend uses
#   text    File.read into a String
#   size    File.size alone, which materializes nothing
# Run:  bend main.bend -- <mode> <path>      (interpreter and C lanes)
#       bun <bundle> -- <mode> <path>        (JS lane, through scripts/js-lane.py)
# The answer is the element count (or the size), so the list must be walked.
import Base

def count_bytes(bs: List<&2, U32>, acc: Nat) -> Nat:
  match bs:
    case Nil{}:
      acc
    case Con{b, rest}:
      count_bytes(rest, (1n + acc : Nat))

def count_chars(s: String, acc: Nat) -> Nat:
  match s:
    case SNil{}:
      acc
    case SCon{c, rest}:
      count_chars(rest, (1n + acc : Nat))

def read_bytes_all(got: File & Result<&1, &1, U32 & String, List<&2, U32>>) -> IO(Nat):
  match got:
    case (f, Fail{e}):
      do IO<Nat>:
        File.close(f)
        return 0n
    case (f, Done{bs}):
      do IO<Nat>:
        File.close(f)
        return count_bytes(bs, 0n)

def read_text_all(got: File & Result<&1, &1, U32 & String, String>) -> IO(Nat):
  match got:
    case (f, Fail{e}):
      do IO<Nat>:
        File.close(f)
        return 0n
    case (f, Done{s}):
      do IO<Nat>:
        File.close(f)
        return count_chars(s, 0n)

def sized(got: File & Result<&1, &1, U32 & String, U32>) -> IO(Nat):
  match got:
    case (f, Fail{e}):
      do IO<Nat>:
        File.close(f)
        return 0n
    case (f, Done{n}):
      do IO<Nat>:
        File.close(f)
        return U32.to_nat(n)

def read_mode(mode: String, file: File) -> IO(Nat):
  match mode:
    case SCon{Chr{98}, rest}:
      do IO<Nat>:
        got : File & Result<&1, &1, U32 & String, List<&2, U32>> <- File.read_bytes(file, 268435456)
        read_bytes_all(got)
    case SCon{Chr{116}, rest}:
      do IO<Nat>:
        got : File & Result<&1, &1, U32 & String, String> <- File.read(file, 268435456)
        read_text_all(got)
    case _:
      do IO<Nat>:
        got : File & Result<&1, &1, U32 & String, U32> <- File.size(file)
        sized(got)

def opened(mode: String, r: Result<&1, &1, U32 & String, File>) -> IO(Nat):
  match r:
    case Fail{e}:
      IO.pure(Nat, 0n)
    case Done{file}:
      read_mode(mode, file)

def run(mode: String, path: String) -> IO(Unit):
  do IO<Unit>:
    r : Result<&1, &1, U32 & String, File> <- File.open(path, "r")
    n : Nat <- opened(mode, r)
    IO.print(Nat.show(n))

def chosen(args: List<String>) -> IO(Unit):
  match args:
    case Con{mode, Con{path, rest}}:
      run(mode, path)
    case _:
      IO.print("usage: <bytes|text|size> <path>")

def main() -> IO(Unit):
  do IO<Unit>:
    args : List<String> <- IO.args()
    chosen(args)
