# S5 (second half) — Plain-text and Quiet output, and the stream each message uses

<!-- Phase 1 spec part. Owner: extractor S5b. Clause range S5.100 upward only;
     S5.1–S5.99 (JSON output and the JSONL store) belong to extractor S5a.
     Table shape is the S5 shape of docs/EXISTING_BEADS_RUST_STRUCTURE.md:
     | S5.n | clause | provenance | cases |
     Provenance is `src/<path>.rs:<line>` relative to legacy/BEADS_RUST_v0.6.0/.
     Ground truth is goldens/<case>.out / .err / .exit, inspected byte by byte
     with `cat -A` and `od -c`. Where the source and a golden disagree, the
     golden wins and the clause says so. -->

Scope of this part: the exact bytes `br --no-db` writes in **Plain** mode
(stdout is a pipe, `NO_COLOR=1`, so no ANSI) and in **Quiet** mode
(`--quiet`/`-q`), for every in-scope command, plus the stdout/stderr split of
every message. JSON bodies, the `{"error":{…}}` envelope and the
`.beads/issues.jsonl` bytes are S5a's.

---

## S5.100–S5.109 — Mode framing, streams, whole-output invariants

| S5.n | clause | provenance | cases |
|---|---|---|---|
| S5.100 | Five output modes exist: Rich, Plain, Json, Toon, Quiet. Under the pinned capture environment (`NO_COLOR=1` set, stdout a pipe) every run without `--json`/`--robot` and without `--quiet` is **Plain**; `--json` or `--robot` selects Json; `--quiet`/`-q` selects Quiet. Plain output carries no ANSI escape: every byte in the plain goldens is literal text | `src/output/mod.rs:1` (mode-detection doc), `src/output/context.rs:773` | `list_plain`, `list_quiet`, `list_json` |
| S5.101 | **Rich (TTY tables, panels, ANSI) and TOON (`--format toon`, `BR_OUTPUT_FORMAT=toon`) output are OUT OF SCOPE for the port** and are not specified here; every Rich branch named in the provenance below is unreachable while stdout is a pipe, and no captured case enters it | `docs/PLAN_TO_PORT_BEADS_RUST_TO_BEND2.md` §3 exclusions; `src/output/context.rs:895` | `list_plain`, `show_plain`, `stats_plain` (piped stdout takes the Plain branch; no golden `.out` or `.err` holds an escape byte); no case enters Rich or TOON: excluded surface |
| S5.102 | Every non-empty plain golden ends with exactly one `\n`; there is no case with a missing final newline and **no plain golden contains a trailing space on any line** (verified over all non-`*json*` `.out` and `.err` files). Padding is therefore always interior (`stats`), never at end of line | verified over `goldens/*.out`, `goldens/*.err`; `src/output/context.rs:947` uses `println!` throughout | `stats_plain`, `list_long`, `show_plain` |
| S5.103 | Stream split in Plain mode: ordinary results and the `✓` success lines go to **stdout**; `Warning: …` lines, `Error: …`/`Hint: …` lines and `[note] …` truncation notes go to **stderr**. A command may write both in one run (`dep_remove_absent` writes only stderr; `ready_limit` writes stdout results and a stderr note) | `src/output/context.rs:1236` (success→stdout), `:1252` (error→stderr), `:1266` (warning→stderr), `:1282` (info→stdout) | `dep_remove_absent`, `ready_limit`, `close_already_closed` |
| S5.104 | `ctx.success(m)` in Plain prints `✓ ` + `m` + `\n` to stdout (U+2713, one space). `ctx.warning(m)` prints `Warning: ` + `m` + `\n` to stderr. `ctx.error(m)` prints `Error: ` + `m` + `\n` to stderr. `ctx.info(m)` prints `m` + `\n` to stdout with **no** prefix or glyph. `ctx.print_line(m)` prints `m` + `\n` to stdout. `ctx.newline()` prints a bare `\n` to stdout | `src/output/context.rs:1236,1252,1266,1282,1309` | `create_min` (`✓ Created …`), `dep_list` (info header), `dep_remove_absent` (warning) |
| S5.105 | A terminating error is rendered by the top level as `Error: {message}` and, when a hint exists, a second line `Hint: {hint}`, both on **stderr**, followed by a single `\n`; stdout for that run holds only whatever was already written before the failure. In `close_already_closed`, `close_epic_with_open_child` and `error_close_blocked` stdout is **empty (0 bytes)** while stderr carries `Warning:` then `Error:` then `Hint:`, exit 3. (The error catalogue itself — messages, codes, exit codes — is S9's.) | `src/error/structured.rs:606`, `src/main.rs:1893` | `close_already_closed`, `error_close_blocked`, `error_show_missing` |
| S5.106 | In **Quiet** mode every mode-aware printer is a no-op: `print`, `print_line`, `print_styled_line`, `success`, `warning`, `info` and `newline` emit nothing; only `error` still writes (`Error: {message}` to stderr). A quiet read therefore produces a **0-byte stdout and a 0-byte stderr** with exit 0 | `src/output/context.rs:936,947,973,1236,1266,1282,1309` | `list_quiet` (both streams empty, exit 0) |
| S5.107 | Quiet is additionally short-circuited before rendering in `list`, `ready`, `blocked`, `search`, `show`, `count`, `stats`, `where`, `version`, `epic`, `comments`, `dep` (every subcommand), `label` (every subcommand), `update`, `defer`, `undefer` and `delete`: those commands return before building any text at all. A quiet **mutation** still performs its write and its `.beads/last-touched` update; only the report is suppressed | `list.rs:210`, `ready.rs:197`, `blocked.rs:235`, `search.rs:211`, `show.rs:314`, `count.rs:98,114`, `stats.rs:161`, `where.rs:41`, `version.rs:97`, `epic.rs:89`, `comments.rs:128,250`, `dep.rs:610,697,781,996,1736,2019`, `label.rs:489,517,545,576,622,656,683`, `update.rs:546`, `defer.rs:190,496`, `delete.rs:165,230,355,464,586,755` | `list_quiet`, create_quiet, dep_add_quiet, label_add_quiet, comments_add_quiet, delete_quiet, close_quiet, close_blocked_quiet, defer_quiet, undefer_quiet, reopen_quiet — measured 2026-09-20: each of those mutations writes its files and prints nothing, EXCEPT `reopen`, which prints its `✓ Reopened <id>: <title>` line under `--quiet` all the same (the list above omits `reopen` on purpose), and a `close` that skips every id, which drops the per-item `Warning:` lines (S9.26) but still writes the `Error:`/`Hint:` pair of S9.12 to stderr and exits 3; (case to add: `update_quiet` — `["@fx=basic","update","proj-mta","-p","0","--quiet"]`) |
| S5.108 | `br reopen` is the one in-scope command with **no** Quiet guard: its plain branch writes with bare `print!`/`println!`, which the mode never sees, so `br reopen --quiet` still prints `✓ Reopened …` on stdout. `br create --silent` behaves the same way and for the same reason (S5.205) [inference: no captured case exercises either combination] | `reopen.rs:168-190` (no `is_quiet` branch), `create.rs:171` | (case to add: `reopen_quiet` — `["@fx=basic","reopen","proj-mkh","--quiet"]`; `create_silent_quiet` — `["create","X","--silent","--quiet"]`) |
| S5.109 | Golden-file convention: when a run changed the store, the harness appends `--- .beads/issues.jsonl ---` (and, when it changed, `--- .beads/last-touched ---`) plus the file bodies to the captured **stdout**, and a scenario golden adds `$ [argv]` headers and `[exit N]` lines. Those bytes are the harness's, not the command's: the command's own stdout ends at the first `--- .beads/` line | `scripts/ws_inner.py:212`, `scripts/make-fixture.sh:26` | `close_basic`, `scn_lifecycle` |

---

## S5.110–S5.119 — Shared plain-text primitives

| S5.n | clause | provenance | cases |
|---|---|---|---|
| S5.110 | Status icons, one per status, used wherever a status glyph appears: `○` U+25CB open · `◐` U+25D0 in_progress · `●` U+25CF blocked · `❄` U+2744 deferred **and** draft · `✓` U+2713 closed · `✗` U+2717 tombstone · `📌` U+1F4CC pinned · `?` U+003F any custom status | `src/format/text.rs:15-32,105-116` | `list_all` (`◐ ○ ✓ ❄`), `search_status` (`✓`) |
| S5.111 | Priority renders as `P` followed by the decimal priority number (`P0`…`P4`); the priority **badge** is `[● ` + that label + `]`, always with `●` U+25CF regardless of the issue's status. The type **badge** is `[` + the type label + `]` (`[task]`, `[bug]`, `[feature]`, `[epic]`, `[docs]`, `[chore]`, `[question]`, or the custom type verbatim) | `src/format/text.rs:120,184,190,196` | `list_plain`, `ready_plain`, `blocked_plain` |
| S5.112 | Every untrusted single-line field (id, title, label, author, type/status label, path, query echo) passes through an inline sanitizer that leaves printable text untouched and replaces **every** control character — including `\n`, `\t`, `\r` — with its Rust `escape_default` form (`\u{1b}`, `\r`, `\n`, `\u{7}`, `\u{9b}`, …). Free-text bodies (description, design, prerequisites, acceptance criteria, notes, comment body) use a second sanitizer that **preserves `\n` and `\t`** and escapes everything else | `src/format/text.rs:40,49,53` | `show_unicode` (a real tab survives inside the description body: `Line two<TAB>tabbed`) |
| S5.113 | Date rendering in plain text: `Created`, `Updated`, `Closed`, `Due`, `Deferred Until`/`Deferred until` all print `%Y-%m-%d` (e.g. `2026-01-01`) — the time of day is never shown. Comment timestamps print `%Y-%m-%d %H:%M UTC` (e.g. `2026-01-01 12:30 UTC`): minute resolution, the literal suffix ` UTC`, no seconds and no offset | `show.rs:1320,1345,1353,1376,1479`, `src/format/text.rs:371,375,381` | `show_plain`, `show_closed`, `show_comments`, `comments_list`, `list_long` |
| S5.114 | Long titles are **not truncated and not wrapped** in the captured (piped) mode. `list`, `search` and `ready` compute a max width only when stdout is a terminal, and pass none otherwise; `blocked` passes width 0 unless `--wrap`. The ellipsis form (`…` as three ASCII dots appended after cutting to `max_len - 3` display columns, by `unicode-width`) therefore never appears in any plain golden | `list.rs:265`, `search.rs:267`, `ready.rs:212`, `blocked.rs:244`, `src/format/text.rs:250-290` | `list_plain` (54-column title printed whole); (case to add: `list_long_title` on a fixture whose title exceeds 200 columns, to pin that no truncation happens when piped) |
| S5.115 | Free-text bodies in `br show` ARE soft-wrapped, at `COLUMNS` when that variable parses to ≥ 20 and at **100** columns otherwise (the sandbox clears the environment, so 100 applies). Wrapping breaks on spaces only, never splits a word, preserves existing line breaks, and carries a line's leading indentation onto its continuations. `--no-wrap` disables it entirely | `show.rs:1196,1208-1245,1189` | `show_unicode` (body shorter than 100 columns, unwrapped); (case to add: `show_wrap_100` on a fixture description longer than 100 columns) |
| S5.116 | The one-line issue summary used by `list` (default), `search` and `list --long`'s first line is exactly `{icon} {id} [● P{n}] [{type}] - {title}`: single spaces between the five parts and the separator is space-hyphen-space | `src/format/text.rs:298-334` | `list_plain`, `search_plain`, `edge_precision_sort_title` |
| S5.117 | The per-issue detail block used by `list --long` lists, in this fixed order and only when the field is present and non-empty: `Status: {status}`, `Priority: P{n}`, `Type: {type}`, `Assignee: {a}`, `Owner: {o}`, `Labels: {l1, l2}` (comma+space joined, already sorted in the store; amended 2026-09-20: golden `list_long` prints NO `Labels:` line for `proj-170`, which carries `auth` and `backend`, so under `--no-db` the rows of the text listing carry no labels and the line never appears; the JSON listing does carry them, S5.33), `Due: {date}`, `Deferred Until: {date}`, then always `Created: {date}` and `Updated: {date}`. `Status`, `Priority` and `Type` are always present | `src/format/text.rs:345-386` | `list_long` (the deferred row shows `Deferred Until: 2027-06-01` between `Type:` and `Created:`) |
| S5.118 | Pluralization is per-message and inconsistent across commands; each message's rule is stated in its own clause. Three families exist: true pluralization (`1 issue` / `3 issues`), the parenthesized escape (`issue(s)`, `dependency link(s)`, `epic(s)`), and hard-coded plurals kept for bd conformance even at count 1 (`Blocked by 1 open dependencies`, S5.141) | `ready.rs:248`, `label.rs:585`, `blocked.rs:441`, `delete.rs:363` | `ready_limit` vs `ready_plain`, `label_list_all`, `blocked_plain` |
| S5.119 | Indentation vocabulary in plain text: two spaces for a sub-item under a header (`  - `, `  -> `, `  <- `, `  backend`, `  status: …`), three spaces for the `epic status` progress lines, four spaces for `blocked --detailed` blocker bullets (`    • `). No tabs are ever emitted | `delete.rs:365`, `show.rs:1454`, `label.rs:526`, `update.rs:1286`, `epic.rs:300`, `blocked.rs:422` | `delete_basic`, `show_plain`, `label_list`, `update_status`, `epic_status` |

---

## S5.120–S5.129 — `list`

| S5.n | clause | provenance | cases |
|---|---|---|---|
| S5.120 | Default `br list` prints one line per issue in result order, each `{icon} {id} [● P{n}] [{type}] - {title}` + `\n`, with **no header, no count, no footer and no separators** | `list.rs:315-319`, `src/format/text.rs:301` | `list_plain`, `list_all`, `list_reverse`, `list_status_in_progress`, `list_unassigned`, `list_label_two_and`, `list_label_any`, `list_title_contains`, `list_deferred`, `list_sort_title`, `list_sort_created`, `list_sort_updated`, `edge_precision_sort_created`, `edge_precision_sort_title` |
| S5.121 | An empty `br list` result prints **nothing at all** — 0 bytes on stdout, 0 on stderr, exit 0. There is no "no issues found" message (kept deliberately for bd conformance) | `list.rs:315` (comment: "bd outputs nothing when no issues found") | `empty_list` |
| S5.122 | `br list --long` prints, per issue, the S5.116 summary line followed by the S5.117 detail lines each prefixed with exactly two spaces, and inserts **one blank line between consecutive issues** — never before the first and never after the last. The output therefore ends `…  Updated: {date}\n` | `list.rs:313,713-725`, `src/format/text.rs:390-398` | `list_long` |
| S5.123 | `br list --all` widens the selection to every status; the rendering is unchanged, so closed rows carry `✓` and deferred rows `❄` | `list.rs:315` | `list_all` |
| S5.124 | When a limit truncated the result set, `br list` writes a note to **stderr** before the listing: `[note] Showing {shown} of {total} issues. Use --limit 0 for all results.` when the total is known from client-side filtering, otherwise `[note] Output truncated to {shown} issues. Use --limit 0 for all results.`. Both are suppressed under `--quiet` and under JSON/TOON | `list.rs:194-208` | (case to add: `list_limit_plain` — `["@fx=basic","list","--limit","2"]`) |
| S5.125 | `br list --quiet` prints nothing on either stream, exit 0 | `list.rs:210` | `list_quiet` |
| S5.126 | An invalid `--sort` value is a validation error, not an empty list: stdout stays empty and stderr carries `Error: Validation failed: sort: invalid sort field 'nonsense'`, exit 4. An invalid `--status` likewise, with the long built-in-status message | `list.rs:855`, `src/error/structured.rs:606` | `list_sort_bad`, `list_status_bad` |
| S5.127 | `br list --tree` indents children under the nearest listed ancestor using `├── ` / `└── ` connectors with `│   ` / `    ` continuation prefixes, prepended to the S5.116 line | `list.rs:805-834` | (case to add: `list_tree` — `["@scn=child_ids"]`-style fixture with dotted child ids, plus `["list","--tree"]`) |
| S5.128 | `br list --pretty` replaces the two-space detail indent with tree connectors: every detail line but the last gets `├── `, the last gets `└── `, and the summary line is unchanged. `--long` additionally adds the `Created:`/`Updated:` pair to that block | `src/format/text.rs:402-421`, `list.rs:279` | (case to add: `list_pretty` — `["@fx=basic","list","--pretty"]`) |
| S5.129 | `br list --fields` and `--json` affect only structured output; the plain renderer ignores `--fields` | `list.rs:257,262` | `list_fields` (JSON; cited for the boundary) |

---

## S5.130–S5.136 — `ready`

| S5.n | clause | provenance | cases |
|---|---|---|---|
| S5.130 | `br ready` prints the header `📋 Ready work ({n} issue{s} with no blockers):` followed by **two** newlines (the format string ends in `\n` and `println!` adds another), producing one blank line, then the numbered list. `📋` is U+1F4CB; `{s}` is empty when `{n}` is 1 and `s` otherwise; `{n}` is the count **after** any `--limit` truncation | `ready.rs:245-251` | `ready_plain` (`3 issues`), `ready_limit` (`1 issue`), `edge_precision_ready` (`8 issues`) |
| S5.131 | Each ready row is `{index}. [● P{n}] [{type}] {id}: {title}` + `\n`, where `{index}` is the 1-based position rendered in decimal with no padding and followed by a period and one space. Note the ordering differs from `list`: badges come **before** the id, and the separator is `: ` not ` - ` | `ready.rs:340-372` | `ready_plain`, `ready_sort_priority`, `ready_sort_oldest`, `ready_type`, `ready_unassigned`, `edge_precision_ready`, `scn_lifecycle`, `scn_child_ids` |
| S5.132 | The ready list has **no trailing blank line**: output ends with the last row's `\n` | verified `od -c goldens/ready_plain.out`; `ready.rs:253` | `ready_plain` |
| S5.133 | An empty ready result prints exactly one of three lines, chosen in this order, on stdout: `✨ All work complete — no issues to work on` when the store holds no active issue at all; `✨ No ready issues match the requested filters or configured ready status group` when any filter (assignee, unassigned, label, type, priority, parent, or a non-default ready status group) was requested; `✨ No ready issues — remaining work is not currently actionable` otherwise. `✨` is U+2728 and the dash is `—` U+2014 | `ready.rs:221,292-302` | `empty_ready` (first form); (cases to add: `ready_filtered_empty` — `["@fx=basic","ready","-l","nosuchlabel"]`; `ready_all_blocked_empty`) |
| S5.134 | When `--limit` truncated the ready set, a note goes to **stderr after** the listing: `[note] Showing {shown} of {total} ready issues. Use --limit 0 for all results.` (`{total}` is the pre-truncation count). Suppressed under `--quiet` | `ready.rs:259-265` | `ready_limit` |
| S5.135 | `--sort priority`, `--sort oldest` and the default change only the row order, never the line format; the header count and numbering are recomputed | `ready.rs:246` | `ready_sort_priority`, `ready_sort_oldest` |
| S5.136 | The ready rendering is state-dependent: after a `close`, the freshly unblocked issue appears in the list with its own type badge (`scn_lifecycle` step 4 shows `1. [● P1] [feature] proj-170: Implement user auth`, which was absent from step 1) | `goldens/scn_lifecycle.out:35` (step 4, `ready`: the quoted row), `goldens/scn_lifecycle.out:2` (step 1, `ready --json`: ids `proj-mta`, `proj-5u2`, `proj-b75` only), the unblocking `close proj-mta` at `goldens/scn_lifecycle.out:20`; steps as written in `goldens/scenarios/lifecycle.scn:4` and `goldens/scenarios/lifecycle.scn:8` | `scn_lifecycle`, `scn_child_ids` |

---

## S5.137–S5.142 — `blocked`

| S5.n | clause | provenance | cases |
|---|---|---|---|
| S5.137 | A non-empty `br blocked` output **begins with a blank line**: the header is printed as `\n🚫 Blocked issues ({total}):\n` plus `println!`'s newline, so the bytes are `\n`, the header line, then one blank line, then the rows. `🚫` is U+1F6AB | `blocked.rs:393` | `blocked_plain`, `scn_lifecycle` |
| S5.138 | `{total}` in the blocked header is the count **before** any `--limit` truncation, so a truncated run shows a header count larger than the number of rows | `blocked.rs:207-213,393` | `blocked_plain` (2 = full count); (case to add: `blocked_limit` — `["@fx=basic","blocked","--limit","1"]`) |
| S5.139 | Each blocked issue renders as two lines. The first is `[● P{n}] {id}: {title}` — note there is **no status icon and no type badge**, unlike `list` and `ready` | `blocked.rs:409` | `blocked_plain`, `scn_lifecycle` |
| S5.140 | The second line is `  Blocked by {count} open dependencies: [{ids}]`, two leading spaces, the blocker ids joined with `, ` inside square brackets, each id stripped of any `:status` suffix | `blocked.rs:441-445,458` | `blocked_plain` (`[proj-mta]`, `[proj-170]`) |
| S5.141 | The word `dependencies` in that line is **never singularized**: a single blocker still prints `Blocked by 1 open dependencies`. This is deliberate bd conformance and is reproduced, not fixed | `blocked.rs:437-439` (comment: "bd uses 'dependencies' even for count=1") | `blocked_plain`, `scn_lifecycle` |
| S5.142 | An empty blocked result prints the single stdout line `✨ No blocked issues` (U+2728) and nothing else, exit 0 | `blocked.rs:388` | `empty_blocked` |

---

## S5.143–S5.155 — `show`

| S5.n | clause | provenance | cases |
|---|---|---|---|
| S5.143 | The `show` header line is `{icon} {id} · {title}` + **three spaces** + `[● {P{n}} · {STATUS}]`, where `·` is U+00B7 with one space on each side and `{STATUS}` is the status name upper-cased (`OPEN`, `IN_PROGRESS`, `CLOSED`, `DEFERRED`, …). The three spaces before `[` are literal and load-bearing | `show.rs:1296-1301` | `show_plain`, `show_comments` (`IN_PROGRESS`), `show_closed` (`CLOSED`), `show_epic`, `show_unicode`, `show_two`, `show_partial_hash` |
| S5.144 | Line 2 is always `Owner: {owner} · Type: {type}`. When the issue has no stored owner the value falls back to the `USER` environment variable, and to the literal `unknown` when that is unset — in the pinned sandbox `USER=tester`, so every golden shows `Owner: tester` even though the fixture records no owner | `show.rs:1304-1314` | `show_plain`, `show_closed`, `show_epic` |
| S5.145 | Line 3 is always `Created: {date} · Updated: {date}` with `%Y-%m-%d` dates and the same ` · ` separator | `show.rs:1317-1322` | `show_plain`, `show_two` |
| S5.146 | Optional metadata lines follow, each on its own line, only when present and in exactly this order: `Assignee: {a}` · `Labels: {l1, l2}` (comma+space) · `Ref: {external_ref}` (non-empty only) · `Due: {date}` · `Deferred until: {date}{countdown}` · `Estimate: {…}` · `Closed: {date} ({reason})` · `Rollup: {status} ({n status, …})`. Note `Deferred until:` here is lower-case `u`, unlike `list --long`'s `Deferred Until:` (S5.117) | `show.rs:1324-1392` | `show_plain` (Assignee+Labels), `show_comments` (Assignee), `show_partial_hash` (Labels), `show_closed` (Closed) |
| S5.147 | `Closed: {date} ({reason})` uses the stored close reason, or the literal `closed` when the record has a closed timestamp but no reason | `show.rs:1371-1379` | `show_closed` (`Closed: 2026-01-01 (Done before the fixture)`) |
| S5.148 | The `Deferred until:` countdown suffix is computed against the current instant: empty once the gate has elapsed; ` (gate opens in under a day)` when under 24 hours remain; ` (gate opens in 1 day)` / ` (gate opens in {n} days)` on an exact multiple of a day; ` (gate opens in over 1 day)` / ` (gate opens in over {n} days)` when a partial day remains | `show.rs:1259-1277,1348-1355` | (case to add: `show_deferred_plain` — `["@fx=basic","show","proj-7vm"]`; the pinned clock makes the countdown deterministic) |
| S5.149 | `Estimate:` renders as `{h}h {m}m` when both are non-zero, `{h}h` when the remainder is zero, and `{m}m` when under an hour; it is omitted when the estimate is absent or zero | `show.rs:1357-1369` | (case to add: `show_estimate` — a fixture issue with `estimated_minutes` 90) |
| S5.150 | Every body section is preceded by **one blank line**. The description has no heading — a blank line then the (wrapped, S5.115) body. `Design:`, `Prerequisites:`, `Acceptance Criteria:` and `Notes:` each get a blank line, then their heading line, then the body | `show.rs:1394-1450` | `show_partial_hash`, `show_two`, `show_unicode` |
| S5.151 | `Dependencies:` is preceded by a blank line and each edge renders as `  -> {id} ({type}) - {title}`: two spaces, ASCII arrow, the dependency type in parentheses, then space-hyphen-space and the target title | `show.rs:1450-1463` | `show_plain`, `show_two` |
| S5.152 | `Dependents:` mirrors it with the reversed arrow: a blank line, the heading, then `  <- {id} ({type}) - {title}` per edge | `show.rs:1465-1478` | `show_plain`, `show_epic`, `show_partial_hash`, `show_two` |
| S5.153 | `Comments:` is preceded by a blank line, then per comment one line `  [{%Y-%m-%d %H:%M UTC}] {author}: {body}` — two leading spaces, the timestamp in square brackets, the author, `: `, and the body. This is a different shape from `comments list` (S5.193) | `show.rs:1477-1489` | `show_comments` |
| S5.154 | Several ids in one `br show` invocation are separated by exactly **one blank line**, emitted before each issue after the first; the ids render in the order given on the command line, and no separator precedes the first or follows the last | `show.rs:366`, `show.rs:221` | `show_two` |
| S5.155 | A `show` that resolves no issue prints nothing on stdout; stderr carries `Error: Issue not found: {id}` + `Hint: Run 'br list' to see available issues.` (exit 3) or the ambiguity pair `Error: Ambiguous ID '{p}': matches [{"id", …}]` + `Hint: Provide more characters of the ID` (exit 3). A successfully resolved partial id renders identically to the full id | `show.rs:234-240`, `src/error/structured.rs:606` | `error_show_missing`, `show_partial_ambiguous`, `show_partial_hash` |

---

## S5.156–S5.160 — `search`

| S5.n | clause | provenance | cases |
|---|---|---|---|
| S5.156 | `br search {q}` prints a header line on stdout, then the matching issues in the S5.116 one-line format. The header is `Found {n} issue(s) matching '{q}'` — the count is always followed by the literal `issue(s)`, and the query is echoed between plain ASCII single quotes, sanitized but not otherwise escaped | `search.rs:321-327,330-333` | `search_plain`, `search_case_insensitive`, `search_description`, `search_unicode`, `search_status` |
| S5.157 | When the page omitted further matches the header verb changes to `Showing`: `Showing {n} issue(s) matching '{q}'` | `search.rs:315-320` | (case to add: `search_limit` — `["@fx=basic","search","a","--limit","1"]`) |
| S5.158 | A search with no matches prints only the header, `Found 0 issue(s) matching '{q}'`, exit 0 — on stdout, with no "not found" error | `search.rs:321` | `search_none`, `empty_search` |
| S5.159 | When the default closed-issue exclusion hid matches, a trailing **stdout** line follows the results: `note: {n} closed match(es) hidden; rerun with --all to include them` | `search.rs:374-380` | (case to add: `search_hidden_closed` — `["@fx=basic","search","work"]`, whose only match is the closed `proj-mkh`) |
| S5.160 | The search truncation note goes to **stdout**, not stderr (unlike `list` and `ready`): `note: showing {shown} search result(s) from offset {offset}; more matches exist. Use --limit 0 for all results (current limit: {limit})` | `search.rs:352-371` (the `stderr` argument is `false` at both text call sites) | (case to add: `search_limit`, as above) |

---

## S5.161–S5.166 — `count`

| S5.n | clause | provenance | cases |
|---|---|---|---|
| S5.161 | Ungrouped `br count` prints the decimal total and nothing else: one line, no label, no thousands separator | `count.rs:109` | `count_plain` (`6`), `count_include_closed` (`8`), `empty_count` (`0`) |
| S5.162 | Grouped `br count --by-*` prints `Total: {n}` first, then one line per group as `{group}: {count}` with **no indentation** | `count.rs:125-133` | `count_by_status`, `count_by_type`, `count_by_assignee`, `count_by_label` |
| S5.163 | The group key for issues with no assignee is the literal `(unassigned)`; for issues with no labels it is the literal `(no labels)`. Both sort into the group list wherever their text places them — in the goldens they lead, ahead of the real names | `count.rs:297,309,316`; `src/storage/sqlite.rs:9303` | `count_by_assignee` (`(unassigned): 4`), `count_by_label` (`(no labels): 4`) |
| S5.164 | An issue with several labels contributes once to **each** of its label groups, so the grouped counts can exceed `Total:` | `count.rs:309-318` | `count_by_label` (4+1+2+1 = 8 > `Total: 6`) |
| S5.165 | `--include-closed` widens the population; the output shape is unchanged | `count.rs:88` | `count_include_closed` |
| S5.166 | `br count --quiet` returns before printing, in both the grouped and ungrouped paths | `count.rs:98,114` | (case to add: `count_quiet` — `["@fx=basic","count","--quiet"]`) |

---

## S5.167–S5.172 — `stats`

| S5.n | clause | provenance | cases |
|---|---|---|---|
| S5.167 | `br stats` opens with `📊 Issue Database Status` (U+1F4CA) followed by a blank line, then the literal line `Summary:` | `stats.rs:1222-1226` | `stats_plain`, `empty_stats` |
| S5.168 | Every summary row is two leading spaces, the label with its colon, spaces padding the whole label field so the **value starts at column 27** (i.e. the two-space indent plus a 24-character label field), then the decimal value. The padding is written literally in the format strings, so the exact byte counts are: `  Total Issues:` + 11 spaces, `  Open:` + 19, `  In Progress:` + 12, `  Blocked:` + 16, `  Closed:` + 17, `  Ready to Work:` + 10, `  Deferred:` + 15, `  Tombstones:` + 13, `  Pinned:` + 17, `  Epics ready to close:` + 3, `  Avg Lead Time:` + 10, `  Deleted:` + 16 | `stats.rs:1228-1266` | `stats_plain` (every row is 27 bytes wide up to the value), `empty_stats` |
| S5.169 | The six rows `Total Issues`, `Open`, `In Progress`, `Blocked`, `Closed`, `Ready to Work` are always printed, even at 0. `Deferred`, `Tombstones`, `Pinned` and `Epics ready to close` are printed **only when greater than zero** | `stats.rs:1228-1246` | `empty_stats` (six rows, no `Deferred`), `stats_plain` (seven rows, `Deferred: 1`) |
| S5.170 | The `Extended:` section — a blank line, the literal `Extended:`, then its rows — appears only when an average lead time exists or tombstones exist. Its `Avg Lead Time` value renders as `{x:.1} hours` when the average is under 24 hours and as `{x/24:.1} days` at 24 hours or more (one fractional digit, half-away-from-zero at the decimal, then the literal unit) | `stats.rs:1249-1267` | `stats_plain` (`2.0 hours`), `scn_lifecycle` final step (`23.2 days`), `empty_stats` (section absent) |
| S5.171 | `br stats` always closes with a blank line then `For more details, use 'br list' to see individual issues.` and the final newline | `stats.rs:1294` | `stats_plain`, `empty_stats` |
| S5.172 | Optional trailing blocks, absent from every captured case, keep the text above byte-stable: per-dimension breakdowns print a blank line, `By {dimension}:`, then `  {key}: {count}` rows; a recent-activity block prints `Recent Activity (last {h} hours):` with six padded rows in the same 27-column shape; a capacity block prints a blank line, `Capacity:`, a header row `  {CAPACITY:<24} {COUNTED:>7} {AGGREGATES:>10} {EXEMPT:>6} {SOFT:>5} {HARD:>5} {REMAINING:>9}  STATE` and one data row per capacity with `-` for absent numbers. Git-derived commit activity is out of scope for the port | `stats.rs:1269-1291,1309-1340` | `stats_plain`, `empty_stats` (none of the three optional blocks appears in either golden), (case to add: `stats_by_type` — `["@fx=basic","stats","--by-type"]`, measured through the sandbox 2026-09-20: a blank line, `By type:`, then six `  {key}: {count}` rows); capacity/activity require configuration the fixtures do not carry |

---

## S5.173–S5.182 — `dep`

| S5.n | clause | provenance | cases |
|---|---|---|---|
| S5.173 | `br dep add` on success prints on stdout `✓ Added dependency: {issue} -> {depends_on} ({type})` — ASCII arrow, type in parentheses. The default type is `blocks`; `external:` targets render verbatim | `dep.rs:640-644` | `dep_add_blocks`, `dep_add_related`, `dep_add_external` |
| S5.174 | A duplicate edge is **not** an error: stdout gets `Dependency already exists: {issue} → {depends_on}` with the **Unicode** arrow `→` U+2192 and no `✓` prefix (it is an info line), exit 0 | `dep.rs:646-650` | `dep_add_duplicate` |
| S5.175 | `br dep remove` on success prints `✓ Removed dependency: {issue} -> {depends_on} ({type})` (ASCII arrow). When the edge does not exist the command still exits 0 but stdout stays **empty** and stderr carries `Warning: Dependency not found: {issue} → {depends_on}` with the Unicode arrow | `dep.rs:788-802` | `dep_remove_absent` (stderr only; the store is still rewritten) |
| S5.176 | `br dep list {id}` prints a header via the info channel (stdout, no glyph): `Dependencies of {id} ({n}):` for the default downward direction, `Dependents of {id} ({n}):` for `--direction up`, `Dependencies and dependents of {id} ({n}):` for `both` | `dep.rs:1032-1046` | `dep_list` |
| S5.177 | Each `dep list` row is `  -> {other_id} ({type}): {title} [P{n}] [{status}]` when the row's subject is the queried issue, and `  <- {other_id} ({type}): {title} [P{n}] [{status}]` when the queried issue is the target. Note the colon after the closing parenthesis — `show` uses ` - ` in the same position (S5.151) | `dep.rs:1048-1067` | `dep_list` |
| S5.178 | `br dep list` on an issue with no edges prints the single stdout line `No dependencies for {id}` (or `No dependents for {id}` / `No dependencies or dependents for {id}` per direction), exit 0, with **no trailing period** | `dep.rs:1014-1024` | `dep_list_none` |
| S5.179 | `br dep tree {id}` prints one line per node: `{indent}{prefix}{id}: {title} [P{n}] [{status}]`, where `{indent}` is two spaces repeated once per depth level and `{prefix}` is empty at depth 0, `├── ` at any deeper node, `├── (truncated) ` when the subtree was cut off, and `├── (shown above) ` when the node repeats an already-printed one. `└──` is never used by this renderer | `dep.rs:1756-1775` | `dep_tree`, `dep_tree_leaf`, `scn_child_ids` (all root-only); (case to add: `dep_tree_children` — a `dep tree` over a node that actually has downward edges, to pin the indent and glyphs) |
| S5.180 | An empty `dep tree` prints the stdout line `No dependency tree for {id}` | `dep.rs:1748` | (case to add: `dep_tree_empty`) |
| S5.181 | `br dep cycles` with no cycles prints `✓ No dependency cycles detected.` (with the trailing period) on stdout. With `--blocking-only` the noun phrase becomes `blocking dependency`: `✓ No blocking dependency cycles detected.`. When archived closed-only cycles were hidden the line instead reads `✓ No active {scope} cycles detected. {n} archived closed-only cycle(s) hidden; rerun with --include-closed to inspect them.` | `dep.rs:2023-2031,2067-2073` | `dep_cycles`, `empty_dep_cycles` |
| S5.182 | When cycles exist, stderr gets `Warning: Found {n} {scope} cycle(s):` and stdout gets one line per cycle, `  {i}. {id1 -> id2 -> …}` (two spaces, 1-based index, period, space, the ids joined by ` -> `) | `dep.rs:2036-2040,2124-2130` | (case to add: `dep_cycles_found` on a fixture that contains a cycle) |

---

## S5.183–S5.190 — `label`

| S5.n | clause | provenance | cases |
|---|---|---|---|
| S5.183 | `br label add` prints one stdout line per (issue, label) pair: `✓ Added label {label} to {id}` when newly added, `✓ Label {label} already exists on {id}` when it was already present. Both carry the `✓` and both exit 0 | `label.rs:131-138,495` | `label_add`, `label_add_existing` |
| S5.184 | `br label remove` prints `✓ Removed label {label} from {id}`, or `✓ Label {label} not found on {id} (no-op)` when it was absent; both exit 0 | `label.rs:139-143` | `label_remove_absent` (the `label_remove` golden uses `--json`) |
| S5.185 | `br label list {id}` prints `Labels for {id}:` then one line per label, two spaces then the label, in the record's (sorted) order | `label.rs:524-527` | `label_list` |
| S5.186 | `br label list {id}` on an issue with no labels prints `No labels for {id}.` — with a trailing period, unlike the `dep list` empty line (S5.178) | `label.rs:522` | (case to add: `label_list_empty` — `["@fx=basic","label","list","proj-5u2"]`) |
| S5.187 | `br label list-all` prints `Labels ({n} total):` then one line per label, `  {label} ({count} issue)` at count 1 and `  {label} ({count} issues)` otherwise — this message **does** pluralize properly | `label.rs:583-589` | `label_list_all` (`auth (1 issue)`, `backend (2 issues)`) |
| S5.188 | With no labels anywhere, `list-all` (and the unique-label form of `list`) prints `No labels in project.` | `label.rs:550,581` | (case to add: `label_list_all_empty` on the empty fixture) |
| S5.189 | `br label rename {old} {new}` prints `✓ Renamed label '{old}' to '{new}' on {n} issue` at count 1 and `… on {n} issues` otherwise, with the names in plain ASCII single quotes | `label.rs:161-169` | (case to add: `label_rename_plain` — `["@fx=basic","label","rename","backend","server"]`; the existing `label_rename` uses `--json`) |
| S5.190 | The two no-change rename paths print, without a `✓`: `Label '{old}' already has that name; no changes made.` when old and new are equal, and `Label '{old}' not found on any issues.` when nothing matched. Both exit 0 | `label.rs:147-159` | (case to add: `label_rename_noop` — `["@fx=basic","label","rename","backend","backend"]`), (case to add: `label_rename_missing` — `["@fx=basic","label","rename","nosuch","other"]`); both re-measured through the sandbox 2026-09-20: the quoted line on stdout, exit 0 |

---

## S5.191–S5.195 — `comments`

| S5.n | clause | provenance | cases |
|---|---|---|---|
| S5.191 | `br comments add` prints the single stdout line `Comment added to {id}` — no `✓`, no quoting of the comment text, no id of the new comment | `comments.rs:139,395-397` | `comments_add` |
| S5.192 | `br comments list {id}` prints the header `Comments for {id}:` | `comments.rs:274,399-401` | `comments_list` |
| S5.193 | Each comment renders as **three** stdout lines: `[{author}] at {%Y-%m-%d %H:%M UTC}`, then the body with trailing newlines stripped (interior `\n`/`\t` preserved), then a **blank line**. The blank line follows every comment including the last, so the output ends with `\n\n` | `comments.rs:275-287` | `comments_list` (bytes end `staging.\n\n`) |
| S5.194 | An issue with no comments prints `No comments for {id}.` (trailing period), exit 0 | `comments.rs:270,403-405` | `comments_list_empty` |
| S5.195 | The `comments list` timestamp shape (`[author] at {ts}` on its own line) differs from the `show` comment shape (`  [{ts}] {author}: {body}` on one line, S5.153); both use minute resolution and the ` UTC` suffix, and neither shows seconds | `comments.rs:276-281` vs `show.rs:1479-1484` | `comments_list`, `show_comments` |

---

## S5.196–S5.199 — `epic status`

| S5.n | clause | provenance | cases |
|---|---|---|---|
| S5.196 | `br epic status` prints, per epic, `{icon} {id} {title}` — the id and title separated by a single space, with **no** `·`, no priority badge and no type badge | `epic.rs:299` | `epic_status`, `scn_lifecycle` |
| S5.197 | The epic glyph is `✓` when the epic is eligible for closure (children exist and all are closed) and `○` otherwise — it does **not** follow the issue's own status icon | `epic.rs:311-326` | `epic_status` (`○`), `scn_lifecycle` step 7 (`✓`) |
| S5.198 | Line 2 is `   Progress: {closed}/{total} children closed ({pct}%)` with **three** leading spaces. The percentage is the integer truncation of `closed * 100 / total`, and 0 when there are no children | `epic.rs:300,435-443` | `epic_status` (`0/1 … (0%)`), `scn_lifecycle` (`1/1 … (100%)`) |
| S5.199 | When the epic is eligible, a third line `   Eligible for closure` (three leading spaces) follows. Every epic block then ends with a bare blank line, so a single-epic output ends `…\n\n`. With no open epics the command prints `No open epics found` | `epic.rs:302-309,97` | `epic_status`, `scn_lifecycle` |

---

## S5.200–S5.202 — `where`, `version`

| S5.n | clause | provenance | cases |
|---|---|---|---|
| S5.200 | `br where` prints the resolved `.beads` directory on line 1 with no indentation, then, each only when known and each with a two-space indent: `  (via redirect from {origin})`, `  prefix: {p}`, `  database: {db path}`, `  jsonl: {jsonl path}`. The `database:` line is printed even in `--no-db` mode, naming the path `beads.db` would occupy | `where.rs:234-248` | `where_plain` |
| S5.201 | `br version` prints one line: `br version {version} ({build})`, extended with ` ({branch}@{commit7})` when both are known, ` ({branch})` with branch only, ` ({commit7})` with commit only, where `{commit7}` is the first 7 characters of the commit hash. The pinned oracle prints `br version 0.6.0 (release) (v0.6.0@b1cfebe)` | `version.rs:117-133`; captured golden `goldens/version_plain.out:1` is exactly `br version 0.6.0 (release) (v0.6.0@b1cfebe)` plus one newline, `goldens/version_plain.exit:1` is `0`, stderr empty | `version_plain` |
| S5.202 | The port cannot truthfully reproduce the original's build metadata; that is OQ-003 and resolves to a DISC, not to a clause here. The **shape** above is what the port must keep | `docs/OPEN_QUESTIONS.md` OQ-003; the metadata is fixed at compile time of the original: `version.rs:33` (crate version), `version.rs:49-53` (build kind), `version.rs:55-58` (commit, branch, rustc, target from build-script variables); the captured bytes the shape is read from: `goldens/version_plain.out:1`, `goldens/version_json.out:1` | `version_plain`, `version_json` |

---

## S5.203–S5.212 — `create`, `q`

| S5.n | clause | provenance | cases |
|---|---|---|---|
| S5.203 | `br create` on success prints the single stdout line `✓ Created {id}: {title}` | `create.rs:224-229` | `create_min`, `create_title_flag`, `scn_dup_title`, `scn_last_touched`, `scn_child_ids` |
| S5.204 | `br q` prints only the new id and a newline — no glyph, no title | `q.rs:241` | `q_basic`, `q_priority` |
| S5.205 | `br create --silent` prints only the new id and a newline, and does so **before** any mode dispatch, so it wins over `--json`, `--quiet` and Rich alike | `create.rs:170-172` | `create_silent`; (case to add: `create_silent_json` — `["create","X","--silent","--json"]`) |
| S5.206 | `br create --dry-run` prints a block on stdout and writes nothing: `Dry run: would create issue {id}` (an info line, no glyph), then `Title: {title}`, `Type: {type}`, `Priority: P{n}`, then `Labels: {l1, l2}` only when `-l` was given, `Parent: {id}` only when `--parent` was given, and `Dependencies: {id, id}` only when `--deps` was given. The golden carries no `--- .beads/` dump, confirming nothing was written | `create.rs:196-220` | `create_dry_run` |
| S5.207 | The dry-run id is a real generated id (`proj-8h9` in the golden), not a placeholder | `create.rs:197` | `create_dry_run` |
| S5.208 | `Priority: P{n}` in the dry-run block comes from the priority's own display form, which is `P` + the number | `src/model/mod.rs:168-172` | `create_dry_run` (`Priority: P2`) |
| S5.209 | Capacity warnings, when any exist, follow the create/update report as `Warning: {text}` lines on stderr; no captured case configures capacity | `create.rs:231-235` | (case to add: `create_capacity_warning` — `["@fx=<fixture with a capacity policy>","create","X"]`; needs a fixture sidecar `.beads/policy.yaml`, which `scripts/ws_inner.py` does not copy today) |
| S5.210 | A create that fails validation prints nothing on stdout; stderr carries `Error: …` (+ `Hint:` where one exists) and the exit code is 3 or 4 per S9 | `src/error/structured.rs:606` | `error_create_empty_title`, `error_create_blank_title`, `error_create_long_title`, `error_create_bad_priority`, `error_create_bad_label`, `error_create_missing_parent` |
| S5.211 | `br q` reports an unusable label on **stderr** as `Warning: invalid label '{label}': {reason}` and continues creating the issue | `q.rs:33-39,129` | (case to add: `q_bad_label` — `["q","X","-l","bad label!"]`) |
| S5.212 | In Quiet mode `br create` (without `--silent`) prints nothing, because its report goes through the mode-aware success/info channels which no-op in Quiet; the issue is still created and `.beads/last-touched` still updated | `create.rs:225`, `src/output/context.rs:1236` | (case to add: `create_quiet` — `["create","X","--quiet"]`) |

---

## S5.213–S5.219 — `update`

| S5.n | clause | provenance | cases |
|---|---|---|---|
| S5.213 | `br update` prints, per updated id, a header line `Updated {id}: {title}` on stdout — no glyph — where `{title}` is the title **after** the update | `update.rs:1284,1327-1333` | `update_status`, `update_priority`, `update_two_ids`, `update_last_touched`, `scn_lifecycle`, `scn_last_touched` |
| S5.214 | Below the header, one indented line per changed field, two leading spaces, in this fixed order and only for fields that actually changed: `  status: {old} → {new}`, `  priority: P{old} → P{new}`, `  type: {old} → {new}`, `  assignee: {old} → {new}`, `  owner: {old} → {new}`. The arrow is `→` U+2192 with a space on each side | `update.rs:1283-1323` | `update_status`, `update_priority`, `update_two_ids`, `scn_lifecycle` |
| S5.215 | An absent old or new assignee/owner renders as the literal `(none)` | `update.rs:1302-1320` | `scn_lifecycle` (`  assignee: (none) → tester`) |
| S5.216 | Changes to title, description, labels, notes, due date, estimate and every other field produce **no** change line: only the five fields of S5.214 are reported, so a pure title change shows just the header carrying the new title | `update.rs:1283-1323` | (case to add: `update_title_plain` — `["@fx=basic","update","proj-mta","--title","Renamed"]`) |
| S5.217 | Several ids in one invocation print their blocks back to back with **no blank line between them**, in the order the ids were given | `update.rs:1417-1437` | `update_two_ids` |
| S5.218 | When a requested update changes nothing at all, the line is `No updates specified for {id}` | `update.rs:1335-1337,1435` | (case to add: `update_noop_plain` — `["@fx=basic","update","proj-mta","-p","1"]`; the existing `update_noop_same_value` uses `--json`) |
| S5.219 | `--claim` renders as the two change lines `  status: open → in_progress` and `  assignee: (none) → {actor}`; a blocked claim instead fails with `Error: Validation failed: claim: cannot claim blocked issue: {blocker ids}` on stderr, exit 4, stdout empty | `update.rs:1250-1277`, `scn_lifecycle` step 2 | `scn_lifecycle`, `error_update_blocked_claim` |

---

## S5.220–S5.228 — `close`, `reopen`

| S5.n | clause | provenance | cases |
|---|---|---|---|
| S5.220 | `br close` prints one stdout line per closed issue: `✓ Closed {id}: {title} ({reason})`. The reason is the stored close reason, which defaults to `done` when `--reason` was not given | `close.rs:453-464,763` | `close_basic` (`(done)`), `close_two`, `scn_lifecycle` (`(Schema done)`), `scn_last_touched` (`(Finished)`) |
| S5.221 | Several ids close in argv order, one line each, with no separator line | `close.rs:762-764` | `close_two` |
| S5.222 | A skipped issue prints `Warning: Skipped {id}: {reason}` on **stderr** (one line per skip), and the reason text is the same string that the terminal error then repeats | `close.rs:466-470,765-767` | `close_already_closed`, `close_epic_with_open_child`, `error_close_blocked` |
| S5.223 | When every requested id was skipped, the run fails: stdout is empty and stderr holds the `Warning:` line(s), then `Error: Nothing to do: all {n} issue(s) skipped — {id}: {reason}[; …][; +{k} more]` (the summary lists at most five id/reason pairs joined by `; `, with a `+{k} more` tail beyond that, and the dash is `—` U+2014), then the matching `Hint:` line. Exit 3 | `close.rs:790-812,812-840` | `close_already_closed`, `close_epic_with_open_child`, `error_close_blocked` |
| S5.224 | When a batch closed some ids and skipped others the run also fails (`CloseIncomplete`), so the `✓ Closed` lines are on stdout **and** a non-zero exit is returned | `close.rs:795-805` | (case to add: `close_mixed` — `["@fx=basic","close","proj-170","proj-mta"]`) |
| S5.225 | `br close --suggest-next` in plain mode appends, after the close lines, a blank line, then `Unblocked {n} issue(s):` on stdout, then one line per newly unblocked issue as `  {id}: {title}` | `close.rs:770-778,472-477` | (case to add: `close_suggest_next_plain` — `["@fx=basic","close","proj-mta","--suggest-next"]`; the existing `close_suggest_next` uses `--json`) |
| S5.226 | A close that matches nothing at all prints `No issues to close.` on stdout, exit 0 | `close.rs:759-761` | (case to add: `close_no_targets`) |
| S5.227 | `br reopen` prints `✓ Reopened {id}: {title}` per reopened issue, extended with ` ({reason})` when `--reason` was given. A skipped issue prints `⊘ Skipped {id}: {reason}` (U+2298) on **stdout** — not stderr — and the run still exits 0. With nothing to do it prints `No issues to reopen.` | `reopen.rs:168-192,427-429` | `reopen_closed`, `reopen_open` (`⊘ Skipped proj-mta: already open`), `scn_last_touched` |
| S5.228 | `close` and `reopen` differ in how they report a skip: `close` uses the warning channel (stderr, `Warning: Skipped …`) and turns it into a terminal error; `reopen` uses a raw stdout line with the `⊘` glyph and exit 0 | `close.rs:765` vs `reopen.rs:181-189` | `close_already_closed` vs `reopen_open` |

---

## S5.229–S5.235 — `defer`, `undefer`

| S5.n | clause | provenance | cases |
|---|---|---|---|
| S5.229 | `br defer` prints one stdout line per deferred issue: `⏱ Deferred {id}: {title} (until {defer_until})` when a target instant was resolved, and `⏱ Deferred {id}: {title} (indefinitely)` otherwise. `⏱` is U+23F1 with no variation selector | `defer.rs:196-210` | `defer_no_until` (`(indefinitely)`) |
| S5.230 | The `(until …)` value is the resolved instant in the same RFC 3339 form the JSON path emits, i.e. with an explicit `+00:00` offset rather than `Z` (`2027-06-01T09:00:00+00:00`, `2026-01-02T04:04:05+00:00` for `--until +1h`), not a `%Y-%m-%d` date | `defer.rs:205`, `defer_until_date.out` / `defer_relative.out` JSON bodies | (case to add: `defer_until_plain` — `["@fx=basic","defer","proj-mta","--until","2027-06-01"]`) |
| S5.231 | A skipped defer prints `⊘ Skipped {id}: {reason}` on stdout, exit 0; with nothing to do, `No issues to defer.` | `defer.rs:211-219` | (case to add: `defer_skipped`) |
| S5.232 | `br undefer` prints `✓ Undeferred {id}: {title} (now {status})` per issue | `defer.rs:504-512` | (case to add: `undefer_plain` — `["@fx=basic","undefer","proj-7vm"]`; the existing `undefer_basic` uses `--json`) |
| S5.233 | An undefer of an issue that is not deferred is a skip, not an error: stdout gets `⊘ Skipped {id}: not deferred (status: {status})`, exit 0 | `defer.rs:513-517` | `undefer_not_deferred` |
| S5.234 | With nothing to undefer, stdout gets `No issues to undefer.` | `defer.rs:518-520` | (case to add: `undefer_no_targets`) |
| S5.235 | An unparseable `--until` never reaches the renderer: stdout stays empty and stderr carries `Error: Validation failed: defer_until: invalid time format (try: +1h, -7d, tomorrow, next-week, or 2025-01-15)`, exit 4 | `src/error/structured.rs:606` | `error_defer_bad_until` |

---

## S5.236–S5.244 — `delete`

| S5.n | clause | provenance | cases |
|---|---|---|---|
| S5.236 | A completed `br delete` prints on stdout `Deleted {n} issue(s):` — no glyph, with a colon — then one line per id as `  - {id}`, then, only when greater than zero, `Removed {n} dependency link(s)` | `delete.rs:363-370` | `delete_basic`, `delete_with_dependents_force` |
| S5.237 | With `--force`, any dependent left without its blocker is reported after the removal count as `Orphaned {n} issue(s):` followed by one `  - {id}` line each | `delete.rs:371-376` | `delete_with_dependents_force` |
| S5.238 | A second delete renderer exists for multi-workspace routing and differs in bytes (`✓ Deleted {n} issue(s)` via the success channel, without the colon, with `Removed …` as an info line and `Orphaned …` as a stderr warning). No `--no-db` single-workspace case reaches it; the S5.236/S5.237 form is what the goldens show and what the port reproduces | `delete.rs:591-610` (routed) vs `delete.rs:363` (local) | `delete_basic` (local form) |
| S5.239 | `br delete --dry-run` prints `Dry-run: Would delete {n} issue(s):` then one line per issue as `  - {id}: {title}` (id **and** title, unlike the applied form), and writes nothing | `delete.rs:240-250` | `delete_dry_run` |
| S5.240 | Deleting an issue that others depend on, without `--force` and without `--cascade`, is a **preview** that changes nothing and exits 0. Its stdout block is, in order: `The following issues depend on issues being deleted:`; one `  - {id}` line per direct dependent; then, only when the transitive closure is larger than that set, a blank line, `{k} additional issue(s) would be transitively affected by --cascade:` and one `  - {id}` line per additional id; then a blank line; then `Use --force to orphan these dependents, or --cascade to delete them recursively.`; then, when the closure is non-empty, `--cascade would delete {m} total dependent(s).`; then `No changes made (preview mode).` | `delete.rs:174-202` | `delete_with_dependents` |
| S5.241 | In that preview `{k}` is the closure size minus the direct-dependent count and `{m}` is the whole closure size — in the golden, 1 additional and 2 total | `delete.rs:178-181,195-199` | `delete_with_dependents` |
| S5.242 | `br delete --hard` with no ids purges tombstones and prints `Dry-run: Would purge {n} tombstone(s):` + `  - {id}` lines under `--dry-run`, `Dry-run: no tombstones to purge.` when there are none, and `✓ No tombstones to purge.` when a real purge finds none | `delete.rs:415-425,464-470` | (case to add: `delete_hard_purge_empty` — `["@fx=basic","delete","--hard"]`) |
| S5.243 | `br delete` with no ids at all is a validation failure, not an empty run: stderr `Error: Validation failed: ids: no issue IDs provided`, exit 4, stdout empty. (`show`, `update` and `close` instead fall back to `.beads/last-touched` and fail only when it is empty, with `… and no last-touched issue`.) | `delete.rs` id resolution; `src/error/structured.rs:606` | `usage_delete_alone`, `usage_show_alone`, `usage_update_alone`, `usage_close_alone` |
| S5.244 | A delete naming an unknown id prints nothing on stdout; stderr carries `Error: Issue not found: {id}` + `Hint: Run 'br list' to see available issues.`, exit 3 | `src/error/structured.rs:606` | `error_delete_missing` |

---

## S5.245–S5.250 — Cross-cutting recap and negative space

| S5.n | clause | provenance | cases |
|---|---|---|---|
| S5.245 | Complete inventory of glyphs that can appear in in-scope plain output, with meanings: `○` U+25CB open status / non-eligible epic · `◐` U+25D0 in progress · `●` U+25CF blocked status **and** the fixed bullet inside every priority badge · `❄` U+2744 deferred or draft · `✓` U+2713 closed status, eligible epic, and the success-line prefix · `✗` U+2717 tombstone (and the batch-create failure prefix on stderr) · `📌` U+1F4CC pinned · `?` unknown/custom status · `📋` U+1F4CB ready header · `🚫` U+1F6AB blocked header · `✨` U+2728 the "nothing to do" lines of `ready` and `blocked` · `📊` U+1F4CA stats header · `⏱` U+23F1 defer · `⊘` U+2298 reopen/defer/undefer skip · `·` U+00B7 `show` field separator · `→` U+2192 update field changes, duplicate/missing dependency messages · `—` U+2014 the `ready` empty line and the close "Nothing to do" summary | `src/format/text.rs:15-32`; `ready.rs:246,294`; `blocked.rs:388,393`; `stats.rs:1223`; `defer.rs:198`; `reopen.rs:183`; `update.rs:1286`; `dep.rs:649`; `show.rs:1299` | `list_all`, `ready_plain`, `blocked_plain`, `empty_ready`, `stats_plain`, `defer_no_until`, `reopen_open`, `update_status`, `dep_add_duplicate`, `show_plain` |
| S5.246 | Plain mode never emits an ANSI escape, a box-drawing table, a panel border or a progress spinner: those belong to Rich. The only box-drawing characters any in-scope plain path can emit are the `├──`/`└──`/`│` connectors of `list --tree`, `list --pretty` and `dep tree` | `src/output/context.rs:947` (Plain is a bare `println!`); `list.rs:826-829`; `dep.rs:1760` | `list_plain`, `dep_tree` |
| S5.247 | No in-scope plain command prints a column-aligned table; the only alignment in the entire plain surface is `stats`' fixed label padding (S5.168) and the capacity block's width specifiers (S5.172) | `stats.rs:1228,1315` | `stats_plain` |
| S5.248 | `[note] …` is the exact prefix of the stderr truncation notes of `list`, `ready` and `blocked` (square brackets, lower-case `note`, one space). `search`'s equivalent uses the different prefix `note: ` and goes to **stdout** (S5.160) | `list.rs:197`, `ready.rs:262`, `blocked.rs:217`, `search.rs:362` | `ready_limit` |
| S5.249 | Numbers in plain text are always plain decimal: no thousands separators, no padding, no sign for zero. The only fractional number in the plain surface is `stats`' average lead time, printed with exactly one fractional digit (S5.170) | `count.rs:109`, `stats.rs:1256-1260` | `count_plain`, `stats_plain` |
| S5.250 | Output is state-dependent, and the scenario goldens are the contract for that: the same argv produces different bytes after a mutation (`ready` gains and loses rows, `epic status` flips its glyph and gains the eligibility line, `blocked` shrinks its header count, `stats` moves from `2.0 hours` to `23.2 days`) | `goldens/scenarios/lifecycle.scn:4`–`goldens/scenarios/lifecycle.scn:16` (the steps). `ready`: `goldens/scn_lifecycle.out:2` → `goldens/scn_lifecycle.out:35` (gains `proj-170`, loses `proj-mta`) → `goldens/scn_lifecycle.out:67`. `epic status`: `goldens/epic_status.out:1` (`○`) → `goldens/scn_lifecycle.out:61` (`✓`) with `goldens/scn_lifecycle.out:63` (`Eligible for closure`). `blocked`: `goldens/blocked_plain.out:2` (`(2)`) → `goldens/scn_lifecycle.out:41` (`(1)`). `stats`: `goldens/stats_plain.out:13` (`2.0 hours`) → `goldens/scn_lifecycle.out:96` (`23.2 days`) | `scn_lifecycle`, `scn_child_ids`, `scn_last_touched`, `scn_dup_title` |
| S5.251 | Coverage clause for the plain failure surface: in every captured non-JSON failing run, **stdout is 0 bytes** and the whole report is on stderr in the two-line `Error:` / `Hint:` shape of S5.105 (a `Hint:` line is present only when the error carries one; `error_conflict_markers` instead carries a multi-line message whose continuation lines are part of the message text). No partial plain output precedes a failure in any of them | `src/error/structured.rs:606`, `src/main.rs:1893` | `error_close_missing`, `error_comments_add_empty`, `error_comments_add_missing`, `error_conflict_markers`, `error_dep_add_cycle`, `error_dep_add_missing`, `error_dep_add_self`, `error_label_add_invalid`, `error_no_workspace_create`, `error_no_workspace_list`, `error_reopen_missing`, `error_update_ambiguous`, `error_update_bad_priority`, `error_update_missing`, `error_create_bad_priority`, `error_defer_bad_until`, `error_update_blocked_claim`, `list_sort_bad`, `list_status_bad` |
| S5.252 | Argument-parser failures are a different surface: the message is lower-case `error: …`, it is followed by a blank line, a `Usage: …` line, another blank line and `For more information, try '--help'.`, all on **stderr** with stdout empty and exit 2. Those bytes are generated by the argument-parser library and belong to S1; this part records only the stream, the empty stdout and the fact that they never mix with the `Error:`/`Hint:` shape | `src/main.rs` clap dispatch; `src/error/structured.rs:606` (not used on this path) | `usage_none`, `usage_unknown_cmd`, `usage_unknown_flag`, `usage_empty_arg`, `usage_limit_noval`, `usage_limit_bad`, `usage_unexpected_flag`, `usage_dep_alone`, `usage_label_alone`, `usage_epic_alone`, `usage_search_alone`, `usage_dep_add_one_arg` |

---

## Handover notes

Facts discovered here that belong to another section's owner:

- **S5a (JSON / the JSONL store).** Every `*_json` case, the `{"error":{…}}` pretty-printed envelope that `dep_add_custom_type` and `update_status_closed` put on **stdout** with exit 4 (a plain run would have put `Error:` on stderr instead), and the `--- .beads/issues.jsonl ---` bodies. `close --suggest-next`, `close --force`, `reopen`, `defer`, `undefer` and `delete` emit a JSON document even without `--json` when `use_json` is set internally (`close.rs:635`, `reopen.rs:143`, `defer.rs:181`); `close_blocked_force` proves it. Also: `dep add`/`dep remove`/`label`/`comments`/`count` use the *pretty* JSON writer while `create`/`q`/`ready`/`list` use the compact one.
- **S6 (order).** Row order in `list`, `ready`, `blocked`, `search`, `dep list`, `count --by-*` group order, `label list-all` order, `show`'s dependency/dependent/comment order, `epic status` order, and the `close`/`update` per-id report order (argv order, `update.rs:1417`; `delete`'s ids are sorted, `delete.rs:636`). `blocked` sorts by priority ascending then blocker count descending (`blocked.rs:208`). `list --tree` sorts sibling groups by the numeric trailing id segment (`list.rs:775-788`).
- **S7 (numerics).** The epic percentage is integer truncation of `closed * 100 / total` computed in 128-bit (`epic.rs:435-443`). The average lead time is an `f64` printed with `{:.1}`, switching unit at exactly 24.0 hours (`stats.rs:1252-1260`) — the rounding mode at a `.x5` boundary is a NUMERIC_PLAN row. Display widths for truncation use `unicode-width`, not byte or char counts (`src/format/text.rs:258`), which matters only on the excluded TTY path.
- **S8 (effects).** `create --dry-run` and `delete --dry-run` and the `delete` dependents preview write no file. `dep remove` on a missing edge still rewrites the store (`dep_remove_absent`). `show`'s deferred countdown and `list --overdue` read the wall clock at render time. `br show` may open a second transient storage handle for inherited context (`show.rs:340-352`).
- **S9 (errors).** The full `Error:`/`Hint:` catalogue, exit codes, and the clap usage texts of `usage_*`. This part fixes only the stream (stderr), the two-line shape, and the fact that stdout is left empty or partial.
- **S10 (oddities to reproduce, not fix).** (a) `Blocked by 1 open dependencies` is never singularized. (b) `br reopen` ignores `--quiet` and prints anyway; `br create --silent` overrides every mode including `--json`. (c) `show` says `Deferred until:` while `list --long` says `Deferred Until:`. (d) `dep add` uses an ASCII `->` for success and a Unicode `→` for "already exists"; `dep remove` does the same split. (e) `search`'s truncation note goes to stdout while every other truncation note goes to stderr. (f) `blocked`'s header count is the pre-truncation total while `ready`'s is the post-truncation count. (g) `delete` has two renderers whose bytes differ (S5.238). (h) `show`'s `Owner:` line invents a value from `$USER` when the record has none.
- **S3 (data model).** The plain surface reveals: status is an open set (a custom status renders with `?` and its own lower-case name), issue type is an open set (`create_custom_type` stores `spike`), priority is a small integer rendered `P{n}`, and comment bodies may carry interior newlines and tabs.

