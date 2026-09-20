# Probe: U32 literal patterns with a default arm, for the decoder's key dispatch.
import Base

def name_of(idx: U32) -> String:
  match idx:
    case 0:
      "zero"
    case 1:
      "one"
    case 2:
      "two"
    case _:
      "other"

def main() -> IO(Unit):
  do IO<Unit>:
    IO.print(name_of(0) ++ " " ++ name_of(2) ++ " " ++ name_of(7))
