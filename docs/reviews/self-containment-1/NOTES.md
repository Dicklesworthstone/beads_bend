# Self-containment review 1 — prediction notes

Reviewer read only: `docs/EXISTING_BEADS_RUST_STRUCTURE.md`, `goldens/cases.tsv` (via `CASES.txt`),
`goldens/fixtures/basic.jsonl`, `scripts/ws-run.sh`, `scripts/ws_inner.py`, `CASES.txt`.
Goldens opened: no. Original run: no. `legacy/` read: no. `docs/spec-parts/`, OQ, DISC read: no.

Harness facts used for every case: inner command is `br --no-db`; fixture copied to
`/mnt/proj/.beads/issues.jsonl`; `USER=tester`, `TZ=UTC`, `NO_COLOR=1`, stdout piped, so Plain
unless `--json` (S1.6, S1.7, S5.100). None of the ten changes the store (S5.58, S8.43, S8.44), so
no `--- .beads/… ---` dump is appended in any prediction.

## 1. error_reopen_missing — `reopen proj-zzz`
- stdout empty: S5.251, S9.8 preamble ("Stdout is empty for every row").
- stderr `Error: Issue not found: proj-zzz` LF `Hint: Run 'br list' to see available issues.` LF:
  S9.9, S4.47, S4.212; two-line shape and trailing LF from S5.105 and the measured bytes in S1.9.
- exit 3: S9.9, S9.6.
- No store write, no dump: S8.43, S5.58.
- TENSION (not a guess, but the spec argues with itself): S4.313 lists `issue not found` among
  `reopen`'s verbatim SKIP reasons and says an all-skipped `reopen` exits 0 with
  `⊘ Skipped <id>: <reason>` on stdout. Read alone, that predicts
  `⊘ Skipped proj-zzz: issue not found` / exit 0. I followed S9.9 + S4.212 + S5.251, which name
  this case explicitly. The spec never says when the `issue not found` skip reason can be reached
  given that resolution is all-or-nothing before any mutation (S4.212).

## 2. error_dep_add_missing — `dep add proj-mta proj-zzz`
- Which id is reported: S4.353 (dependent resolved first, then the target; example says target
  resolution fails first, exit 3). `proj-mta` exists, so `<id>` is `proj-zzz`.
- stderr bytes / exit 3 / empty stdout: S9.9, S4.47, S5.105, S5.251.
- No write, no `last-touched`: S8.43, S5.18.
- TENSION: S2.56 gives different wording for a missing end
  (`depends_on_id: dependency target not found`, a validation failure, exit 4). S2.56's last
  sentence defers to S9 only "for the cycle and duplicate cases", so it does not itself say the
  missing-target case is pre-empted; S4.353's ordering is what settles it.

## 3. version_plain — `version`
- stdout `br version 0.6.0 (release) (v0.6.0@b1cfebe)` LF, stderr empty, exit 0: S9.33 (verbatim),
  S5.201.
- No gap. (Default fixture is `empty`; `.beads/` exists, `version` writes nothing: S5.58.)

## 4. show_json — `show proj-170 --json`
- Bare one-element array, compact, one trailing LF, stderr empty, exit 0: S5.30, S5.20, S10.36.
- Own members and their order: S5.4; which are present: the fixture line, echoed as the file
  spells it (S5.30) — `id,title,status,priority,issue_type,assignee,created_at,created_by,
  updated_at,source_repo,source_repo_path,compaction_level,original_size`.
- Appended groups and order `labels, dependencies, dependents, parent`; `comments`, `events`,
  `rollup`, `acceptance_items`, `inherited_context` omitted as empty: S5.30, S4.195 (its example
  names exactly this case), S4.196, S4.197 (no children, so no rollup).
- Five-member edge objects `id,title,status,priority,dependency_type` and list order
  (priority asc → `proj-mta` P1 before `proj-uly` P2): S5.31, S4.180.
