// Sys.exit: flush both streams, then leave with the code and no message.
Term sys_exit_run(Env e, Term* f, IoWork* w) {
  fflush(stdout);
  fflush(stderr);
  exit((int)(u32)f[0]);
  return term_pak(CID_UNIT, 0);
}

static void __attribute__((constructor)) sys_exit_use(void) {
  io_eff(CID_SYS_EXIT, sys_exit_run, 0);
}