## OQ proposals

| question | clause | case to add |
|---|---|---|
| Is a long title truncated in plain mode when stdout is a pipe? (source says no; no case proves it) | S5.114 | `list_long_title` — `["@fx=longtitle","list"]` on a fixture with a 300-column title |
| At what width does `br show` wrap a free-text body when `COLUMNS` is unset? (source says 100) | S5.115 | `show_wrap_100` — `["@fx=longdesc","show","proj-aaa"]` |
| What are the exact bytes of `dep tree` at depth ≥ 1, and of the `(truncated)` / `(shown above)` prefixes? | S5.179 | `dep_tree_children` — `["@scn=child_ids"]` extended with `["dep","tree","proj-uly","--direction","up"]` |
| What does a plain `close --suggest-next` print, and is the `Unblocked` block preceded by exactly one blank line? | S5.225 | `close_suggest_next_plain` — `["@fx=basic","close","proj-mta","--suggest-next"]` |
| Does a mixed batch (one closed, one skipped) print the `✓` line on stdout and still exit non-zero? | S5.224 | `close_mixed` — `["@fx=basic","close","proj-170","proj-mta"]` |
| Does `br reopen --quiet` really print, and does `br create --silent --quiet` print the id? | S5.108 | `reopen_quiet`, `create_silent_quiet` |
| What are the bytes of a quiet mutation (stdout, stderr, and the store dump)? | S5.107 | `update_quiet` — `["@fx=basic","update","proj-mta","-p","0","--quiet"]` |
| Which stream carries the `list` truncation note and which of the two wordings applies to a plain `--limit`? | S5.124 | `list_limit_plain` — `["@fx=basic","list","--limit","2"]` |
| Does the `search` truncation note really land on stdout, and what is the hidden-closed note's exact text? | S5.159, S5.160 | `search_limit`, `search_hidden_closed` |
| What is the plain form of `defer --until` — RFC 3339 with `+00:00`, or a date? | S5.230 | `defer_until_plain` — `["@fx=basic","defer","proj-mta","--until","2027-06-01"]` |
| What are the plain forms of `undefer`, `label rename`, `update --title`, `update` no-op and `label list` on an unlabeled issue? | S5.232, S5.189, S5.216, S5.218, S5.186 | `undefer_plain`, `label_rename_plain`, `update_title_plain`, `update_noop_plain`, `label_list_empty` |
| What does `dep cycles` print when a cycle exists (stdout rows vs the stderr warning)? | S5.182 | `dep_cycles_found` — `["@fx=cycle","dep","cycles"]` on a fixture containing a cycle |
| What does `ready` print when filters exclude everything, versus when everything is blocked (three different `✨` lines)? | S5.133 | `ready_filtered_empty`, `ready_all_blocked_empty` |
| What is the countdown suffix on a plain `show` of a deferred issue under the pinned clock? | S5.148 | `show_deferred_plain` — `["@fx=basic","show","proj-7vm"]` |
| Does `blocked --limit` really print a header count larger than the row count? | S5.138 | `blocked_limit` — `["@fx=basic","blocked","--limit","1"]` |
