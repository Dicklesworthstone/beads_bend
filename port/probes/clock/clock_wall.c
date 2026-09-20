// Clock.wall: CLOCK_REALTIME as "<seconds>.<nanoseconds, nine digits>".
Term clock_wall_run(Env e, Term* f, IoWork* w) {
  struct timespec ts;
  clock_gettime(CLOCK_REALTIME, &ts);
  char buf[48];
  int n = snprintf(buf, sizeof buf, "%lld.%09ld", (long long)ts.tv_sec, (long)ts.tv_nsec);
  return io_str(e, buf, (u64)n);
}

static void __attribute__((constructor)) clock_wall_use(void) {
  io_eff(CID_CLOCK_WALL, clock_wall_run, 0);
}
