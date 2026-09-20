// Sys.remove: remove one file, best effort (remove(3)). The command that tombstones
// issues takes `.beads/last-touched` away when that file names one of them
// (S4.210, S5.18), and Bend's Base has no effect for it. A missing file, a
// directory or a refused removal all answer Unit: the original swallows every
// failure of this sidecar (S5.17).
Term sys_remove_run(Env e, Term* f, IoWork* w) {
  uint64_t n = 0;
  char* path = io_cstr(e, f[0], &n);
  if (!io_nul(path, n)) {
    remove(path);
  }
  free(path);
  return term_pak(CID_UNIT, 0);
}

static void __attribute__((constructor)) sys_remove_use(void) {
  io_eff(CID_SYS_REMOVE, sys_remove_run, 0);
}
