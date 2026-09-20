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

### DISC-001 — `<short title>`   [<date> | <class> | OPEN · ACCEPTED · REVERTED · RESOLVED]
- Spec clause: S`<n.m>`
- Original behavior (cite the golden): `goldens/<case>.out` line `<n>`: `<verbatim>`
- Port behavior: `<verbatim>`
- Why: `<one paragraph; "the original is wrong" needs the approver below>`
- Kill-switch: `~` switch `<name>` / env `BEADS_RUST_<FLAG>=1` restores the original's behavior
- Affected cases: `<list>` (re-captured through wrapper `scripts/canon-<name>.sh`, MANIFEST diff `<sha>`)
- Impact measured: `<n>` of `<m>` cases; largest numeric delta `<value>` (class NumericWidth only)
- Approver: `<name>`, `<date>`
- Resolution: `<for RESOLVED only: restored behavior and regression cases / lane or proof artifacts>`
