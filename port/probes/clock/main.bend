# OQ-009 probe: does a custom effect load on every engine of the pinned Bend,
# and what precision does each side deliver? Bend 2.0.20's IO.now is a
# monotonic millisecond ticker (OQ-004), so the port needs its own wall clock.
# The answer is a String "<epoch seconds>.<nine fraction digits>": epoch
# nanoseconds (~1.8e18) exceed Nat's 2^48-1, and one read keeps both halves
# of one instant together.
import Base

def Clock.wall() -> IO(String):
  import "./clock_wall.c"
  import "./clock_wall.js"

def main() -> IO(Unit):
  do IO<Unit>:
    t : String <- Clock.wall()
    IO.print(t)
