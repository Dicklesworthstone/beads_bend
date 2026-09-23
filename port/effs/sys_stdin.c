// Sys.stdin: standard input read to its end, as a string. `comments add -f -` and `--description-file -` read
// their text from it (S4.381, S4.397), and Bend's Base has no effect for it. A read error ends the text there.
Term sys_stdin_run(Env e, Term* f, IoWork* w) {
  size_t cap = 65536, n = 0;
  char* buf = malloc(cap);
  if (buf == NULL) {
    return io_str(e, "", 0);
  }
  for (;;) {
    if (n == cap) {
      char* grown = realloc(buf, cap * 2);
      if (grown == NULL) {
        break;
      }
      buf = grown;
      cap *= 2;
    }
    ssize_t r = read(0, buf + n, cap - n);
    if (r <= 0) {
      break;
    }
    n += (size_t)r;
  }
  Term t = io_str(e, buf, (u64)n);
  free(buf);
  return t;
}

static void __attribute__((constructor)) sys_stdin_use(void) {
  io_eff(CID_SYS_STDIN, sys_stdin_run, 0);
}
