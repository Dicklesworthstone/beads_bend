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

### DISC-001 — a pinned-instant seam, `BEADS_BEND_NOW`   [2026-09-20 | Nondeterminism | OPEN]
- Spec clause: S8 (clock effect), S4 (id generation, timestamps)
- Original behavior (cite the golden): every timestamp and id derives from the wall clock; `br` has no override. `goldens/create_min.out` line 1 shows the pinned instant only because the capture preloads libfaketime: `✓ Created proj-…` with `"created_at":"2026-01-02T03:04:05Z"` in the dump.
- Port behavior: identical bytes when `BEADS_BEND_NOW=<epoch seconds>` is set; the real clock otherwise.
- Why: a port that cannot be pinned cannot be golden-tested on any mutating case (61 of 231 goldens contain a `--- .beads/issues.jsonl ---` dump: `grep -l` over `goldens/*.out`, 2026-09-20). libfaketime reaches only the C lane, so the instant enters through the shell as one environment read; the core never sees a clock.
- Kill-switch: unset `BEADS_BEND_NOW` (the default): the port reads the real clock, as the original does.
- Affected cases: none change; the variable is what makes the mutating cases comparable on every lane (`scripts/ws_inner.py` sets it from the case's `@time`).
- Impact measured: 0 of 231 goldens differ because of it; without it no mutating case is reproducible.
- Approver: pending (repository owner)

### DISC-002 — single-writer: no cross-process write locks   [2026-09-20 | Excluded | OPEN]
- Spec clause: S8 (lock sidecars), PLAN §3 exclusion "cross-process write locks"
- Original behavior (cite the golden): a mutating run takes `.beads/.br-jsonl-write-<sha>.lock`, `.br-db-write-<sha>.lock` and `.write.lock` (observed 2026-09-20 in a scratch workspace) and refuses to export when the on-disk JSONL changed since load.
- Port behavior: no lock files; one invocation loads, mutates and writes back. Two concurrent port writers can lose an update.
- Why: Bend's effects have no `fcntl`/`flock` and no exclusive-create open; the lock protocol is not expressible in the shell.
- Kill-switch: none possible inside Bend; serialize writers outside the tool. Repayment: a custom lock effect (C and JS).
- Affected cases: none of the 231 (the sandbox runs one process at a time; lock sidecars are not part of the dumped state).
- Impact measured: 0 of 231 cases; the exposure is concurrent agents on one workspace, which the corpus does not exercise.
- Approver: pending (repository owner)

### DISC-003 — write-back is not atomic   [2026-09-20 | Platform | OPEN]
- Spec clause: S8 (JSONL publication), PLAN §3 exclusion "temp file + RENAME_EXCHANGE"
- Original behavior (cite the golden): stages `issues.jsonl.<pid>.tmp`, fsyncs, publishes by rename and keeps a pre-export backup under `.beads/.br_history/`; the published bytes are what `--- .beads/issues.jsonl ---` shows in every mutating golden.
- Port behavior: the same final bytes, written in place. A kill during the write can leave a truncated store, and no history backup exists.
- Why: Bend's file effects are open, read, write, close, size; there is no rename or fsync.
- Kill-switch: none inside Bend. Repayment: a custom `file_rename` effect, then the staged publication.
- Affected cases: none of the 231 (final bytes are equal; crash windows are not observable in the harness).
- Impact measured: 0 of 231 cases.
- Approver: pending (repository owner)

### DISC-004 — sidecars other than `last-touched` are not produced   [2026-09-20 | Excluded | OPEN]
- Spec clause: S8
- Original behavior (cite the golden): after a mutation `.beads/` also holds the three lock files and a `.br_history/` directory (observed 2026-09-20).
- Port behavior: writes `issues.jsonl` and `last-touched` only.
- Why: consequences of DISC-002 and DISC-003.
- Kill-switch: none.
- Affected cases: none (the harness dumps `issues.jsonl` and `last-touched`, the two files other tools read).
- Impact measured: 0 of 231 cases.
- Approver: pending (repository owner)

### DISC-005 — candidates of an ambiguous partial id are listed in byte order   [2026-09-20 | OrderLeak | OPEN]
- Spec clause: S6 (order leaks), S9 (`AMBIGUOUS_ID`, exit 3)
- Original behavior (cite the golden): the candidate list is hash-random per process. Six runs of `show m` on fixture `basic` on 2026-09-20 printed four different orders, e.g. `Error: Ambiguous ID 'm': matches ["proj-7vm", "proj-mkh", "proj-mta"]` and `… matches ["proj-mkh", "proj-mta", "proj-7vm"]`; `floor.sh --repeat 3` reported `"unstable":["show_partial_ambiguous"]`. The same list appears in the JSON envelope's `message` and in `context.matches`. The exit code (3), the hint and every other byte are stable.
- Port behavior: the candidates in ascending byte order of the id, in all three places.
- Why: a per-process random order cannot be reproduced by any deterministic program; byte order is one of the orders the original itself produces.
- Kill-switch: none is meaningful (there is no single original order to restore).
- Affected cases: `show_partial_ambiguous`, `error_show_ambiguous_json`, `error_update_ambiguous`; captured through the canonicalizer in `scripts/ws_inner.py` (`canon`: sorts only the lists of an `Ambiguous ID` message, applied identically to the original and the port; the exit code is never canonicalized).
- Impact measured: 1 of 231 cases unstable before the canonicalizer; five repeated runs byte-identical after it, in plain and JSON form; `list_json` unchanged byte for byte.
- Approver: pending (repository owner)