- `"parent":"proj-uly"`: S4.196, S5.31.
- GUESSES:
  - Timestamp spelling inside `show --json`. No clause states it for this path. I wrote the `Z`
    form (`"2026-01-01T10:00:01Z"`) because S5.30 says the record is carried "exactly as the
    file spells it" and S5.12 cites `show_deferred_json`. The spec documents that other JSON
    paths print `+00:00` (S4.298 close, S4.33x defer), so the choice is not forced by a clause.
  - Whether `compaction_level`/`original_size`/`source_repo*` are echoed on the direct-read
    path: inferred from S5.30 ("no `source_repo` or `original_size` when the file had none",
    hence present when the file has them). Not stated positively.
  - S4.195 says labels are gathered "ordered ascending by byte order"; S5.30/S2.39 say file order,
    unsorted. They disagree in general; here the file order is already sorted, so no byte depends
    on it.

## 5. where_json — `where --json`
- stdout verbatim from S9.32:
  `{"path":"/mnt/proj/.beads","prefix":"proj","database_path":"/mnt/proj/.beads/beads.db","jsonl_path":"/mnt/proj/.beads/issues.jsonl"}` LF.
  Key order and omission of `redirected_from`: S5.56, S9.32. Compact + LF: S5.20. Exit 0.
- No gap.

## 6. comments_list_empty — `comments list proj-mta`
- stdout `No comments for proj-mta.` LF, exit 0, stderr empty: S5.194; LF from S5.102/S5.104.
- Minor gap: S5.194 does not say whether the `Comments for {id}:` header of S5.192 precedes the
  "No comments" line. I predicted the single line only ("prints `No comments for {id}.`").

## 7. dep_tree — `dep tree proj-uly`
- Root-only tree: S4.182 (its example is this case), S6.28 note.
- Line format `{indent}{prefix}{id}: {title} [P{n}] [{status}]`, empty prefix at depth 0: S5.179.
  → `proj-uly: Auth epic [P2] [open]` LF. Exit 0, stderr empty.
- Minor gap: S5.179 does not say whether a header line precedes the nodes (dep list has one,
  S5.176). I predicted none ("prints one line per node"). `{status}` is taken to be the raw
  status string `open`, as in S5.177's `[{status}]`; not stated for `dep tree` specifically.

## 8. search_none — `search zzzz`
- stdout `Found 0 issue(s) matching 'zzzz'` LF only, exit 0: S5.158, S4.137 (example `search zzzz`
  → none), S9.30 for the LF.
- No hidden-closed note: S4.142 (no closed record contains `zzzz`).
- No gap.

## 9. ready_limit — `ready --limit 1`
- Candidates `proj-mta, proj-5u2, proj-b75`, hybrid order, first is `proj-mta`: S4.171, S4.174.
- Header `📋 Ready work (1 issue with no blockers):` + blank line; count is post-truncation,
  singular: S5.130, S4.177, S10.44.
- Row `1. [● P1] [task] proj-mta: Set up database schema`: S5.131, S5.111, quoted in S10.58.
- No trailing blank line: S5.132.
- stderr `[note] Showing 1 of 3 ready issues. Use --limit 0 for all results.` LF: S4.177, S5.134,
  S8.34 (verbatim), S5.248. Exit 0.
- No gap.

## 10. label_list_all_json — `label list-all --json`
- Bare array of `{label,count}` ascending by label, compact + LF: S5.50, S6.21, S5.20.
- Counts from the fixture: `auth` 1 (proj-170), `backend` 2 (proj-170, proj-mta), `db` 1
  (proj-mta); agrees with the plain counts quoted in S5.187.
- Minor gap: no clause says whether labels on closed/tombstone issues are counted. Irrelevant to
  `basic` (no such record carries a label).

## Spec inconsistencies noticed in passing (not needed for these ten)
- S1.12 says a repeated `--json` is refused (exit 2, golden `usage_json_twice`); S5.25 says
  "Repeating `--json` is accepted and changes nothing" and cites the same golden.
- S5.105's "both on stderr, followed by a single `\n`" is ambiguous about whether each line or
  only the pair ends in LF; S1.9's measured bytes resolve it (each line ends in LF).
