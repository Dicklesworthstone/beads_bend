# Backlog (the granular to-do list) — the Bend 2 port of BEADS_RUST

The working list. `docs/PORT_STATE.md` is the resume document (gate lines, next
action); this file is the granular backlog behind it. An item is checked only
when its evidence exists (a gate line, a golden passing on a lane, a commit).
Items found during the work are appended under the phase they belong to.

Legend: `[x]` done with evidence · `[ ]` open · `[~]` partly done (what is
left is stated) · `(OQ-n)` / `(DISC-n)` cross-reference the registers.

## A. Owner decisions (delegated 2026-09-20: "You decide on everything. I approve whatever you want to do.")

- [x] A1. Git remote: create a public GitHub repository under the owner's account, with a description and topics; push `main`
  - [x] A1.1 scan tracked files for IPs, key paths, tokens, email addresses (clean, 864 files)
  - [x] A1.2 add a LICENSE (the owner's beads_rust license text, the project this one ports)
  - [x] A1.3 `gh repo create` public, description, topics, homepage-free
  - [x] A1.4 push `main`; `git status` shows up to date with origin (https://github.com/Dicklesworthstone/beads_bend)
  - [x] A1.5 README: repository URL, clone line, license section; AGENTS.md and PORT_STATE: the remote exists
- [x] A2. DISC-001…DISC-005: record ACCEPTED with the approver and the authorizing words
- [x] A3. UBS `python.taint.command` on `scripts/ws_inner.py`: one inline `# ubs:ignore[python.taint.command]` with the reason on the one line; `ubs scripts/ws_inner.py` exits 0
- [x] A4. The port's `version` contract and binary name (`bn`): DISC-006 ACCEPTED, OQ-003 resolved; the canonicalizer itself lands with E3.5

## B. Phase 0 — truth pack (done; maintenance items)

- [x] B1. 235 goldens, floor STABLE, MANIFEST pinned (344 since the three parser batches of B12)
- [ ] B2. ws-run: a mode that dumps EVERY file under `.beads/` (needed by OQ-005 `init`, OQ-008 sidecars)
- [ ] B3. ws-run: a directive to run from a SUBDIRECTORY of the workspace (upward walk, OQ-103)
- [ ] B4. ws-run: a directive to set ONE environment variable (`BEADS_DIR`, `BR_OUTPUT_FORMAT`, `BD_ACTOR`; S1/S8 cases)
- [ ] B5. ws-run: fixture selector for `.beads/` WITHOUT `issues.jsonl`, and binary fixtures (non-UTF-8, OQ-101)
- [ ] B6. ws-run: stage extra input files in the workspace (`--description-file`, `create -f`, `comments add -f`, `delete --from-file`)
- [ ] B7. Large fixtures through the oracle: `n163`, `n164` (id-length edge, OQ-006), a 5k-record store (JS-lane depth, performance)
- [ ] B8. Fixture `leadtime` (non-integer average lead time, OQ-078)
- [ ] B9. Fixture with a real dependency cycle; diamonds; external blockers; templates; custom statuses (S4b OQs)
- [ ] B10. Capture the extractors' ~215 `(case to add …)` proposals in batches with `golden-capture.sh --repin`, re-floor
- [ ] B11. Full four-lane run at HEAD when the machine has memory (last one was stopped by the harness)
- [x] B12. The parser's surface as cases, three batches under `--repin`: 43 (every command's usage line, the argument syntax forms), 41 (refusal shapes, value checks, exclusions, aliases, hyphen values), 25 (the questions the first two raised: OQ-104…OQ-113). 344 cases
  - [x] B12.1 floor over 278: STABLE
  - [x] B12.2 floor over 344: STABLE
- [x] B13. `scripts/quick-lanes.sh`: c-1t and js over the whole corpus, the inner loop (the four-lane gate stays `scripts/lanes.sh`)

## C. Phase 1 — spec (first pass done)

- [x] C1. 874 clauses merged; spec-lint 0 findings; blind review 10/10
- [ ] C2. Reconcile the six contradictions the blind review found (OQ-093…OQ-098): amend the wrong clause to the golden
- [ ] C3. Reconcile S4.52 vs S8.31 (how often the clock is read, OQ-100)
- [ ] C4. S10.49 looks misattributed (`where` omits `prefix:` when the prefix is undetectable): verify and amend
- [ ] C5. Second extraction pass (same prompt, same files) per section; third, case-keyed expansion pass
- [ ] C6. Second blind self-containment review on ten NEW cases, including mutating ones, after C2
- [ ] C7. Resolve or exclude every OPEN row of `docs/OPEN_QUESTIONS.md` (95 open)

## D. Phase 2 — architecture (done; amendments)

- [x] D1. PROPOSED_ARCHITECTURE, NUMERIC_PLAN, parity skeleton; arch-lint PASS
- [ ] D2. Amend the architecture: `Sys.remove`, `Sys.rename` effects are planned, not written; `Clock.wall` lives in a probe only
- [ ] D3. NUMERIC_PLAN S7.20: decide the multi-limb binary64 routine vs a DISC after OQ-078's golden exists

## E. Phase 3 — reference port

### E1. Foundations (done)
- [x] bytes (UTF-8 encode/decode) · sha256 · id (seed, hash36, length table) · time (RFC 3339) · json (lexer, members) · failure (renderings, escaping) · model (record, store line) · decode (line → record) · store (load, refusals) · run (dispatcher) · scaffold · shell with `Sys.exit`, `Sys.cwd`
- [x] 29 closed laws proved; 7 of 235 cases pass on c-1t

### E2. Command line (S1.1–S1.30, S1.68–S1.92) — `port/core/surface.bend` (tables), `port/core/cli.bend` (algorithm), `port/core/help.bend` (generated texts)
- [x] E2.1 read S1 in full; list the grammar: global flags, per-command flags, value syntax, aliases, conflicts → `core/surface.bend`, 36 levels
- [x] E2.2 the token layer: `--flag`, `--flag=value`, `-f`, `-fvalue`, combined shorts, `--`, negative numbers, `-` alone
- [x] E2.3 clap's refusals, verbatim, exit 2: unknown subcommand and option (with the similarity tips, Jaro in exact fractions), the `--` advice, missing value, invalid value (unsigned, ranged, enumerated with the similar-value tip), repeated option, unexpected value, exclusions in argv order, missing positionals, the order rule of S1.84
- [x] E2.4 the bare `dep` / `label` / `epic` help blocks on stderr, exit 2; a group with options only (S1.83)
- [x] E2.5 the result type: `Cli.Parsed` with `Command{path, opts, words}` (NOT one constructor per command form: PROPOSED_ARCHITECTURE §2 amended)
- [x] E2.6 route `Run.outcome` through it: usage refusals come BEFORE any workspace or store access
- [x] E2.7 goldens on c-1t and js: every `usage_*` case that the parser alone decides passes; the rest wait for their command (E5, E6) or for `version` (E3.5)
- [x] E2.8 help texts: top (`--help`, `help`), `list --help`, `list -h`, `help list`, the three groups; the spec appendix `docs/spec-parts/HELP_TEXTS.md` (clause S1.89) is their single source, `scripts/gen-help-bend.py` builds the module
- [x] E2.9 eight closed laws (`cli_*`): refusal texts, similarity, exclusions, accepted command lines, help forms
- [x] E2.10 DISC-007: an explicit top-level `--no-db` is accepted
- [ ] E2.11 the help text of the other 30 levels, long and short (about 60 cases and 150 KB of text): decide in PLAN §3 whether they stay excluded
- [ ] E2.12 open parser questions: OQ-106 (threshold in floating point), OQ-107 (equal similarity), OQ-111 (`--assignee` bare against empty)
- [ ] E2.13 environment reads the parser's callers need (`BR_OUTPUT_FORMAT`, `NO_COLOR`, `USER`, `BD_ACTOR`…): a `Sys.env` custom effect, probed on three engines

### E3. Workspace (S2.1–S2.23) — `core/discover.bend`
- [ ] E3.1 upward walk for `.beads/` then `_beads/`; `BEADS_DIR`; `redirect` (fuel 10); probes in the shell, decision in the core
- [ ] E3.2 the prefix: `config.yaml` `issue_prefix`, directory-name rules, fallback `br`
- [ ] E3.3 `metadata.json`, `BEADS_JSONL`, user-level config layers under `$HOME`
- [ ] E3.4 `where` (plain, JSON): goldens `where_plain`, `where_json`
- [ ] E3.5 `version` per DISC-006 (`bn version …`), plus the shape canonicalizer for `version_plain` / `version_json` in `scripts/ws_inner.py`, re-captured with `--disc DISC-006`

### E4. Store completeness — `core/store.bend`
- [ ] E4.1 load repairs S2.31–S2.36: status/type/dep-type folding and aliases; label sort+dedup; duplicate edges; duplicate comments; `-wisp-` ⇒ ephemeral; `closed_at` repairs; `external_ref` trim; `updated_at` ≥ `created_at`
- [ ] E4.2 duplicate-id refusal (S2.40); tombstone protection (S2.42)
- [ ] E4.3 validation S2.43–S2.56 with verbatim messages (exit 4)
- [ ] E4.4 `Store.text`: records by id bytes, `\n` each; S5.9 `""` rule; S5.14 dependency defaults (`import`, `{}`, `""`); S5.16 exclusions
- [ ] E4.5 laws: `labels_normalize_idempotent`, `store_text_fixpoint_basic`, a closed law for `edge_precision_rewrite`'s lines
- [ ] E4.6 UTF-8 strictness (overlong, surrogates, > U+10FFFF) after OQ-101

### E5. Queries — `core/query.bend`, `core/blocked.bend`, `core/graph.bend`
- [ ] E5.1 visibility, filters, `--limit/--offset`, `total/has_more`; the comparators of S6.6–S6.17 as `le` defs
- [ ] E5.2 `list` plain / `--long` / JSON (`IssueWithCounts`); `search`; `count` (+ every `--by-*`); `stats`
- [ ] E5.3 the BLOCKED relation (three ordered steps), `ready` (three sort policies), `blocked`
- [ ] E5.4 `show` (raw-record path, S2.39), `dep list` (two orders), `dep tree`, `dep cycles`, `epic status`, `label list`, `label list-all`, `comments list`
- [ ] E5.5 laws: `counts_sum_to_total`; order laws for the comparators

### E6. Mutations — `core/mutate.bend`
- [ ] E6.1 `create`, `q` (full id ladder against the store; child ids; `--deps`, `--parent`; `--dry-run`, `--silent`, `--ephemeral`)
- [ ] E6.2 `update` (every flag, `--claim`, last-touched fallback), `close` (+`--suggest-next`, blocked refusal, partial batches exit 3), `reopen`, `defer`/`undefer` (date forms S4.56–S4.62)
- [ ] E6.3 `delete` (tombstone, dependents, `--force`, `--cascade`, `--dry-run`, removes `last-touched`)
- [ ] E6.4 `dep add/remove` (cycle refusal exit 5, no-op duplicates), `label add/remove/rename`, `comments add` (id = store-wide max + 1), `epic close-eligible`
- [ ] E6.5 the shell's writes: `Sys.rename` temp-file publication, `Sys.remove`, `last-touched` ordering after the flush
- [ ] E6.6 `Clock.wall` in the shell + `BEADS_BEND_NOW` pin (DISC-001); the `Platform` DISC for JS-lane millisecond precision

### E7. Rendering — `core/render.bend`
- [ ] E7.1 plain text per command (S5.100–S5.252): glyphs, padding, pluralization, wrapping at 100 columns
- [ ] E7.2 JSON per command (S5.20–S5.58): key orders, `+00:00` in `close`/`defer` payloads, `--fields` ignored under `--json`
- [ ] E7.3 quiet mode; warnings on stderr; the complete S9 error table as `Failure.*` constructors

### E8. Phase 3 exit
- [ ] E8.1 lanes PASS on interpreter, c-1t, c-8t, js (gpu MISSING with reason)
- [ ] E8.2 every def tagged; `law-coverage.sh` OK; `port-lint.py` no errors
- [ ] E8.3 stack safety on the JS lane for a 5k-record store (B7)

## F. Phases 4–6

- [ ] F1. Parity gate: board FULL/DEBT; ≥ 10 find-fix rounds with rotating lenses, 2 consecutive clean, non-author rounds; `law-mutation.sh` STRONG for every def a property law names
- [ ] F2. Performance: hotspot → card → fast twin → law → keep-audit → cv-gated capture → ledger; incumbent = `br --no-db` in the sandbox at thread parity
- [ ] F3. Certify: `docs/PORT_REPORT.md`, evidence bundle, SHIP / HOLD / BLOCK

## G. Toolchain and upstream

- [ ] G1. File upstream (bendlang/bend): the foreign-reliance verdict cost (reproducer `port/probe_shell_time.bend`); the `../` import + `( .. : U32)` misresolution; GUIDE.md still saying bare operators default to `Nat`
- [ ] G2. `scripts/version-drift.sh` between 2.0.16 and 2.0.20 now that the port has gates
- [ ] G3. CI: `assets/github-workflows/port-gates.yml` filled for this port (compiler + oracle placeholders), once a runner with bubblewrap and the pins exists
