// Sys.argv: the command line as one string: a flag per argument (`1` valid UTF-8, `0` not), then each argument, all
// separated by NUL. bun hands an invalid byte xx through as the lone surrogate U+DCxx, which Bend's strings refuse;
// the bytes are rebuilt from it and decoded as WHATWG does (TextDecoder), the same U+FFFD text as the C side (OQ-012).
function sys_argv_bytes(a) {
  const out = [];
  for (let i = 0; i < a.length; i += 1) {
    const c = a.charCodeAt(i);
    const paired = i > 0 && a.charCodeAt(i - 1) >= 0xD800 && a.charCodeAt(i - 1) <= 0xDBFF;
    if (c >= 0xDC80 && c <= 0xDCFF && !paired) {
      out.push(c - 0xDC00);
      continue;
    }
    const cp = a.codePointAt(i);
    if (cp > 0xFFFF) {
      i += 1;
    }
    for (const b of Buffer.from(String.fromCodePoint(cp), "utf8")) {
      out.push(b);
    }
  }
  return Uint8Array.from(out);
}

function sys_argv() {
  const lossy = new TextDecoder("utf-8");
  const strict = new TextDecoder("utf-8", { fatal: true });
  let flags = "";
  const texts = [];
  for (const a of cli_args) {
    const b = sys_argv_bytes(a);
    let ok = "1";
    try {
      strict.decode(b);
    } catch (e) {
      ok = "0";
    }
    flags += ok;
    texts.push(lossy.decode(b));
  }
  return [flags].concat(texts).join("\u0000");
}
