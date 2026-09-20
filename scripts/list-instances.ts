// list-instances: load a .bend file the way `bend` does (book_nil -> book_load
// -> book_valid, see <checkout>/bend2/main.ts book_read) and print every
// top-level Def the 2.0.16 verdict counts as unsafe: `t.u === true` (an
// @unsafe def) or a name containing "~" (a template instance), plus the
// template memo (which template, instantiated with which argument key, became
// which instance). `bend` itself prints only the count; this lists the names
// a claim must split into "@unsafe" and "template instances".
//
// usage: bun list-instances.ts <file.bend> [--checkout DIR]
//   The checkout is a bendlang/bend clone; when --checkout is absent it is
//   taken from BEND_CLI ("bun /path/bend2/main.ts" -> /path). The release
//   binary has no such listing, so this needs the checkout.
// exit: 0 complete proof and known count semantics; 2 usage/check/import error.
// Last stdout line: JSON. counted is the disjoint union; compiler_counted
// follows this checkout's cli_report (2.0.13 counts only explicit @unsafe).
// checkout and source hashes identify the code used for this listing.
import * as fs from "node:fs";
import * as path from "node:path";
import { createHash } from "node:crypto";
import { pathToFileURL } from "node:url";

const USAGE = "usage: bun list-instances.ts <file.bend> [--checkout DIR]   (or set BEND_CLI=\"bun /path/bend2/main.ts\")";
const args = process.argv.slice(2);
let file = "";
let checkout = "";
for (let i = 0; i < args.length; i++) {
  if (args[i] === "--checkout") {
    if (checkout || !args[i + 1] || args[i + 1].startsWith("--")) { console.error(USAGE); process.exit(2); }
    checkout = args[++i];
  }
  else if (args[i] === "--help" || args[i] === "-h") { console.log(USAGE); process.exit(0); }
  else if (file || args[i].startsWith("-")) { console.error(USAGE); process.exit(2); }
  else file = args[i];
}
if (!checkout) {
  const cli = process.env.BEND_CLI ?? "";
  const match = cli.match(/(?:^|\s)(?:"([^"\\]*\/bend2\/main\.ts)"|'([^']*\/bend2\/main\.ts)'|([^\s'"\\]*bend2\/main\.ts))(?:\s|$)/);
  const main = match?.[1] ?? match?.[2] ?? match?.[3];
  if (main) checkout = path.dirname(path.dirname(main));
}
if (!file || !checkout) { console.error(USAGE); process.exit(2); }

try {
if (!fs.statSync(file).isFile()) throw new Error("input must be a regular .bend file"); // ubs:ignore[js.node.fs-sync] -- Reject FIFOs/devices before upstream book_load performs a blocking read.
checkout = fs.realpathSync(checkout); // ubs:ignore[js.node.fs-sync] -- One-shot compiler inspection; canonical source identity is required before loading.
const mainPath = path.join(checkout, "bend2", "main.ts");
const bendPath = path.join(checkout, "bend2", "bend.ts");
const mainSource = fs.readFileSync(mainPath, "utf8"); // ubs:ignore[js.node.fs-sync] -- Read the pinned compiler's reporting rule in a sequential CLI.
const reporter = mainSource.match(/function cli_report\([^]*?\n\}/)?.[0] ?? "";
// Refuse unknown reporting semantics instead of extrapolating a version string.
const union = reporter.includes('t.u === true || k.includes("~")');
const explicit = !union && /Object\.values\(book\.tlds\)[^]*?t\.\$ === "Def" && t\.u === true\)\.length/.test(reporter);
if (!union && !explicit) throw new Error("unrecognized checkout cli_report; cannot reconcile unsafe count");
const Bend = await import(pathToFileURL(bendPath).href);
const book = Bend.book_nil();
const seen = new Map<string, string | null>();
await Bend.book_load(book, file, "", seen);
const laws = path.join(path.dirname(file), "LAWS.bend");
if (path.basename(file) === "PROOF.bend" && fs.existsSync(laws) && !seen.has(fs.realpathSync(laws))) { // ubs:ignore[js.node.fs-sync] -- Match the upstream CLI's import completeness check.
  throw new Error("PROOF.bend must import ./LAWS.bend");
}
Bend.book_valid(book, 0);
if (book.hols + book.open > 0) throw new Error(`${book.hols + book.open} TODOs found; incomplete proof`);
const unsafeDefs: string[] = [];
const instances: string[] = [];
for (const [k, t] of Object.entries(book.tlds) as [string, { $: string; u?: boolean }][]) {
  if (t.$ !== "Def") continue;
  if (t.u === true) unsafeDefs.push(k);
  else if (k.includes("~")) instances.push(k);
}
unsafeDefs.sort(); instances.sort();
console.log(`file: ${file}`);
console.log(`tlds: ${Object.keys(book.tlds).length}, counted unsafe: ${unsafeDefs.length + instances.length} = ${unsafeDefs.length} @unsafe + ${instances.length} template instances`);
for (const k of unsafeDefs) console.log(`  @unsafe    ${k}`);
for (const k of instances) console.log(`  instance   ${k}`);
for (const [tk, tm] of Object.entries(book.tmps ?? {}) as [string, { is: Record<string, string> }][]) {
  for (const [key, inst] of Object.entries(tm.is)) console.log(`  memo ${tk} -> ${inst} (key ${key.length} chars)`);
}
const hash = (source: string | Buffer) => createHash("sha256").update(source).digest("hex");
console.log(JSON.stringify({ file, checkout, main_sha256: hash(mainSource), bend_sha256: hash(fs.readFileSync(bendPath)), // ubs:ignore[js.node.fs-sync] -- Fingerprint the inspected source before this one-shot CLI exits.
  tlds: Object.keys(book.tlds).length, unsafe_defs: unsafeDefs, instances, counted: unsafeDefs.length + instances.length,
  count_mode: union ? "explicit-and-instances" : "explicit-only", compiler_counted: unsafeDefs.length + (union ? instances.length : 0) }));
} catch (error) {
  console.error(`error: ${String(error)}`);
  console.log(JSON.stringify({ file, checkout, verdict: "ERROR", reason: String(error) }));
  process.exit(2);
}
