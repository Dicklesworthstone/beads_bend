// fmt-check: format a .bend file with the Bend repo's formatting-only LSP core
// (tools/bend-fmt-lsp/src/formatter.ts, added at 437d62f / 2.0.16) from the
// command line, without installing anything: an optional, reviewer-neutral
// style gate for a port (SHIP-AND-CERTIFY "The evidence bundle"). It rewrites
// `~(` as `~ (` and normalizes indentation. Its token/indent fingerprint is
// a formatting guard, not a proof of semantic preservation; rerun the gates.
//
// usage: bun fmt-check.ts <file.bend>... [--checkout DIR] [--write]
//   --checkout DIR  a bendlang/bend clone at or after 437d62f; when absent it
//                   is taken from BEND_CLI ("bun /path/bend2/main.ts" -> /path)
//   --write         rewrite each CHANGED file in place (default: report only)
// exit: 0 every file UNCHANGED, 1 at least one CHANGED, 2 usage or a
// FORMAT-ERROR. Last stdout line: JSON {"files":[{"file","verdict","diff_lines"}],"verdict":"UNCHANGED|CHANGED"}
import * as fs from "node:fs";
import * as path from "node:path";
import { pathToFileURL } from "node:url";

const USAGE = "usage: bun fmt-check.ts <file.bend>... [--checkout DIR] [--write]";
const args = process.argv.slice(2);
const files: string[] = [];
let checkout = "";
let write = false;
for (let i = 0; i < args.length; i++) {
  if (args[i] === "--checkout") {
    if (checkout || !args[i + 1] || args[i + 1].startsWith("--")) { console.error(USAGE); process.exit(2); }
    checkout = args[++i];
  }
  else if (args[i] === "--write") write = true;
  else if (args[i] === "--help" || args[i] === "-h") { console.log(USAGE); process.exit(0); }
  else if (args[i].startsWith("-")) { console.error(USAGE); process.exit(2); }
  else files.push(args[i]);
}
if (!checkout) {
  const cli = process.env.BEND_CLI ?? "";
  const match = cli.match(/(?:^|\s)(?:"([^"\\]*\/bend2\/main\.ts)"|'([^']*\/bend2\/main\.ts)'|([^\s'"\\]*bend2\/main\.ts))(?:\s|$)/);
  const main = match?.[1] ?? match?.[2] ?? match?.[3];
  if (main) checkout = path.dirname(path.dirname(main));
}
if (files.length === 0 || !checkout) { console.error(USAGE); process.exit(2); }
const fmtPath = path.resolve(checkout, "tools", "bend-fmt-lsp", "src", "formatter.ts");
if (!fs.existsSync(fmtPath)) { console.error(`error: ${fmtPath} not found (the formatter arrived at 437d62f, 2.0.16)`); process.exit(2); } // ubs:ignore[js.node.fs-sync] -- One-shot CLI; synchronous metadata lookup has no server event loop to block.
let formatBend: (source: string, options: {tabSize: number; insertSpaces: boolean}) => string;
try {
  ({ formatBend } = await import(pathToFileURL(fmtPath).href));
  if (typeof formatBend !== "function") throw new Error("formatter has no formatBend function");
} catch (error) {
  console.error(`error: ${String(error)}`);
  console.log(JSON.stringify({ files: [], verdict: "FORMAT-ERROR" }));
  process.exit(2);
}

const rows: { file: string; verdict: string; diff_lines: number }[] = [];
const pending: {file: string; source: Buffer; formatted: string}[] = [];
function readRegular(file: string): Buffer {
  const fd = fs.openSync(file, fs.constants.O_RDONLY | fs.constants.O_NONBLOCK); // ubs:ignore[js.node.fs-sync] -- Nonblocking FIFO-safe open for a one-shot CLI.
  try {
    if (!fs.fstatSync(fd).isFile()) throw new Error("format input must be a regular file"); // ubs:ignore[js.node.fs-sync] -- Check the opened descriptor before reading.
    return fs.readFileSync(fd); // ubs:ignore[js.node.fs-sync] -- Sequential regular-file input for this CLI.
  } finally { fs.closeSync(fd); } // ubs:ignore[js.node.fs-sync] -- Close each descriptor immediately, including error paths.
}
let worst = 0;
for (const file of files) {
  let src: string;
  let source: Buffer;
  let formatted: string;
  try {
    source = readRegular(file);
    src = new TextDecoder("utf-8", { fatal: true, ignoreBOM: true }).decode(source);
    formatted = formatBend(src, { tabSize: 2, insertSpaces: true });
    if (typeof formatted !== "string") throw new Error("formatter did not return text");
  } catch (e) {
    console.log(`FORMAT-ERROR ${file}: ${String(e)}`);
    rows.push({ file, verdict: "FORMAT-ERROR", diff_lines: -1 });
    worst = 2;
    continue;
  }
  if (formatted === src) {
    console.log(`UNCHANGED ${file} (${src.length} chars)`);
    rows.push({ file, verdict: "UNCHANGED", diff_lines: 0 });
    continue;
  }
  const a = src.split("\n"), b = formatted.split("\n");
  let diffs = 0;
  for (let i = 0; i < Math.max(a.length, b.length); i++) {
    if (a[i] !== b[i]) {
      diffs++;
      if (diffs <= 12) {
        console.log(`  line ${i + 1}:`);
        console.log(`    - ${JSON.stringify(a[i] ?? "<eof>")}`);
        console.log(`    + ${JSON.stringify(b[i] ?? "<eof>")}`);
      }
    }
  }
  console.log(`CHANGED ${file}: ${diffs} line(s) differ (${a.length} -> ${b.length} lines)`);
  rows.push({ file, verdict: "CHANGED", diff_lines: diffs });
  if (worst < 1) worst = 1;
  if (write) pending.push({file, source, formatted});
}
// Validate every input before any rewrite. Invalid UTF-8 and a later parse
// failure must not leave an earlier file partly reformatted.
if (write && worst < 2) {
  try {
    for (const item of pending) {
      if (!readRegular(item.file).equals(item.source)) throw new Error(`input changed during formatting: ${item.file}`);
    }
    for (const item of pending) {
      fs.writeFileSync(item.file, item.formatted); // ubs:ignore[js.node.fs-sync] -- Explicit --write in a sequential CLI; all inputs preflighted first.
      console.log(`wrote ${item.file}`);
    }
  } catch (error) {
    console.error(`FORMAT-ERROR: ${String(error)}`);
    worst = 2;
  }
}
console.log(JSON.stringify({ files: rows, verdict: worst === 0 ? "UNCHANGED" : worst === 1 ? "CHANGED" : "FORMAT-ERROR" }));
process.exit(worst);
