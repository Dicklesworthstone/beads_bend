// Sys.cwd: the process's current directory as the OS reports it (getcwd).
// The original prints and stores the absolute workspace path (`where`,
// `source_repo_path`, the refusals that quote the store path), and Bend's Base
// has no effect for it. An unreadable directory answers the empty string; the
// core treats that as "no workspace path", never as a default path.
Term sys_cwd_run(Env e, Term* f, IoWork* w) {
  char buf[4096];
  if (getcwd(buf, sizeof buf) == NULL) {
    buf[0] = 0;
  }
  return io_str(e, buf, strlen(buf));
}

static void __attribute__((constructor)) sys_cwd_use(void) {
  io_eff(CID_SYS_CWD, sys_cwd_run, 0);
}
