// Sys.remove: remove one file, best effort; every failure is swallowed (S5.17).
function sys_remove(path) {
  try {
    require("fs").unlinkSync(path);
  } catch (e) {
    // a missing file or a refused removal changes nothing
  }
  return null;
}
