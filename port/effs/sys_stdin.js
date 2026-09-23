// Sys.stdin: standard input read to its end, as a string (UTF-8). `comments add -f -` and
// `--description-file -` read their text from it (S4.381, S4.397). A read error answers "".
function sys_stdin() {
  try {
    return require("fs").readFileSync(0, "utf8");
  } catch (e) {
    return "";
  }
}
