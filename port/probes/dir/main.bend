# Probe (workspace discovery, S2.2): Bend 2.0.20 has no directory test. Does File.open(<dir>, "r")
# succeed on a directory and fail on a missing path, on every engine? Prints one line per path.
import Base

def opened(r: Result<&1, &1, U32 & String, File>) -> IO(String):
  match r:
    case Done{file}:
      do IO<String>:
        File.close(file)
        return "opens"
    case Fail{error}:
      IO.pure(String, "fails")

def try_path(+p: String) -> IO(Unit):
  do IO<Unit>:
    r : Result<&1, &1, U32 & String, File> <- File.open(p, "r")
    v : String <- opened(r)
    IO.print(p ++ " " ++ v)

def main() -> IO(Unit):
  do IO<Unit>:
    try_path(".")
    try_path("/tmp")
    try_path("./no-such-directory")
    try_path("/etc/hostname")
