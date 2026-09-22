// Clock.wall: the wall clock as "<seconds>.<nine digits>". JavaScript's finest wall clock is
// performance.timeOrigin + performance.now(), read here to the microsecond; the last three
// digits are always 000 (DISC-009: C reads nanoseconds).
function clock_wall() {
  const us = BigInt(Math.round((performance.timeOrigin + performance.now()) * 1000));
  return (us / 1000000n).toString() + "." + (us % 1000000n).toString().padStart(6, "0") + "000";
}
