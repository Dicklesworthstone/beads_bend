# Extractor brief (Phase 1) — shared by every spec extractor

You are a Phase 1 spec EXTRACTOR for a port of the Rust CLI `br` (beads_rust 0.6.0) to Bend 2.
Research only: you write NO code. Working directory: /data/projects/beads_bend.

## Read first, in this order
1. /home/ubuntu/.claude/skills/porting-to-bend2/references/SPEC-EXTRACTION.md — the clause discipline. Follow it exactly.
2. docs/PLAN_TO_PORT_BEADS_RUST_TO_BEND2.md §3 — scope. The port's contract is `br --no-db` (JSONL is the whole store). Excluded rows are out of your surface.
3. docs/OPEN_QUESTIONS.md — facts already settled by RUNNING the original.
4. `rg -n 'RS-' /home/ubuntu/.claude/skills/porting-to-bend2/references/LANGUAGE-GUIDES.md` — the probed Rust traps; cite a probe id where one applies.

## Sources
- The original's source PINNED at tag v0.6.0: legacy/BEADS_RUST_v0.6.0/ . Cite provenance as `src/<path>.rs:<line>` relative to it.
  NEVER read legacy/BEADS_RUST (a live tree 271 commits ahead of the pin) and never /dp/beads_rust.
- Ground truth for behavior is the captured goldens: goldens/cases.tsv (231 cases: name<TAB>JSON argv), goldens/<case>.out / .err / .exit,
  fixtures goldens/fixtures/*.jsonl, scenarios goldens/scenarios/*.scn. Leading `@fx=`, `@time=`, `@scn=` words select the fixture, the pinned
  instant (default 2026-01-02 03:04:05 UTC) and a multi-step scenario; when a run changed the store, the golden's stdout continues with
  `--- .beads/issues.jsonl ---` and `--- .beads/last-touched ---` dumps (scripts/ws-run.sh --help).
- Where the source and a golden disagree, the GOLDEN wins (the source also holds SQLite-mode paths that `--no-db` never takes). Say so in the clause.
- You may RUN the original to settle a doubt, only through the hermetic sandbox (pinned clock, fresh tmpfs workspace, touches nothing):
  `scripts/ws-run.sh --oracle br --no-db :: [@fx=<fixture>] <br args…>`

## Hard rules
- Create or modify exactly ONE file: your output file. Never edit goldens/, cases.tsv, docs/*.md or scripts/. Propose `(case to add: <name> — <argv>)` instead.
- Never delete anything. No git command that changes state. Never touch /dp/beads_rust.

## Output: docs/spec-parts/<your file>.md
- Use exactly the table shapes of docs/EXISTING_BEADS_RUST_STRUCTURE.md for your sections; clause ids ONLY in your allocated range.
- One behavior per clause. Verbatim strings in backticks, with trailing spaces and newlines stated explicitly. Every error clause states the
  stream and the exit code. Every clause carries provenance and names at least one EXISTING case, or says `(case to add: …)`.
- Algorithms are described behaviorally with `| input | output |` example rows taken from goldens, plus the exact arithmetic where it affects bytes.
- No code-shaped text (no `def `, `for `, `if …:`). Never the words "probably", "should", "TODO". Mark inference `[inference]`.
- End with `## Handover notes` (facts owned by other sections: order → S6, numerics → S7, effects → S8, oddities → S10, data model → S3)
  and `## OQ proposals` (`| question | clause | case to add |`).
- Coverage duty: every case in cases.tsv whose behavior falls in your surface is cited by at least one of your clauses.
- DO NOT OVERSIMPLIFY. DO NOT LOSE ANY FEATURES OR FUNCTIONALITY within scope.

## Final reply (under 200 words; do NOT paste clauses)
File written, clause count, number of distinct cases cited, OQ proposals count, and anything you could not determine.
