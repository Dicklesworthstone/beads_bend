# Discrepancies — the Bend 2 port of BEADS_RUST

<!-- Every observed or deliberate divergence from the original's observable behavior.
     Bug-compatibility is the default: a divergence exists only as an entry
     here, with a kill-switch, the affected cases and a measured impact.
     Goldens are re-captured for an accepted DISC only through the
     canonicalizing wrapper the entry names, never edited by hand. -->

Classes: `NumericWidth` (F32 for f64, budgeted) · `OrderLeak` (the
original's order is hash-random and cannot be reproduced) · `ErrorText`
(platform/library message differs) · `Platform` (path separators, locale,
line endings) · `Nondeterminism` (the original varies; canonicalized) ·
`BugFix` (an intentional fix, approved) · `Excluded` (feature not ported,
also in PLAN §3) · `Performance` (a limit the original has and the port does
not, or vice versa).

## Register

`ACCEPTED` records an approved deliberate divergence. `REVERTED` records its
reversal. `RESOLVED` records a repair that restores the original behavior;
it needs a Resolution field naming the regression artifacts, not approval
to change the contract. Keep the historical entry and its original evidence.

### DISC-001 — a pinned-instant seam, `BEADS_BEND_NOW`   [2026-09-20 | Nondeterminism | ACCEPTED]
- Spec clause: S8 (clock effect), S4 (id generation, timestamps)
- Original behavior (cite the golden): every timestamp and id derives from the wall clock; `br` has no override. `goldens/create_min.out` line 1 shows the pinned instant only because the capture preloads libfaketime: `✓ Created proj-…` with `"created_at":"2026-01-02T03:04:05Z"` in the dump.
- Port behavior: identical bytes when `BEADS_BEND_NOW=<epoch seconds>` is set; the real clock otherwise.
- Why: a port that cannot be pinned cannot be golden-tested on any mutating case (61 of 231 goldens contain a `--- .beads/issues.jsonl ---` dump: `grep -l` over `goldens/*.out`, 2026-09-20). libfaketime reaches only the C lane, so the instant enters through the shell as one environment read; the core never sees a clock.
- Kill-switch: unset `BEADS_BEND_NOW` (the default): the port reads the real clock, as the original does.
- Affected cases: none change; the variable is what makes the mutating cases comparable on every lane (`scripts/ws_inner.py` sets it from the case's `@time`).
- Impact measured: 0 of 231 goldens differ because of it; without it no mutating case is reproducible.
- Approver: Jeffrey Emanuel (repository owner), 2026-09-20, by delegation. Their words: "You decide on everything. I approve whatever you want to do." The acceptance itself was decided by the porting agent under that delegation; they can revoke it, which returns the entry to OPEN
- Amendment 2026-09-20 (same day, after OQ-004 and OQ-009): "the real clock" above cannot mean Bend's `IO.now`, which is a monotonic millisecond ticker on every engine. With the variable unset the port reads a custom effect, `Clock.wall` (`port/probes/clock/`), which delivers nanoseconds on the C lane and milliseconds on the interpreter and JS lanes. An unpinned timestamp therefore prints 9 fraction digits from the native binary and 3 from the JS engines: a separate `Platform` DISC is registered when the clock lands in the port. Counts in DISC-001…DISC-004 were measured on the 231-case corpus that existed when they were written; the corpus has 235 cases since DISC-005.

### DISC-002 — single-writer: no cross-process write locks   [2026-09-20 | Excluded | ACCEPTED]
- Spec clause: S8 (lock sidecars), PLAN §3 exclusion "cross-process write locks"
- Original behavior (cite the golden): a mutating run takes `.beads/.br-jsonl-write-<sha>.lock`, `.br-db-write-<sha>.lock` and `.write.lock` (observed 2026-09-20 in a scratch workspace) and refuses to export when the on-disk JSONL changed since load.
- Port behavior: no lock files; one invocation loads, mutates and writes back. Two concurrent port writers can lose an update.
- Why: Bend's effects have no `fcntl`/`flock` and no exclusive-create open; the lock protocol is not expressible in the shell.
- Kill-switch: none possible inside Bend; serialize writers outside the tool. Repayment: a custom lock effect (C and JS).
- Affected cases: none of the 231 (the sandbox runs one process at a time; lock sidecars are not part of the dumped state).
- Impact measured: 0 of 231 cases; the exposure is concurrent agents on one workspace, which the corpus does not exercise.
- Approver: Jeffrey Emanuel (repository owner), 2026-09-20, by delegation. Their words: "You decide on everything. I approve whatever you want to do." The acceptance itself was decided by the porting agent under that delegation; they can revoke it, which returns the entry to OPEN

### DISC-003 — write-back is not atomic   [2026-09-20 | Platform | ACCEPTED]
- Spec clause: S8 (JSONL publication), PLAN §3 exclusion "temp file + RENAME_EXCHANGE"
- Original behavior (cite the golden): stages `issues.jsonl.<pid>.tmp`, fsyncs, publishes by rename and keeps a pre-export backup under `.beads/.br_history/`; the published bytes are what `--- .beads/issues.jsonl ---` shows in every mutating golden.
- Port behavior: the same final bytes, written in place. A kill during the write can leave a truncated store, and no history backup exists.
- Why: Bend's file effects are open, read, write, close, size; there is no rename or fsync.
- Kill-switch: none inside Bend. Repayment: a custom `file_rename` effect, then the staged publication.
- Affected cases: none of the 231 (final bytes are equal; crash windows are not observable in the harness).
- Impact measured: 0 of 231 cases.
- Approver: Jeffrey Emanuel (repository owner), 2026-09-20, by delegation. Their words: "You decide on everything. I approve whatever you want to do." The acceptance itself was decided by the porting agent under that delegation; they can revoke it, which returns the entry to OPEN

### DISC-004 — sidecars other than `last-touched` are not produced   [2026-09-20 | Excluded | ACCEPTED]
- Spec clause: S8
- Original behavior (cite the golden): after a mutation `.beads/` also holds the three lock files and a `.br_history/` directory (observed 2026-09-20).
- Port behavior: writes `issues.jsonl` and `last-touched` only.
- Why: consequences of DISC-002 and DISC-003.
- Kill-switch: none.
- Affected cases: none (the harness dumps `issues.jsonl` and `last-touched`, the two files other tools read).
- Impact measured: 0 of 231 cases.
- Approver: Jeffrey Emanuel (repository owner), 2026-09-20, by delegation. Their words: "You decide on everything. I approve whatever you want to do." The acceptance itself was decided by the porting agent under that delegation; they can revoke it, which returns the entry to OPEN

### DISC-005 — candidates of an ambiguous partial id are listed in byte order   [2026-09-20 | OrderLeak | ACCEPTED]
- Spec clause: S6 (order leaks), S9 (`AMBIGUOUS_ID`, exit 3)
- Original behavior (cite the golden): the candidate list is hash-random per process. Six runs of `show m` on fixture `basic` on 2026-09-20 printed four different orders, e.g. `Error: Ambiguous ID 'm': matches ["proj-7vm", "proj-mkh", "proj-mta"]` and `… matches ["proj-mkh", "proj-mta", "proj-7vm"]`; `floor.sh --repeat 3` reported `"unstable":["show_partial_ambiguous"]`. The same list appears in the JSON envelope's `message` and in `context.matches`. The exit code (3), the hint and every other byte are stable.
- Port behavior: the candidates in ascending byte order of the id, in all three places.
- Why: a per-process random order cannot be reproduced by any deterministic program; byte order is one of the orders the original itself produces.
- Kill-switch: none is meaningful (there is no single original order to restore).
- Affected cases: `show_partial_ambiguous`, `error_show_ambiguous_json`, `error_update_ambiguous`; captured through the canonicalizer in `scripts/ws_inner.py` (`canon`: sorts only the lists of an `Ambiguous ID` message, applied identically to the original and the port; the exit code is never canonicalized).
- Impact measured: 1 of 231 cases unstable before the canonicalizer; five repeated runs byte-identical after it, in plain and JSON form; `list_json` unchanged byte for byte.
- Approver: Jeffrey Emanuel (repository owner), 2026-09-20, by delegation. Their words: "You decide on everything. I approve whatever you want to do." The acceptance itself was decided by the porting agent under that delegation; they can revoke it, which returns the entry to OPEN

### DISC-006 — the port's `version` output and binary name are its own   [2026-09-20 | Platform | ACCEPTED]
- Spec clause: S5.200–S5.202, S9.33; OQ-003
- Original behavior (cite the golden): `goldens/version_plain.out` line 1: `br version 0.6.0 (release) (v0.6.0@b1cfebe)`; `goldens/version_json.out` line 1: `{"version":"0.6.0","build":"release","commit":"b1cfebe05437463e91a353cf2bedafac27266f5b","branch":"v0.6.0","rust_version":"1.100.0-nightly","target":"x86_64-unknown-linux-gnu","features":["self_update"]}`.
- Port behavior: the port's binary is named `bn`. `bn version` prints `bn version <port version> (bend <bend version>) (port of br 0.6.0@b1cfebe)`; `bn version --json` prints one compact object with the members `version`, `build` (`bend`), `bend_version`, `port_of` (`br 0.6.0`), `oracle_commit`, `features` (an empty list). Everywhere else the port prints the original's bytes, including the literal `br` inside clap's usage texts and inside hints such as `Run: br init`.
- Why: those bytes are build metadata of a different program (a Rust toolchain version, a target triple, a git branch). Printing them would be a false statement about the binary the user is running.
- Kill-switch: none is meaningful: there is no truthful way to restore the original's bytes.
- Affected cases: `version_plain`, `version_json`. When `version` is ported (backlog item E3.5) the comparison of these two cases goes through a canonicalizer in `scripts/ws_inner.py`, applied identically to both sides and only when the case's command is `version`: plain output is reduced to its shape (`<name> version <version> …`, one line), JSON output to "one object with a string member `version`"; the exit code is never canonicalized. Until then both cases fail on every lane like every other unported command.
- Impact measured: 2 of 235 cases.
- Approver: Jeffrey Emanuel (repository owner), 2026-09-20, by delegation (the words quoted under DISC-001); decided by the porting agent under that delegation
- Amendment 2026-09-20, session 3 (DISC-006 landed): `version` is ported and the three cases pass. The port's chosen identity, fixed in `port/core/run.bend` (`port_name`, `port_version`, `port_bend`): name `bn`, version `0.1.0` (nothing is released yet), Bend `2.0.20`. `bn version` prints `bn version 0.1.0 (bend 2.0.20) (port of br 0.6.0@b1cfebe)`; `bn version --json` prints `{"version":"0.1.0","build":"bend","bend_version":"2.0.20","port_of":"br 0.6.0","oracle_commit":"b1cfebe05437463e91a353cf2bedafac27266f5b","features":[]}`; `bn --version` prints `bn 0.1.0`. The canonicalizer is `versions()` and `canon_version()` in `scripts/ws_inner.py`: for a step whose argv names `version` (or carries `--version`/`-V`), and for no other step, a one-line report is reduced to `<name> version <version> <details>`, a one-line flag answer to `<name> <version>`, and a JSON object with a string member `version` to `{"version": <string>}` — identically on both sides; anything else passes through and still fails its golden, and the exit code is never canonicalized. The three goldens were re-captured with `golden-capture.sh … --disc DISC-006`; the MANIFEST diff named exactly `usage_version_flag.out`, `version_plain.out` and `version_json.out` (and the header's `recapture: disc: DISC-006` line), no other hash moved.
- Amendment 2026-09-20 (DISC-006): the top-level `--version` / `-V` flag is the same divergence: the original prints `br 0.6.0` (`goldens/usage_version_flag.out` line 1), the port prints its own name and version. Affected cases are now `version_plain`, `version_json`, `usage_version_flag` (3 of 344). The port's parser answers `Versioned` for the flag (`port/core/cli.bend`); until backlog item E3.5 lands the three cases fail on every lane.

### DISC-007 — an explicit top-level `--no-db` is accepted   [2026-09-20 | BugFix | ACCEPTED]
- Spec clause: S1.1, S1.12, S1.91
- Original behavior (cite the golden): the port's contract is `br --no-db <argv>`. A user of the port who types `--no-db` themselves at the top level is therefore compared with `br --no-db --no-db <command>`, which the original refuses: a once-only option given twice at one level (`goldens/usage_top_json_twice.err` line 1 shows the rule for `--json`: `error: the argument '--json' cannot be used multiple times`).
- Port behavior: the contract's own `--no-db` is present for the usage line (S1.15, S1.70: `Usage: br --no-db <COMMAND>`) but is not counted as an occurrence, so `bn --no-db list` runs `list`. A second explicit `--no-db` at the top level is refused as the original refuses it.
- Why: the port exists to stand in for `br --no-db`. A script that calls `br --no-db list` must keep working when `br` is replaced by the port; refusing the very flag that defines the port's mode would make the drop-in impossible.
- Kill-switch: none. The strict reading has no user: nobody types `--no-db --no-db`.
- Affected cases: none of the 344. No case passes `--no-db` at the top level, because the harness would capture it as `br --no-db --no-db …`; `usage_no_db_explicit_sub` (`count --no-db`, accepted by the original too) covers the command level.
- Impact measured: 0 of 344 cases.
- Approver: Jeffrey Emanuel (repository owner), 2026-09-20, by delegation (the words quoted under DISC-001); decided by the porting agent under that delegation
