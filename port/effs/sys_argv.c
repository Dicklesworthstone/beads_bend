// Sys.argv: the command line as one string: a flag per argument (`1` valid UTF-8, `0` not), then each argument, all
// separated by NUL (which no argument can hold). io_str decodes the bytes as WHATWG does, so an invalid sequence
// reads as U+FFFD, as the original prints it; the flags let the core refuse an invalid VALUE the way the original
// does (S1.2, OQ-012). IO.args cannot: it hands the core the U+FFFD text and no way to tell it from a real one.
static int sys_argv_valid(const char* p, size_t n) {
  size_t need = 0;
  unsigned lo = 0x80, hi = 0xBF;
  for (size_t i = 0; i < n; i += 1) {
    unsigned b = (unsigned char)p[i];
    if (need > 0) {
      if (b < lo || b > hi) {
        return 0;
      }
      lo = 0x80;
      hi = 0xBF;
      need -= 1;
    } else if (b < 0x80) {
      continue;
    } else if (b < 0xC2 || b > 0xF4) {
      return 0;
    } else {
      need = b < 0xE0 ? 1 : b < 0xF0 ? 2 : 3;
      lo   = b == 0xE0 ? 0xA0 : b == 0xF0 ? 0x90 : 0x80;
      hi   = b == 0xED ? 0x9F : b == 0xF4 ? 0x8F : 0xBF;
    }
  }
  return need == 0;
}

Term sys_argv_run(Env e, Term* f, IoWork* w) {
  size_t len = (size_t)io_argc + 1;
  for (int i = 0; i < io_argc; i += 1) {
    len += strlen(io_argv[i]) + 1;
  }
  char* buf = malloc(len);
  if (buf == NULL) {
    return io_str(e, "", 0);
  }
  size_t n = 0;
  for (int i = 0; i < io_argc; i += 1) {
    buf[n++] = sys_argv_valid(io_argv[i], strlen(io_argv[i])) ? '1' : '0';
  }
  for (int i = 0; i < io_argc; i += 1) {
    size_t l = strlen(io_argv[i]);
    buf[n++] = 0;
    memcpy(buf + n, io_argv[i], l);
    n += l;
  }
  Term t = io_str(e, buf, (u64)n);
  free(buf);
  return t;
}

static void __attribute__((constructor)) sys_argv_use(void) {
  io_eff(CID_SYS_ARGV, sys_argv_run, 0);
}
