// Sys.cwd: the process's current directory; the empty string when it cannot be read.
function sys_cwd() {
  try {
    return process.cwd();
  } catch (e) {
    return "";
  }
}
