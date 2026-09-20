// Clock.wall: Date.now() is the only wall clock JS offers, in milliseconds;
// the fraction is padded to nine digits so both sides answer one format.
function clock_wall() {
  const ms = Date.now();
  return Math.floor(ms / 1000) + "." + String(ms % 1000).padStart(3, "0") + "000000";
}
