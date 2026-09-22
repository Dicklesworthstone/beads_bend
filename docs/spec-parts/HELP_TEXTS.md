# Appendix to S1.89 — the help texts the port carries, verbatim

Part of THE SPEC (`docs/EXISTING_BEADS_RUST_STRUCTURE.md`, clause S1.89), kept in its own file because the
texts are the original's words and are long: `scripts/merge-spec-parts.py` does not copy them into the merged
spec, and the wording gate (`scripts/claims-lint.sh docs/*.md …`) does not read this directory. Measured
2026-09-20 from the goldens named beside each block.

## The texts

The help texts the port carries, exactly as measured. Each block is the whole output, ends with one
line feed, and is ASCII except where shown. `scripts/gen-help-bend.py` builds `port/core/help.bend`
from these blocks, so this file is the single source of those bytes.

`br --no-db --help`, and byte for byte the same for `br --no-db help` (`usage_help_subcommand`); golden `usage_help_flag_top`, stdout:

<!-- help-text: top -->
```text
Agent-first issue tracker (SQLite + JSONL)

Usage: br [OPTIONS] <COMMAND>

Commands:
  agents        Manage AGENTS.md workflow instructions
  audit         Record and label agent interactions (append-only JSONL)
  blocked       List blocked issues
  capabilities  Describe br's machine-readable contracts and safety guarantees
  capacity      Workflow capacity management: audited issue-specific exemptions (GitHub #384)
  changelog     Generate changelog from closed issues
  close         Close an issue
  comments      Manage comments
  completions   Generate shell completions
  config        Configuration management
  coordination  Diagnose swarm coordination state without mutating claims
  count         Count issues with optional grouping
  create        Create a new issue
  defer         Defer issues (schedule for later)
  delete        Delete an issue (creates tombstone)
  dep           Manage dependencies
  doctor        Run diagnostics and optionally repair issues
  epic          Epic management commands
  gate          Workflow gate engine: record and inspect gate results (issue #312)
  graph         Visualize the dependents graph: what an issue unblocks
  history       Manage local history backups
  info          Show diagnostic metadata about the workspace
  init          Initialize a beads workspace
  label         Manage labels
  lint          Check issues for missing template sections
  list          List issues
  orphans       List orphan issues (referenced in commits but open)
  q             Quick capture (create issue, print ID only)
  query         Manage saved queries
  ready         List ready issues (open, unblocked, not deferred)
  reopen        Reopen an issue
  robot-docs    Print concise in-tool docs for automation agents
  scheduler     Rank ready work for agent swarms with explainable evidence
  schema        Emit JSON Schemas and per-command output envelope shapes (for agent/tooling integration)
  search        Search issues (matches title, description, id, and comment text)
  show          Show issue details
  stale         List stale issues
  stats         Show project statistics
  status        Alias for stats
  sync          Sync database with JSONL file (export or import)
  undefer       Undefer issues (make ready again)
  update        Update an issue
  vcs-status    Explicitly inspect Git visibility for the configured JSONL export
  upgrade       Upgrade br to the latest version
  version       Show version information
  where         Show the active .beads directory
  help          Print this message or the help of the given subcommand(s)

Options:
      --db <DB>                      Database path (auto-discover .beads/*.db if not set; env: BEADS_DB)
      --actor <ACTOR>                Actor name for audit trail
      --json                         Output as JSON
      --no-daemon                    Force direct mode (no daemon) - effectively no-op in br v1
      --no-auto-flush                Skip auto JSONL export
      --no-auto-import               Skip auto import check
      --allow-stale                  Allow stale DB (bypass freshness check warning)
      --lock-timeout <LOCK_TIMEOUT>  `SQLite` busy/write-lock timeout in ms
      --no-db                        JSONL-only mode (no DB connection)
  -v, --verbose...                   Increase logging verbosity (-v, -vv)
  -q, --quiet                        Quiet mode (no output except errors)
      --no-color                     Disable colored output
  -h, --help                         Print help
  -V, --version                      Print version
```

`br --no-db list --help` (the long form); golden `usage_help_list`, stdout:

<!-- help-text: list -->
```text
List issues

Usage: br list [OPTIONS]

Options:
  -s, --status <STATUS>
          Filter by status (can be repeated; 'all' matches every status)

  -t, --type <TYPE>
          Filter by issue type (can be repeated)

      --assignee <ASSIGNEE>
          Filter by assignee

      --unassigned
          Filter for unassigned issues only

      --id <ID>
          Filter by specific IDs (can be repeated)

  -l, --label <LABEL>
          Filter by label (AND logic, can be repeated)

      --label-any <LABEL_ANY>
          Filter by label (OR logic, can be repeated)

  -p, --priority <PRIORITY>
          Filter by priority: 0-4 or P0-P4, ranges like 0-1, comma lists; repeatable

      --priority-min <PRIORITY_MIN>
          Filter by minimum priority (0=critical, 4=backlog)

      --priority-max <PRIORITY_MAX>
          Filter by maximum priority

      --title-contains <TITLE_CONTAINS>
          Title contains substring

      --desc-contains <DESC_CONTAINS>
          Description contains substring

      --notes-contains <NOTES_CONTAINS>
          Notes contains substring

  -a, --all
          Include closed issues (default excludes closed)

      --limit <LIMIT>
          Maximum number of results (0 = unlimited; default: unlimited — the full work surface)

      --offset <OFFSET>
          Number of results to skip (for pagination, default: 0)

      --sort <SORT>
          Sort field (`priority`, `created_at`, `updated_at`, `title`)

  -r, --reverse
          Reverse sort order

      --deferred
          Include deferred issues

      --overdue
          Filter for overdue issues

      --long
          Use long output format

      --pretty
          Use tree/pretty output format

      --tree
          Group children under their parents with tree connectors (text output). Hierarchy follows dotted child IDs (`bd-abc.2` under `bd-abc`); a child whose parent is filtered out of the result set is shown at the top level (GitHub #475)

      --wrap
          Wrap long lines instead of truncating in text output

      --format <FORMAT>
          Output format (text, json, csv, toon). Env: BR_OUTPUT_FORMAT, TOON_DEFAULT_FORMAT

          Possible values:
          - text: Human-readable text (default)
          - json: JSON output
          - csv:  CSV output with configurable fields
          - toon: TOON format (token-optimized object notation)

      --stats
          Show token savings stats when using TOON output

      --fields <FIELDS>
          CSV fields to include (comma-separated)
          
          Available: id, title, description, status, priority, `issue_type`, assignee, owner, `created_at`, `updated_at`, `closed_at`, `due_at`, `defer_until`, notes, `external_ref`
          
          Default: id, title, status, priority, `issue_type`, assignee, `created_at`, `updated_at`

      --db <DB>
          Database path (auto-discover .beads/*.db if not set; env: BEADS_DB)

      --actor <ACTOR>
          Actor name for audit trail

      --json
          Output as JSON

      --no-daemon
          Force direct mode (no daemon) - effectively no-op in br v1

      --no-auto-flush
          Skip auto JSONL export

      --no-auto-import
          Skip auto import check

      --allow-stale
          Allow stale DB (bypass freshness check warning)

      --lock-timeout <LOCK_TIMEOUT>
          `SQLite` busy/write-lock timeout in ms

      --no-db
          JSONL-only mode (no DB connection)

  -v, --verbose...
          Increase logging verbosity (-v, -vv)

  -q, --quiet
          Quiet mode (no output except errors)

      --no-color
          Disable colored output

  -h, --help
          Print help (see a summary with '-h')
```

`br --no-db list -h` (the short form); golden `usage_help_short_list`, stdout:

<!-- help-text: list-short -->
```text
List issues

Usage: br list [OPTIONS]

Options:
  -s, --status <STATUS>
          Filter by status (can be repeated; 'all' matches every status)
  -t, --type <TYPE>
          Filter by issue type (can be repeated)
      --assignee <ASSIGNEE>
          Filter by assignee
      --unassigned
          Filter for unassigned issues only
      --id <ID>
          Filter by specific IDs (can be repeated)
  -l, --label <LABEL>
          Filter by label (AND logic, can be repeated)
      --label-any <LABEL_ANY>
          Filter by label (OR logic, can be repeated)
  -p, --priority <PRIORITY>
          Filter by priority: 0-4 or P0-P4, ranges like 0-1, comma lists; repeatable
      --priority-min <PRIORITY_MIN>
          Filter by minimum priority (0=critical, 4=backlog)
      --priority-max <PRIORITY_MAX>
          Filter by maximum priority
      --title-contains <TITLE_CONTAINS>
          Title contains substring
      --desc-contains <DESC_CONTAINS>
          Description contains substring
      --notes-contains <NOTES_CONTAINS>
          Notes contains substring
  -a, --all
          Include closed issues (default excludes closed)
      --limit <LIMIT>
          Maximum number of results (0 = unlimited; default: unlimited — the full work surface)
      --offset <OFFSET>
          Number of results to skip (for pagination, default: 0)
      --sort <SORT>
          Sort field (`priority`, `created_at`, `updated_at`, `title`)
  -r, --reverse
          Reverse sort order
      --deferred
          Include deferred issues
      --overdue
          Filter for overdue issues
      --long
          Use long output format
      --pretty
          Use tree/pretty output format
      --tree
          Group children under their parents with tree connectors (text output). Hierarchy follows dotted child IDs (`bd-abc.2` under `bd-abc`); a child whose parent is filtered out of the result set is shown at the top level (GitHub #475)
      --wrap
          Wrap long lines instead of truncating in text output
      --format <FORMAT>
          Output format (text, json, csv, toon). Env: BR_OUTPUT_FORMAT, TOON_DEFAULT_FORMAT [possible values: text, json, csv, toon]
      --stats
          Show token savings stats when using TOON output
      --fields <FIELDS>
          CSV fields to include (comma-separated)
      --db <DB>
          Database path (auto-discover .beads/*.db if not set; env: BEADS_DB)
      --actor <ACTOR>
          Actor name for audit trail
      --json
          Output as JSON
      --no-daemon
          Force direct mode (no daemon) - effectively no-op in br v1
      --no-auto-flush
          Skip auto JSONL export
      --no-auto-import
          Skip auto import check
      --allow-stale
          Allow stale DB (bypass freshness check warning)
      --lock-timeout <LOCK_TIMEOUT>
          `SQLite` busy/write-lock timeout in ms
      --no-db
          JSONL-only mode (no DB connection)
  -v, --verbose...
          Increase logging verbosity (-v, -vv)
  -q, --quiet
          Quiet mode (no output except errors)
      --no-color
          Disable colored output
  -h, --help
          Print help (see more with '--help')
```

`br --no-db dep` (S1.25); golden `usage_dep_alone`, stderr:

<!-- help-text: dep -->
```text
Manage dependencies

Usage: br dep [OPTIONS] <COMMAND>

Commands:
  add     Add a dependency: <issue> depends on <depends-on>
  import  Bulk import dependency edges from JSONL
  remove  Remove a dependency [alias: rm]
  list    List dependencies of an issue
  tree    Show dependency tree rooted at issue
  cycles  Detect and report dependency cycles
  help    Print this message or the help of the given subcommand(s)

Options:
      --db <DB>                      Database path (auto-discover .beads/*.db if not set; env: BEADS_DB)
      --actor <ACTOR>                Actor name for audit trail
      --json                         Output as JSON
      --no-daemon                    Force direct mode (no daemon) - effectively no-op in br v1
      --no-auto-flush                Skip auto JSONL export
      --no-auto-import               Skip auto import check
      --allow-stale                  Allow stale DB (bypass freshness check warning)
      --lock-timeout <LOCK_TIMEOUT>  `SQLite` busy/write-lock timeout in ms
      --no-db                        JSONL-only mode (no DB connection)
  -v, --verbose...                   Increase logging verbosity (-v, -vv)
  -q, --quiet                        Quiet mode (no output except errors)
      --no-color                     Disable colored output
  -h, --help                         Print help
```

`br --no-db label` (S1.26); golden `usage_label_alone`, stderr:

<!-- help-text: label -->
```text
Manage labels

Usage: br label [OPTIONS] <COMMAND>

Commands:
  add       Add label(s) to issue(s)
  remove    Remove label(s) from issue(s)
  list      List labels for an issue or all unique labels
  list-all  List all unique labels with counts
  rename    Rename a label across all issues
  help      Print this message or the help of the given subcommand(s)

Options:
      --db <DB>                      Database path (auto-discover .beads/*.db if not set; env: BEADS_DB)
      --actor <ACTOR>                Actor name for audit trail
      --json                         Output as JSON
      --no-daemon                    Force direct mode (no daemon) - effectively no-op in br v1
      --no-auto-flush                Skip auto JSONL export
      --no-auto-import               Skip auto import check
      --allow-stale                  Allow stale DB (bypass freshness check warning)
      --lock-timeout <LOCK_TIMEOUT>  `SQLite` busy/write-lock timeout in ms
      --no-db                        JSONL-only mode (no DB connection)
  -v, --verbose...                   Increase logging verbosity (-v, -vv)
  -q, --quiet                        Quiet mode (no output except errors)
      --no-color                     Disable colored output
  -h, --help                         Print help
```

`br --no-db epic` (S1.27); golden `usage_epic_alone`, stderr:

<!-- help-text: epic -->
```text
Epic management commands

Usage: br epic [OPTIONS] <COMMAND>

Commands:
  status          Show status of all epics (progress, eligibility)
  close-eligible  Close epics that are eligible (all children closed)
  help            Print this message or the help of the given subcommand(s)

Options:
      --db <DB>                      Database path (auto-discover .beads/*.db if not set; env: BEADS_DB)
      --actor <ACTOR>                Actor name for audit trail
      --json                         Output as JSON
      --no-daemon                    Force direct mode (no daemon) - effectively no-op in br v1
      --no-auto-flush                Skip auto JSONL export
      --no-auto-import               Skip auto import check
      --allow-stale                  Allow stale DB (bypass freshness check warning)
      --lock-timeout <LOCK_TIMEOUT>  `SQLite` busy/write-lock timeout in ms
      --no-db                        JSONL-only mode (no DB connection)
  -v, --verbose...                   Increase logging verbosity (-v, -vv)
  -q, --quiet                        Quiet mode (no output except errors)
      --no-color                     Disable colored output
  -h, --help                         Print help
```

## The texts of every other level (measured 2026-09-22)

Captured from the pinned original through the sandbox; each block names its golden. The key is the level's words
joined by `.`; `-short` marks the `-h` form, which clap prints without the long descriptions.

### `br create --help` — `goldens/usage_help_create.out`

<!-- help-text: create -->
```text
Create a new issue

Usage: br create [OPTIONS] [TITLE]

Arguments:
  [TITLE]
          Issue title

Options:
      --title <TITLE_FLAG>
          Issue title (alternative to positional argument)

  -t, --type <TYPE>
          Issue type (task, bug, feature, etc.)

      --slug <SLUG>
          Human-readable slug embedded in the generated ID. Example: `--slug survey-my-thing` produces an ID of the form `br-survey-my-thing-<hash>`, keeping the configured prefix and the uniquifying hash suffix. The slug is normalized to lowercase ASCII alphanumeric + single hyphens (runs of other characters collapse to one hyphen, leading/trailing hyphens are stripped, length is capped at 48 characters after normalization)

  -p, --priority <PRIORITY>
          Priority (0-4 or P0-P4)

  -d, --description <DESCRIPTION>
          Description
          
          [alias: --body]

      --description-file <PATH>
          Read the issue description verbatim from a file (or `-` for stdin).
          
          The entire file content is used as the description, unchanged from disk — unlike the bulk `-f/--file` markdown import, which only captures the first paragraph after each `## Title` heading. Use this for multi-paragraph / markdown descriptions (lists, fenced code) that are fragile to pass through shell quoting on `-d/--description`. Mutually exclusive with `-d/--description`.

  -a, --assignee <ASSIGNEE>
          Assign to person

      --owner <OWNER>
          Set owner email

  -l, --labels <LABELS>
          Labels (comma-separated)

      --parent <PARENT>
          Parent issue ID (creates parent-child dep)

      --deps <DEPS>
          Dependencies (format: type:id,type:id)

  -e, --estimate <ESTIMATE>
          Time estimate in minutes

      --due <DUE>
          Due date (RFC3339 or relative)

      --defer <DEFER>
          Defer until date (RFC3339 or relative)

      --external-ref <EXTERNAL_REF>
          External reference

      --ephemeral
          Mark as ephemeral (not exported to JSONL)

  -s, --status <STATUS>
          Initial status (open, deferred, in_progress, closed)

      --acceptance-criteria <ACCEPTANCE_CRITERIA>
          Acceptance criteria recorded on the initial issue (beads_rust#408)
          
          [alias: --acceptance]

      --prerequisites <PREREQUISITES>
          Prerequisite checklist recorded separately from acceptance criteria

      --agent-context <AGENT_CONTEXT>
          Set the initial `agent_context` governing-instructions JSON (beads_rust#408).
          
          Accepts the same forms as `br update --agent-context`: inline JSON, `@path/to/file.json`, or `@path/to/file.yaml` (normalized to JSON). An empty string leaves the field unset. Invalid context is rejected before any issue, event, or JSONL record is created.

      --dry-run
          Preview without creating

      --silent
          Output only issue ID

  -f, --file <FILE>
          Create issues from a markdown file (bulk import)

      --agent-name <NAME>
          Tier 1 attribution: agent name (env: BR_AGENT_NAME). Recorded only
          
          [env: BR_AGENT_NAME=]

      --harness <HARNESS>
          Tier 1 attribution: harness identifier (env: BR_HARNESS). Recorded only
          
          [env: BR_HARNESS=]

      --model <MODEL>
          Tier 1 attribution: model identifier (env: BR_MODEL). Recorded only
          
          [env: BR_MODEL=]

      --db <DB>
          Database path (auto-discover .beads/*.db if not set; env: BEADS_DB)

      --actor <ACTOR>
          Actor name for audit trail

      --json
          Output as JSON

      --no-daemon
          Force direct mode (no daemon) - effectively no-op in br v1

      --no-auto-flush
          Skip auto JSONL export

      --no-auto-import
          Skip auto import check

      --allow-stale
          Allow stale DB (bypass freshness check warning)

      --lock-timeout <LOCK_TIMEOUT>
          `SQLite` busy/write-lock timeout in ms

      --no-db
          JSONL-only mode (no DB connection)

  -v, --verbose...
          Increase logging verbosity (-v, -vv)

  -q, --quiet
          Quiet mode (no output except errors)

      --no-color
          Disable colored output

  -h, --help
          Print help (see a summary with '-h')
```

### `br create -h` — `goldens/usage_help_short_create.out`

<!-- help-text: create-short -->
```text
Create a new issue

Usage: br create [OPTIONS] [TITLE]

Arguments:
  [TITLE]  Issue title

Options:
      --title <TITLE_FLAG>
          Issue title (alternative to positional argument)
  -t, --type <TYPE>
          Issue type (task, bug, feature, etc.)
      --slug <SLUG>
          Human-readable slug embedded in the generated ID. Example: `--slug survey-my-thing` produces an ID of the form `br-survey-my-thing-<hash>`, keeping the configured prefix and the uniquifying hash suffix. The slug is normalized to lowercase ASCII alphanumeric + single hyphens (runs of other characters collapse to one hyphen, leading/trailing hyphens are stripped, length is capped at 48 characters after normalization)
  -p, --priority <PRIORITY>
          Priority (0-4 or P0-P4)
  -d, --description <DESCRIPTION>
          Description [alias: --body]
      --description-file <PATH>
          Read the issue description verbatim from a file (or `-` for stdin)
  -a, --assignee <ASSIGNEE>
          Assign to person
      --owner <OWNER>
          Set owner email
  -l, --labels <LABELS>
          Labels (comma-separated)
      --parent <PARENT>
          Parent issue ID (creates parent-child dep)
      --deps <DEPS>
          Dependencies (format: type:id,type:id)
  -e, --estimate <ESTIMATE>
          Time estimate in minutes
      --due <DUE>
          Due date (RFC3339 or relative)
      --defer <DEFER>
          Defer until date (RFC3339 or relative)
      --external-ref <EXTERNAL_REF>
          External reference
      --ephemeral
          Mark as ephemeral (not exported to JSONL)
  -s, --status <STATUS>
          Initial status (open, deferred, in_progress, closed)
      --acceptance-criteria <ACCEPTANCE_CRITERIA>
          Acceptance criteria recorded on the initial issue (beads_rust#408) [alias: --acceptance]
      --prerequisites <PREREQUISITES>
          Prerequisite checklist recorded separately from acceptance criteria
      --agent-context <AGENT_CONTEXT>
          Set the initial `agent_context` governing-instructions JSON (beads_rust#408)
      --dry-run
          Preview without creating
      --silent
          Output only issue ID
  -f, --file <FILE>
          Create issues from a markdown file (bulk import)
      --agent-name <NAME>
          Tier 1 attribution: agent name (env: BR_AGENT_NAME). Recorded only [env: BR_AGENT_NAME=]
      --harness <HARNESS>
          Tier 1 attribution: harness identifier (env: BR_HARNESS). Recorded only [env: BR_HARNESS=]
      --model <MODEL>
          Tier 1 attribution: model identifier (env: BR_MODEL). Recorded only [env: BR_MODEL=]
      --db <DB>
          Database path (auto-discover .beads/*.db if not set; env: BEADS_DB)
      --actor <ACTOR>
          Actor name for audit trail
      --json
          Output as JSON
      --no-daemon
          Force direct mode (no daemon) - effectively no-op in br v1
      --no-auto-flush
          Skip auto JSONL export
      --no-auto-import
          Skip auto import check
      --allow-stale
          Allow stale DB (bypass freshness check warning)
      --lock-timeout <LOCK_TIMEOUT>
          `SQLite` busy/write-lock timeout in ms
      --no-db
          JSONL-only mode (no DB connection)
  -v, --verbose...
          Increase logging verbosity (-v, -vv)
  -q, --quiet
          Quiet mode (no output except errors)
      --no-color
          Disable colored output
  -h, --help
          Print help (see more with '--help')
```

### `br q --help` — `goldens/usage_help_q.out`

<!-- help-text: q -->
```text
Quick capture (create issue, print ID only)

Usage: br q [OPTIONS] [TITLE]...

Arguments:
  [TITLE]...  Issue title words

Options:
  -p, --priority <PRIORITY>          Priority (0-4 or P0-P4)
  -t, --type <TYPE>                  Issue type (task, bug, feature, etc.)
  -l, --labels <LABELS>              Labels to apply (repeatable, comma-separated allowed)
  -d, --description <DESCRIPTION>    Description [alias: --body]
      --parent <PARENT>              Parent issue ID (creates parent-child dep)
  -e, --estimate <ESTIMATE>          Time estimate in minutes
      --db <DB>                      Database path (auto-discover .beads/*.db if not set; env: BEADS_DB)
      --actor <ACTOR>                Actor name for audit trail
      --json                         Output as JSON
      --no-daemon                    Force direct mode (no daemon) - effectively no-op in br v1
      --no-auto-flush                Skip auto JSONL export
      --no-auto-import               Skip auto import check
      --allow-stale                  Allow stale DB (bypass freshness check warning)
      --lock-timeout <LOCK_TIMEOUT>  `SQLite` busy/write-lock timeout in ms
      --no-db                        JSONL-only mode (no DB connection)
  -v, --verbose...                   Increase logging verbosity (-v, -vv)
  -q, --quiet                        Quiet mode (no output except errors)
      --no-color                     Disable colored output
  -h, --help                         Print help
```

### `br q -h` — `goldens/usage_help_short_q.out`

<!-- help-text: q-short -->
```text
Quick capture (create issue, print ID only)

Usage: br q [OPTIONS] [TITLE]...

Arguments:
  [TITLE]...  Issue title words

Options:
  -p, --priority <PRIORITY>          Priority (0-4 or P0-P4)
  -t, --type <TYPE>                  Issue type (task, bug, feature, etc.)
  -l, --labels <LABELS>              Labels to apply (repeatable, comma-separated allowed)
  -d, --description <DESCRIPTION>    Description [alias: --body]
      --parent <PARENT>              Parent issue ID (creates parent-child dep)
  -e, --estimate <ESTIMATE>          Time estimate in minutes
      --db <DB>                      Database path (auto-discover .beads/*.db if not set; env: BEADS_DB)
      --actor <ACTOR>                Actor name for audit trail
      --json                         Output as JSON
      --no-daemon                    Force direct mode (no daemon) - effectively no-op in br v1
      --no-auto-flush                Skip auto JSONL export
      --no-auto-import               Skip auto import check
      --allow-stale                  Allow stale DB (bypass freshness check warning)
      --lock-timeout <LOCK_TIMEOUT>  `SQLite` busy/write-lock timeout in ms
      --no-db                        JSONL-only mode (no DB connection)
  -v, --verbose...                   Increase logging verbosity (-v, -vv)
  -q, --quiet                        Quiet mode (no output except errors)
      --no-color                     Disable colored output
  -h, --help                         Print help
```

### `br update --help` — `goldens/usage_help_update.out`

<!-- help-text: update -->
```text
Update an issue

Boxed: `UpdateArgs` is the largest argument struct by a wide margin, and keeping it inline would size every `Commands` value to it.

Usage: br update [OPTIONS] [IDS]...

Arguments:
  [IDS]...
          Issue IDs to update

Options:
      --title <TITLE>
          Update title

  -d, --description <DESCRIPTION>
          Update description
          
          [alias: --body]

      --description-file <PATH>
          Set the issue description verbatim from a file (or `-` for stdin), replacing the existing value. The entire file content is used unchanged from disk. Mutually exclusive with `-d/--description`; use this for multi-paragraph / markdown descriptions that are fragile to pass through shell quoting

      --design <DESIGN>
          Update design notes

      --acceptance-criteria <ACCEPTANCE_CRITERIA>
          Update acceptance criteria
          
          [alias: --acceptance]

      --prerequisites <PREREQUISITES>
          Replace the prerequisite checklist (empty string clears)

      --check-acceptance <ITEMS>
          Tick acceptance-criteria checklist items in place (GitHub #477).
          
          ITEMS is either a comma-separated list of 1-based item numbers (`1,4,5`) or a text selector that must match exactly one item (case-insensitive; an exact match wins, otherwise a unique substring). Repeat the flag for several text selectors. Every item is validated before anything is written, and the rest of the field is left byte-for-byte intact, so this never needs `--force`.

      --uncheck-acceptance <ITEMS>
          Untick acceptance-criteria checklist items in place; same selectors as `--check-acceptance`

      --add-acceptance <TEXT>
          Append an unchecked acceptance criterion (`- [ ] TEXT`) to the checklist without rewriting the field. Repeatable, like `--add-label`

      --notes <NOTES>
          Update additional notes

      --append-notes <TEXT>
          Append TEXT to notes without rewriting the field (GitHub #480).
          
          Existing notes are kept byte-for-byte; TEXT goes on a new line after them (creating the field when empty). Repeatable, like `--add-label`; several values are appended as consecutive lines. Re-running the same append is a no-op when the field already ends with that text. Append-only, so this never needs `--force`.

      --transition-comment <COMMENT>
          New comment bound atomically to the requested status transition. Required when policy lists `transition_comment` for the transition

  -s, --status <STATUS>
          Change status. Terminal states (`closed`, `tombstone`) are refused — use the dedicated `br close` / `br delete` commands so close-policy and dependency-rewiring are enforced (beads_rust#301)

  -p, --priority <PRIORITY>
          Change priority (0-4 or P0-P4)

  -t, --type <TYPE>
          Change issue type

      --assignee <ASSIGNEE>
          Assign to user (empty string clears)

      --owner <OWNER>
          Set owner (empty string clears)

      --claim
          Atomic claim (assignee=actor + `status=in_progress`)

      --force
          Force update even if issue is blocked, and allow a destructive rewrite of a non-empty description/design/acceptance-criteria/prerequisites/ notes/agent-context value: clearing it, or replacing it with content shorter than half its current length (GitHub #467, #481). Revisions that keep at least half the length pass without this flag

      --due <DUE>
          Set due date (empty string clears)

      --defer <DEFER>
          Set defer until date (empty string clears)

      --estimate <ESTIMATE>
          Set time estimate

      --add-label <ADD_LABEL>
          Add label(s)

      --remove-label <REMOVE_LABEL>
          Remove label(s)

      --set-labels <SET_LABELS>
          Set label(s) (replaces all) - repeatable like bd
          
          [alias: --labels]

      --parent <PARENT>
          Reparent to new parent (empty string removes parent)

      --external-ref <EXTERNAL_REF>
          Set external reference

      --source-repo <SOURCE_REPO>
          Override `source_repo` (display name; usually the repo's basename, e.g. `widget_engine`)

      --source-repo-path <SOURCE_REPO_PATH>
          Override `source_repo_path` (absolute path to the directory containing the `.beads` folder; populates the canonical filesystem location of the repo for cross-machine sync awareness — see #289)

      --agent-context <AGENT_CONTEXT>
          Set the `agent_context` governing-instructions JSON (beads_rust#297). Accepts inline JSON or a `@path` to a JSON or YAML file (extension determines parser; YAML is normalized to JSON before storage). Pass `--agent-context ""` (empty string) to clear the field back to NULL. Emitted on descendant `br show` / `br update --status in_progress` / `--claim` when `inherited_context.enabled` is set in `.beads/config.yaml`

      --session <SESSION>
          Set `closed_by_session` when closing

      --agent-name <NAME>
          Tier 1 attribution: agent name (env: BR_AGENT_NAME). Recorded only
          
          [env: BR_AGENT_NAME=]

      --harness <HARNESS>
          Tier 1 attribution: harness identifier (env: BR_HARNESS). Recorded only
          
          [env: BR_HARNESS=]

      --model <MODEL>
          Tier 1 attribution: model identifier (env: BR_MODEL). Recorded only
          
          [env: BR_MODEL=]

      --db <DB>
          Database path (auto-discover .beads/*.db if not set; env: BEADS_DB)

      --actor <ACTOR>
          Actor name for audit trail

      --json
          Output as JSON

      --no-daemon
          Force direct mode (no daemon) - effectively no-op in br v1

      --no-auto-flush
          Skip auto JSONL export

      --no-auto-import
          Skip auto import check

      --allow-stale
          Allow stale DB (bypass freshness check warning)

      --lock-timeout <LOCK_TIMEOUT>
          `SQLite` busy/write-lock timeout in ms

      --no-db
          JSONL-only mode (no DB connection)

  -v, --verbose...
          Increase logging verbosity (-v, -vv)

  -q, --quiet
          Quiet mode (no output except errors)

      --no-color
          Disable colored output

  -h, --help
          Print help (see a summary with '-h')
```

### `br update -h` — `goldens/usage_help_short_update.out`

<!-- help-text: update-short -->
```text
Update an issue

Usage: br update [OPTIONS] [IDS]...

Arguments:
  [IDS]...  Issue IDs to update

Options:
      --title <TITLE>
          Update title
  -d, --description <DESCRIPTION>
          Update description [alias: --body]
      --description-file <PATH>
          Set the issue description verbatim from a file (or `-` for stdin), replacing the existing value. The entire file content is used unchanged from disk. Mutually exclusive with `-d/--description`; use this for multi-paragraph / markdown descriptions that are fragile to pass through shell quoting
      --design <DESIGN>
          Update design notes
      --acceptance-criteria <ACCEPTANCE_CRITERIA>
          Update acceptance criteria [alias: --acceptance]
      --prerequisites <PREREQUISITES>
          Replace the prerequisite checklist (empty string clears)
      --check-acceptance <ITEMS>
          Tick acceptance-criteria checklist items in place (GitHub #477)
      --uncheck-acceptance <ITEMS>
          Untick acceptance-criteria checklist items in place; same selectors as `--check-acceptance`
      --add-acceptance <TEXT>
          Append an unchecked acceptance criterion (`- [ ] TEXT`) to the checklist without rewriting the field. Repeatable, like `--add-label`
      --notes <NOTES>
          Update additional notes
      --append-notes <TEXT>
          Append TEXT to notes without rewriting the field (GitHub #480)
      --transition-comment <COMMENT>
          New comment bound atomically to the requested status transition. Required when policy lists `transition_comment` for the transition
  -s, --status <STATUS>
          Change status. Terminal states (`closed`, `tombstone`) are refused — use the dedicated `br close` / `br delete` commands so close-policy and dependency-rewiring are enforced (beads_rust#301)
  -p, --priority <PRIORITY>
          Change priority (0-4 or P0-P4)
  -t, --type <TYPE>
          Change issue type
      --assignee <ASSIGNEE>
          Assign to user (empty string clears)
      --owner <OWNER>
          Set owner (empty string clears)
      --claim
          Atomic claim (assignee=actor + `status=in_progress`)
      --force
          Force update even if issue is blocked, and allow a destructive rewrite of a non-empty description/design/acceptance-criteria/prerequisites/ notes/agent-context value: clearing it, or replacing it with content shorter than half its current length (GitHub #467, #481). Revisions that keep at least half the length pass without this flag
      --due <DUE>
          Set due date (empty string clears)
      --defer <DEFER>
          Set defer until date (empty string clears)
      --estimate <ESTIMATE>
          Set time estimate
      --add-label <ADD_LABEL>
          Add label(s)
      --remove-label <REMOVE_LABEL>
          Remove label(s)
      --set-labels <SET_LABELS>
          Set label(s) (replaces all) - repeatable like bd [alias: --labels]
      --parent <PARENT>
          Reparent to new parent (empty string removes parent)
      --external-ref <EXTERNAL_REF>
          Set external reference
      --source-repo <SOURCE_REPO>
          Override `source_repo` (display name; usually the repo's basename, e.g. `widget_engine`)
      --source-repo-path <SOURCE_REPO_PATH>
          Override `source_repo_path` (absolute path to the directory containing the `.beads` folder; populates the canonical filesystem location of the repo for cross-machine sync awareness — see #289)
      --agent-context <AGENT_CONTEXT>
          Set the `agent_context` governing-instructions JSON (beads_rust#297). Accepts inline JSON or a `@path` to a JSON or YAML file (extension determines parser; YAML is normalized to JSON before storage). Pass `--agent-context ""` (empty string) to clear the field back to NULL. Emitted on descendant `br show` / `br update --status in_progress` / `--claim` when `inherited_context.enabled` is set in `.beads/config.yaml`
      --session <SESSION>
          Set `closed_by_session` when closing
      --agent-name <NAME>
          Tier 1 attribution: agent name (env: BR_AGENT_NAME). Recorded only [env: BR_AGENT_NAME=]
      --harness <HARNESS>
          Tier 1 attribution: harness identifier (env: BR_HARNESS). Recorded only [env: BR_HARNESS=]
      --model <MODEL>
          Tier 1 attribution: model identifier (env: BR_MODEL). Recorded only [env: BR_MODEL=]
      --db <DB>
          Database path (auto-discover .beads/*.db if not set; env: BEADS_DB)
      --actor <ACTOR>
          Actor name for audit trail
      --json
          Output as JSON
      --no-daemon
          Force direct mode (no daemon) - effectively no-op in br v1
      --no-auto-flush
          Skip auto JSONL export
      --no-auto-import
          Skip auto import check
      --allow-stale
          Allow stale DB (bypass freshness check warning)
      --lock-timeout <LOCK_TIMEOUT>
          `SQLite` busy/write-lock timeout in ms
      --no-db
          JSONL-only mode (no DB connection)
  -v, --verbose...
          Increase logging verbosity (-v, -vv)
  -q, --quiet
          Quiet mode (no output except errors)
      --no-color
          Disable colored output
  -h, --help
          Print help (see more with '--help')
```

### `br close --help` — `goldens/usage_help_close.out`

<!-- help-text: close -->
```text
Close an issue

Usage: br close [OPTIONS] [IDS]...

Arguments:
  [IDS]...  Issue IDs to close (uses last-touched if empty)

Options:
  -r, --reason <REASON>               Close reason
      --transition-comment <COMMENT>  New comment committed atomically with each close transition. This is distinct from close metadata in `--reason`
  -f, --force                         Close even if blocked by open dependencies
      --suggest-next                  After closing, return newly unblocked issues (single ID only)
      --session <SESSION>             Session ID for tracking
      --robot                         Machine-readable output (alias for --json)
      --agent-name <NAME>             Tier 1 attribution: agent name (env: BR_AGENT_NAME) [env: BR_AGENT_NAME=]
      --harness <HARNESS>             Tier 1 attribution: harness identifier (env: BR_HARNESS) [env: BR_HARNESS=]
      --model <MODEL>                 Tier 1 attribution: model identifier (env: BR_MODEL) [env: BR_MODEL=]
      --bypass-policy                 Bypass closure-time policy gates. Requires `--bypass-reason`. Only honoured when `.beads/policy.yaml` has `allow_bypass: true` (which is the default)
      --bypass-reason <REASON>        Reason for bypassing policy gates. Required when `--bypass-policy` is set
      --db <DB>                       Database path (auto-discover .beads/*.db if not set; env: BEADS_DB)
      --actor <ACTOR>                 Actor name for audit trail
      --json                          Output as JSON
      --no-daemon                     Force direct mode (no daemon) - effectively no-op in br v1
      --no-auto-flush                 Skip auto JSONL export
      --no-auto-import                Skip auto import check
      --allow-stale                   Allow stale DB (bypass freshness check warning)
      --lock-timeout <LOCK_TIMEOUT>   `SQLite` busy/write-lock timeout in ms
      --no-db                         JSONL-only mode (no DB connection)
  -v, --verbose...                    Increase logging verbosity (-v, -vv)
  -q, --quiet                         Quiet mode (no output except errors)
      --no-color                      Disable colored output
  -h, --help                          Print help
```

### `br close -h` — `goldens/usage_help_short_close.out`

<!-- help-text: close-short -->
```text
Close an issue

Usage: br close [OPTIONS] [IDS]...

Arguments:
  [IDS]...  Issue IDs to close (uses last-touched if empty)

Options:
  -r, --reason <REASON>               Close reason
      --transition-comment <COMMENT>  New comment committed atomically with each close transition. This is distinct from close metadata in `--reason`
  -f, --force                         Close even if blocked by open dependencies
      --suggest-next                  After closing, return newly unblocked issues (single ID only)
      --session <SESSION>             Session ID for tracking
      --robot                         Machine-readable output (alias for --json)
      --agent-name <NAME>             Tier 1 attribution: agent name (env: BR_AGENT_NAME) [env: BR_AGENT_NAME=]
      --harness <HARNESS>             Tier 1 attribution: harness identifier (env: BR_HARNESS) [env: BR_HARNESS=]
      --model <MODEL>                 Tier 1 attribution: model identifier (env: BR_MODEL) [env: BR_MODEL=]
      --bypass-policy                 Bypass closure-time policy gates. Requires `--bypass-reason`. Only honoured when `.beads/policy.yaml` has `allow_bypass: true` (which is the default)
      --bypass-reason <REASON>        Reason for bypassing policy gates. Required when `--bypass-policy` is set
      --db <DB>                       Database path (auto-discover .beads/*.db if not set; env: BEADS_DB)
      --actor <ACTOR>                 Actor name for audit trail
      --json                          Output as JSON
      --no-daemon                     Force direct mode (no daemon) - effectively no-op in br v1
      --no-auto-flush                 Skip auto JSONL export
      --no-auto-import                Skip auto import check
      --allow-stale                   Allow stale DB (bypass freshness check warning)
      --lock-timeout <LOCK_TIMEOUT>   `SQLite` busy/write-lock timeout in ms
      --no-db                         JSONL-only mode (no DB connection)
  -v, --verbose...                    Increase logging verbosity (-v, -vv)
  -q, --quiet                         Quiet mode (no output except errors)
      --no-color                      Disable colored output
  -h, --help                          Print help
```

### `br reopen --help` — `goldens/usage_help_reopen.out`

<!-- help-text: reopen -->
```text
Reopen an issue

Usage: br reopen [OPTIONS] [IDS]...

Arguments:
  [IDS]...  Issue IDs to reopen (uses last-touched if empty)

Options:
  -r, --reason <REASON>              Reason for reopening (stored as a comment)
      --robot                        Machine-readable output (alias for --json)
      --agent-name <NAME>            Tier 1 attribution: agent name (env: BR_AGENT_NAME). Recorded only [env: BR_AGENT_NAME=]
      --harness <HARNESS>            Tier 1 attribution: harness identifier (env: BR_HARNESS). Recorded only [env: BR_HARNESS=]
      --model <MODEL>                Tier 1 attribution: model identifier (env: BR_MODEL). Recorded only [env: BR_MODEL=]
      --db <DB>                      Database path (auto-discover .beads/*.db if not set; env: BEADS_DB)
      --actor <ACTOR>                Actor name for audit trail
      --json                         Output as JSON
      --no-daemon                    Force direct mode (no daemon) - effectively no-op in br v1
      --no-auto-flush                Skip auto JSONL export
      --no-auto-import               Skip auto import check
      --allow-stale                  Allow stale DB (bypass freshness check warning)
      --lock-timeout <LOCK_TIMEOUT>  `SQLite` busy/write-lock timeout in ms
      --no-db                        JSONL-only mode (no DB connection)
  -v, --verbose...                   Increase logging verbosity (-v, -vv)
  -q, --quiet                        Quiet mode (no output except errors)
      --no-color                     Disable colored output
  -h, --help                         Print help
```

### `br reopen -h` — `goldens/usage_help_short_reopen.out`

<!-- help-text: reopen-short -->
```text
Reopen an issue

Usage: br reopen [OPTIONS] [IDS]...

Arguments:
  [IDS]...  Issue IDs to reopen (uses last-touched if empty)

Options:
  -r, --reason <REASON>              Reason for reopening (stored as a comment)
      --robot                        Machine-readable output (alias for --json)
      --agent-name <NAME>            Tier 1 attribution: agent name (env: BR_AGENT_NAME). Recorded only [env: BR_AGENT_NAME=]
      --harness <HARNESS>            Tier 1 attribution: harness identifier (env: BR_HARNESS). Recorded only [env: BR_HARNESS=]
      --model <MODEL>                Tier 1 attribution: model identifier (env: BR_MODEL). Recorded only [env: BR_MODEL=]
      --db <DB>                      Database path (auto-discover .beads/*.db if not set; env: BEADS_DB)
      --actor <ACTOR>                Actor name for audit trail
      --json                         Output as JSON
      --no-daemon                    Force direct mode (no daemon) - effectively no-op in br v1
      --no-auto-flush                Skip auto JSONL export
      --no-auto-import               Skip auto import check
      --allow-stale                  Allow stale DB (bypass freshness check warning)
      --lock-timeout <LOCK_TIMEOUT>  `SQLite` busy/write-lock timeout in ms
      --no-db                        JSONL-only mode (no DB connection)
  -v, --verbose...                   Increase logging verbosity (-v, -vv)
  -q, --quiet                        Quiet mode (no output except errors)
      --no-color                     Disable colored output
  -h, --help                         Print help
```

### `br defer --help` — `goldens/usage_help_defer.out`

<!-- help-text: defer -->
```text
Defer issues (schedule for later)

Usage: br defer [OPTIONS] [IDS]...

Arguments:
  [IDS]...  Issue IDs to defer

Options:
      --until <UNTIL>                 Defer until date/time (e.g., `+1h`, `tomorrow`, `2025-01-15`)
      --robot                         Machine-readable output (alias for --json)
      --transition-comment <COMMENT>  New comment committed atomically with each defer transition
      --agent-name <NAME>             Tier 1 attribution: agent name (env: BR_AGENT_NAME). Recorded only [env: BR_AGENT_NAME=]
      --harness <HARNESS>             Tier 1 attribution: harness identifier (env: BR_HARNESS). Recorded only [env: BR_HARNESS=]
      --model <MODEL>                 Tier 1 attribution: model identifier (env: BR_MODEL). Recorded only [env: BR_MODEL=]
      --db <DB>                       Database path (auto-discover .beads/*.db if not set; env: BEADS_DB)
      --actor <ACTOR>                 Actor name for audit trail
      --json                          Output as JSON
      --no-daemon                     Force direct mode (no daemon) - effectively no-op in br v1
      --no-auto-flush                 Skip auto JSONL export
      --no-auto-import                Skip auto import check
      --allow-stale                   Allow stale DB (bypass freshness check warning)
      --lock-timeout <LOCK_TIMEOUT>   `SQLite` busy/write-lock timeout in ms
      --no-db                         JSONL-only mode (no DB connection)
  -v, --verbose...                    Increase logging verbosity (-v, -vv)
  -q, --quiet                         Quiet mode (no output except errors)
      --no-color                      Disable colored output
  -h, --help                          Print help
```

### `br defer -h` — `goldens/usage_help_short_defer.out`

<!-- help-text: defer-short -->
```text
Defer issues (schedule for later)

Usage: br defer [OPTIONS] [IDS]...

Arguments:
  [IDS]...  Issue IDs to defer

Options:
      --until <UNTIL>                 Defer until date/time (e.g., `+1h`, `tomorrow`, `2025-01-15`)
      --robot                         Machine-readable output (alias for --json)
      --transition-comment <COMMENT>  New comment committed atomically with each defer transition
      --agent-name <NAME>             Tier 1 attribution: agent name (env: BR_AGENT_NAME). Recorded only [env: BR_AGENT_NAME=]
      --harness <HARNESS>             Tier 1 attribution: harness identifier (env: BR_HARNESS). Recorded only [env: BR_HARNESS=]
      --model <MODEL>                 Tier 1 attribution: model identifier (env: BR_MODEL). Recorded only [env: BR_MODEL=]
      --db <DB>                       Database path (auto-discover .beads/*.db if not set; env: BEADS_DB)
      --actor <ACTOR>                 Actor name for audit trail
      --json                          Output as JSON
      --no-daemon                     Force direct mode (no daemon) - effectively no-op in br v1
      --no-auto-flush                 Skip auto JSONL export
      --no-auto-import                Skip auto import check
      --allow-stale                   Allow stale DB (bypass freshness check warning)
      --lock-timeout <LOCK_TIMEOUT>   `SQLite` busy/write-lock timeout in ms
      --no-db                         JSONL-only mode (no DB connection)
  -v, --verbose...                    Increase logging verbosity (-v, -vv)
  -q, --quiet                         Quiet mode (no output except errors)
      --no-color                      Disable colored output
  -h, --help                          Print help
```

### `br undefer --help` — `goldens/usage_help_undefer.out`

<!-- help-text: undefer -->
```text
Undefer issues (make ready again)

Usage: br undefer [OPTIONS] [IDS]...

Arguments:
  [IDS]...  Issue IDs to undefer

Options:
      --robot                         Machine-readable output (alias for --json)
      --transition-comment <COMMENT>  New comment committed atomically with each undefer transition
      --agent-name <NAME>             Tier 1 attribution: agent name (env: BR_AGENT_NAME). Recorded only [env: BR_AGENT_NAME=]
      --harness <HARNESS>             Tier 1 attribution: harness identifier (env: BR_HARNESS). Recorded only [env: BR_HARNESS=]
      --model <MODEL>                 Tier 1 attribution: model identifier (env: BR_MODEL). Recorded only [env: BR_MODEL=]
      --db <DB>                       Database path (auto-discover .beads/*.db if not set; env: BEADS_DB)
      --actor <ACTOR>                 Actor name for audit trail
      --json                          Output as JSON
      --no-daemon                     Force direct mode (no daemon) - effectively no-op in br v1
      --no-auto-flush                 Skip auto JSONL export
      --no-auto-import                Skip auto import check
      --allow-stale                   Allow stale DB (bypass freshness check warning)
      --lock-timeout <LOCK_TIMEOUT>   `SQLite` busy/write-lock timeout in ms
      --no-db                         JSONL-only mode (no DB connection)
  -v, --verbose...                    Increase logging verbosity (-v, -vv)
  -q, --quiet                         Quiet mode (no output except errors)
      --no-color                      Disable colored output
  -h, --help                          Print help
```

### `br undefer -h` — `goldens/usage_help_short_undefer.out`

<!-- help-text: undefer-short -->
```text
Undefer issues (make ready again)

Usage: br undefer [OPTIONS] [IDS]...

Arguments:
  [IDS]...  Issue IDs to undefer

Options:
      --robot                         Machine-readable output (alias for --json)
      --transition-comment <COMMENT>  New comment committed atomically with each undefer transition
      --agent-name <NAME>             Tier 1 attribution: agent name (env: BR_AGENT_NAME). Recorded only [env: BR_AGENT_NAME=]
      --harness <HARNESS>             Tier 1 attribution: harness identifier (env: BR_HARNESS). Recorded only [env: BR_HARNESS=]
      --model <MODEL>                 Tier 1 attribution: model identifier (env: BR_MODEL). Recorded only [env: BR_MODEL=]
      --db <DB>                       Database path (auto-discover .beads/*.db if not set; env: BEADS_DB)
      --actor <ACTOR>                 Actor name for audit trail
      --json                          Output as JSON
      --no-daemon                     Force direct mode (no daemon) - effectively no-op in br v1
      --no-auto-flush                 Skip auto JSONL export
      --no-auto-import                Skip auto import check
      --allow-stale                   Allow stale DB (bypass freshness check warning)
      --lock-timeout <LOCK_TIMEOUT>   `SQLite` busy/write-lock timeout in ms
      --no-db                         JSONL-only mode (no DB connection)
  -v, --verbose...                    Increase logging verbosity (-v, -vv)
  -q, --quiet                         Quiet mode (no output except errors)
      --no-color                      Disable colored output
  -h, --help                          Print help
```

### `br delete --help` — `goldens/usage_help_delete.out`

<!-- help-text: delete -->
```text
Delete an issue (creates tombstone)

Usage: br delete [OPTIONS] [IDS]...

Arguments:
  [IDS]...  Issue IDs to delete

Options:
      --reason <REASON>              Delete reason (default: "delete") [default: delete]
      --from-file <FROM_FILE>        Read IDs from file (one per line, # comments ignored)
      --cascade                      Delete dependents recursively
      --force                        Bypass dependent checks (orphans dependents)
      --hard                         Prune tombstones from JSONL immediately
      --dry-run                      Preview only, no changes
      --db <DB>                      Database path (auto-discover .beads/*.db if not set; env: BEADS_DB)
      --actor <ACTOR>                Actor name for audit trail
      --json                         Output as JSON
      --no-daemon                    Force direct mode (no daemon) - effectively no-op in br v1
      --no-auto-flush                Skip auto JSONL export
      --no-auto-import               Skip auto import check
      --allow-stale                  Allow stale DB (bypass freshness check warning)
      --lock-timeout <LOCK_TIMEOUT>  `SQLite` busy/write-lock timeout in ms
      --no-db                        JSONL-only mode (no DB connection)
  -v, --verbose...                   Increase logging verbosity (-v, -vv)
  -q, --quiet                        Quiet mode (no output except errors)
      --no-color                     Disable colored output
  -h, --help                         Print help
```

### `br delete -h` — `goldens/usage_help_short_delete.out`

<!-- help-text: delete-short -->
```text
Delete an issue (creates tombstone)

Usage: br delete [OPTIONS] [IDS]...

Arguments:
  [IDS]...  Issue IDs to delete

Options:
      --reason <REASON>              Delete reason (default: "delete") [default: delete]
      --from-file <FROM_FILE>        Read IDs from file (one per line, # comments ignored)
      --cascade                      Delete dependents recursively
      --force                        Bypass dependent checks (orphans dependents)
      --hard                         Prune tombstones from JSONL immediately
      --dry-run                      Preview only, no changes
      --db <DB>                      Database path (auto-discover .beads/*.db if not set; env: BEADS_DB)
      --actor <ACTOR>                Actor name for audit trail
      --json                         Output as JSON
      --no-daemon                    Force direct mode (no daemon) - effectively no-op in br v1
      --no-auto-flush                Skip auto JSONL export
      --no-auto-import               Skip auto import check
      --allow-stale                  Allow stale DB (bypass freshness check warning)
      --lock-timeout <LOCK_TIMEOUT>  `SQLite` busy/write-lock timeout in ms
      --no-db                        JSONL-only mode (no DB connection)
  -v, --verbose...                   Increase logging verbosity (-v, -vv)
  -q, --quiet                        Quiet mode (no output except errors)
      --no-color                     Disable colored output
  -h, --help                         Print help
```

### `br show --help` — `goldens/usage_help_show.out`

<!-- help-text: show -->
```text
Show issue details

Usage: br show [OPTIONS] [IDS]...

Arguments:
  [IDS]...
          Issue IDs

Options:
      --format <FORMAT>
          Output format (text, json, toon). Env: BR_OUTPUT_FORMAT, TOON_DEFAULT_FORMAT

          Possible values:
          - text: Human-readable text (default)
          - json: JSON output
          - toon: TOON format (token-optimized object notation)

      --wrap
          Soft-wrap long lines to the terminal width in text output. Wrapping is now on by default; this flag is kept for backwards compatibility

      --no-wrap
          Disable soft-wrapping; let long description/comment lines extend past the panel width (the pre-#370 behavior)

      --stats
          Show token savings stats when using TOON output

      --db <DB>
          Database path (auto-discover .beads/*.db if not set; env: BEADS_DB)

      --actor <ACTOR>
          Actor name for audit trail

      --json
          Output as JSON

      --no-daemon
          Force direct mode (no daemon) - effectively no-op in br v1

      --no-auto-flush
          Skip auto JSONL export

      --no-auto-import
          Skip auto import check

      --allow-stale
          Allow stale DB (bypass freshness check warning)

      --lock-timeout <LOCK_TIMEOUT>
          `SQLite` busy/write-lock timeout in ms

      --no-db
          JSONL-only mode (no DB connection)

  -v, --verbose...
          Increase logging verbosity (-v, -vv)

  -q, --quiet
          Quiet mode (no output except errors)

      --no-color
          Disable colored output

  -h, --help
          Print help (see a summary with '-h')
```

### `br show -h` — `goldens/usage_help_short_show.out`

<!-- help-text: show-short -->
```text
Show issue details

Usage: br show [OPTIONS] [IDS]...

Arguments:
  [IDS]...  Issue IDs

Options:
      --format <FORMAT>              Output format (text, json, toon). Env: BR_OUTPUT_FORMAT, TOON_DEFAULT_FORMAT [possible values: text, json, toon]
      --wrap                         Soft-wrap long lines to the terminal width in text output. Wrapping is now on by default; this flag is kept for backwards compatibility
      --no-wrap                      Disable soft-wrapping; let long description/comment lines extend past the panel width (the pre-#370 behavior)
      --stats                        Show token savings stats when using TOON output
      --db <DB>                      Database path (auto-discover .beads/*.db if not set; env: BEADS_DB)
      --actor <ACTOR>                Actor name for audit trail
      --json                         Output as JSON
      --no-daemon                    Force direct mode (no daemon) - effectively no-op in br v1
      --no-auto-flush                Skip auto JSONL export
      --no-auto-import               Skip auto import check
      --allow-stale                  Allow stale DB (bypass freshness check warning)
      --lock-timeout <LOCK_TIMEOUT>  `SQLite` busy/write-lock timeout in ms
      --no-db                        JSONL-only mode (no DB connection)
  -v, --verbose...                   Increase logging verbosity (-v, -vv)
  -q, --quiet                        Quiet mode (no output except errors)
      --no-color                     Disable colored output
  -h, --help                         Print help (see more with '--help')
```

### `br search --help` — `goldens/usage_help_search.out`

<!-- help-text: search -->
```text
Search issues (matches title, description, id, and comment text)

Usage: br search [OPTIONS] <QUERY>

Arguments:
  <QUERY>
          Search query

Options:
  -s, --status <STATUS>
          Filter by status (can be repeated; 'all' matches every status)

  -t, --type <TYPE>
          Filter by issue type (can be repeated)

      --assignee <ASSIGNEE>
          Filter by assignee

      --unassigned
          Filter for unassigned issues only

      --id <ID>
          Filter by specific IDs (can be repeated)

  -l, --label <LABEL>
          Filter by label (AND logic, can be repeated)

      --label-any <LABEL_ANY>
          Filter by label (OR logic, can be repeated)

  -p, --priority <PRIORITY>
          Filter by priority: 0-4 or P0-P4, ranges like 0-1, comma lists; repeatable

      --priority-min <PRIORITY_MIN>
          Filter by minimum priority (0=critical, 4=backlog)

      --priority-max <PRIORITY_MAX>
          Filter by maximum priority

      --title-contains <TITLE_CONTAINS>
          Title contains substring

      --desc-contains <DESC_CONTAINS>
          Description contains substring

      --notes-contains <NOTES_CONTAINS>
          Notes contains substring

  -a, --all
          Include closed issues (default excludes closed)

      --limit <LIMIT>
          Maximum number of results (0 = unlimited; default: unlimited — the full work surface)

      --offset <OFFSET>
          Number of results to skip (for pagination, default: 0)

      --sort <SORT>
          Sort field (`priority`, `created_at`, `updated_at`, `title`)

  -r, --reverse
          Reverse sort order

      --deferred
          Include deferred issues

      --overdue
          Filter for overdue issues

      --long
          Use long output format

      --pretty
          Use tree/pretty output format

      --tree
          Group children under their parents with tree connectors (text output). Hierarchy follows dotted child IDs (`bd-abc.2` under `bd-abc`); a child whose parent is filtered out of the result set is shown at the top level (GitHub #475)

      --wrap
          Wrap long lines instead of truncating in text output

      --format <FORMAT>
          Output format (text, json, csv, toon). Env: BR_OUTPUT_FORMAT, TOON_DEFAULT_FORMAT

          Possible values:
          - text: Human-readable text (default)
          - json: JSON output
          - csv:  CSV output with configurable fields
          - toon: TOON format (token-optimized object notation)

      --stats
          Show token savings stats when using TOON output

      --fields <FIELDS>
          CSV fields to include (comma-separated)
          
          Available: id, title, description, status, priority, `issue_type`, assignee, owner, `created_at`, `updated_at`, `closed_at`, `due_at`, `defer_until`, notes, `external_ref`
          
          Default: id, title, status, priority, `issue_type`, assignee, `created_at`, `updated_at`

      --db <DB>
          Database path (auto-discover .beads/*.db if not set; env: BEADS_DB)

      --actor <ACTOR>
          Actor name for audit trail

      --json
          Output as JSON

      --no-daemon
          Force direct mode (no daemon) - effectively no-op in br v1

      --no-auto-flush
          Skip auto JSONL export

      --no-auto-import
          Skip auto import check

      --allow-stale
          Allow stale DB (bypass freshness check warning)

      --lock-timeout <LOCK_TIMEOUT>
          `SQLite` busy/write-lock timeout in ms

      --no-db
          JSONL-only mode (no DB connection)

  -v, --verbose...
          Increase logging verbosity (-v, -vv)

  -q, --quiet
          Quiet mode (no output except errors)

      --no-color
          Disable colored output

  -h, --help
          Print help (see a summary with '-h')
```

### `br search -h` — `goldens/usage_help_short_search.out`

<!-- help-text: search-short -->
```text
Search issues (matches title, description, id, and comment text)

Usage: br search [OPTIONS] <QUERY>

Arguments:
  <QUERY>  Search query

Options:
  -s, --status <STATUS>
          Filter by status (can be repeated; 'all' matches every status)
  -t, --type <TYPE>
          Filter by issue type (can be repeated)
      --assignee <ASSIGNEE>
          Filter by assignee
      --unassigned
          Filter for unassigned issues only
      --id <ID>
          Filter by specific IDs (can be repeated)
  -l, --label <LABEL>
          Filter by label (AND logic, can be repeated)
      --label-any <LABEL_ANY>
          Filter by label (OR logic, can be repeated)
  -p, --priority <PRIORITY>
          Filter by priority: 0-4 or P0-P4, ranges like 0-1, comma lists; repeatable
      --priority-min <PRIORITY_MIN>
          Filter by minimum priority (0=critical, 4=backlog)
      --priority-max <PRIORITY_MAX>
          Filter by maximum priority
      --title-contains <TITLE_CONTAINS>
          Title contains substring
      --desc-contains <DESC_CONTAINS>
          Description contains substring
      --notes-contains <NOTES_CONTAINS>
          Notes contains substring
  -a, --all
          Include closed issues (default excludes closed)
      --limit <LIMIT>
          Maximum number of results (0 = unlimited; default: unlimited — the full work surface)
      --offset <OFFSET>
          Number of results to skip (for pagination, default: 0)
      --sort <SORT>
          Sort field (`priority`, `created_at`, `updated_at`, `title`)
  -r, --reverse
          Reverse sort order
      --deferred
          Include deferred issues
      --overdue
          Filter for overdue issues
      --long
          Use long output format
      --pretty
          Use tree/pretty output format
      --tree
          Group children under their parents with tree connectors (text output). Hierarchy follows dotted child IDs (`bd-abc.2` under `bd-abc`); a child whose parent is filtered out of the result set is shown at the top level (GitHub #475)
      --wrap
          Wrap long lines instead of truncating in text output
      --format <FORMAT>
          Output format (text, json, csv, toon). Env: BR_OUTPUT_FORMAT, TOON_DEFAULT_FORMAT [possible values: text, json, csv, toon]
      --stats
          Show token savings stats when using TOON output
      --fields <FIELDS>
          CSV fields to include (comma-separated)
      --db <DB>
          Database path (auto-discover .beads/*.db if not set; env: BEADS_DB)
      --actor <ACTOR>
          Actor name for audit trail
      --json
          Output as JSON
      --no-daemon
          Force direct mode (no daemon) - effectively no-op in br v1
      --no-auto-flush
          Skip auto JSONL export
      --no-auto-import
          Skip auto import check
      --allow-stale
          Allow stale DB (bypass freshness check warning)
      --lock-timeout <LOCK_TIMEOUT>
          `SQLite` busy/write-lock timeout in ms
      --no-db
          JSONL-only mode (no DB connection)
  -v, --verbose...
          Increase logging verbosity (-v, -vv)
  -q, --quiet
          Quiet mode (no output except errors)
      --no-color
          Disable colored output
  -h, --help
          Print help (see more with '--help')
```

### `br count --help` — `goldens/usage_help_count.out`

<!-- help-text: count -->
```text
Count issues with optional grouping

Usage: br count [OPTIONS]

Options:
      --by <BY>
          Group counts by field [possible values: status, priority, type, assignee, label]
      --by-status
          Group by status (alias for --by status)
      --by-priority
          Group by priority (alias for --by priority)
      --by-type
          Group by type (alias for --by type)
      --by-assignee
          Group by assignee (alias for --by assignee)
      --by-label
          Group by label (alias for --by label)
      --status <STATUS>
          Filter by status (repeatable or comma-separated; 'all' matches every status)
      --type <TYPES>
          Filter by issue type (repeatable or comma-separated)
      --priority <PRIORITY>
          Filter by priority (0-4 or P0-P4; repeatable or comma-separated)
      --assignee <ASSIGNEE>
          Filter by assignee
      --unassigned
          Only include unassigned issues
      --include-closed
          Include closed issues; tombstones require `--status tombstone`
      --include-templates
          Include template issues
      --title-contains <TITLE_CONTAINS>
          Title contains substring
      --db <DB>
          Database path (auto-discover .beads/*.db if not set; env: BEADS_DB)
      --actor <ACTOR>
          Actor name for audit trail
      --json
          Output as JSON
      --no-daemon
          Force direct mode (no daemon) - effectively no-op in br v1
      --no-auto-flush
          Skip auto JSONL export
      --no-auto-import
          Skip auto import check
      --allow-stale
          Allow stale DB (bypass freshness check warning)
      --lock-timeout <LOCK_TIMEOUT>
          `SQLite` busy/write-lock timeout in ms
      --no-db
          JSONL-only mode (no DB connection)
  -v, --verbose...
          Increase logging verbosity (-v, -vv)
  -q, --quiet
          Quiet mode (no output except errors)
      --no-color
          Disable colored output
  -h, --help
          Print help
```

### `br count -h` — `goldens/usage_help_short_count.out`

<!-- help-text: count-short -->
```text
Count issues with optional grouping

Usage: br count [OPTIONS]

Options:
      --by <BY>
          Group counts by field [possible values: status, priority, type, assignee, label]
      --by-status
          Group by status (alias for --by status)
      --by-priority
          Group by priority (alias for --by priority)
      --by-type
          Group by type (alias for --by type)
      --by-assignee
          Group by assignee (alias for --by assignee)
      --by-label
          Group by label (alias for --by label)
      --status <STATUS>
          Filter by status (repeatable or comma-separated; 'all' matches every status)
      --type <TYPES>
          Filter by issue type (repeatable or comma-separated)
      --priority <PRIORITY>
          Filter by priority (0-4 or P0-P4; repeatable or comma-separated)
      --assignee <ASSIGNEE>
          Filter by assignee
      --unassigned
          Only include unassigned issues
      --include-closed
          Include closed issues; tombstones require `--status tombstone`
      --include-templates
          Include template issues
      --title-contains <TITLE_CONTAINS>
          Title contains substring
      --db <DB>
          Database path (auto-discover .beads/*.db if not set; env: BEADS_DB)
      --actor <ACTOR>
          Actor name for audit trail
      --json
          Output as JSON
      --no-daemon
          Force direct mode (no daemon) - effectively no-op in br v1
      --no-auto-flush
          Skip auto JSONL export
      --no-auto-import
          Skip auto import check
      --allow-stale
          Allow stale DB (bypass freshness check warning)
      --lock-timeout <LOCK_TIMEOUT>
          `SQLite` busy/write-lock timeout in ms
      --no-db
          JSONL-only mode (no DB connection)
  -v, --verbose...
          Increase logging verbosity (-v, -vv)
  -q, --quiet
          Quiet mode (no output except errors)
      --no-color
          Disable colored output
  -h, --help
          Print help
```

### `br stats --help` — `goldens/usage_help_stats.out`

<!-- help-text: stats -->
```text
Show project statistics

Usage: br stats [OPTIONS]

Options:
      --by-type
          Show breakdown by issue type

      --by-priority
          Show breakdown by priority

      --by-assignee
          Show breakdown by assignee

      --by-label
          Show breakdown by label

      --activity
          Include recent activity stats explicitly (default unless `--no-activity`)

      --no-activity
          Skip recent activity stats (for performance)

      --activity-hours <ACTIVITY_HOURS>
          Activity window in hours (default: 24)
          
          [default: 24]

      --format <FORMAT>
          Output format (text, json, toon). Env: BR_OUTPUT_FORMAT, TOON_DEFAULT_FORMAT

          Possible values:
          - text: Human-readable text (default)
          - json: JSON output
          - toon: TOON format (token-optimized object notation)

      --stats
          Show token savings stats when using TOON output

      --robot
          Machine-readable output (alias for --json)

      --db <DB>
          Database path (auto-discover .beads/*.db if not set; env: BEADS_DB)

      --actor <ACTOR>
          Actor name for audit trail

      --json
          Output as JSON

      --no-daemon
          Force direct mode (no daemon) - effectively no-op in br v1

      --no-auto-flush
          Skip auto JSONL export

      --no-auto-import
          Skip auto import check

      --allow-stale
          Allow stale DB (bypass freshness check warning)

      --lock-timeout <LOCK_TIMEOUT>
          `SQLite` busy/write-lock timeout in ms

      --no-db
          JSONL-only mode (no DB connection)

  -v, --verbose...
          Increase logging verbosity (-v, -vv)

  -q, --quiet
          Quiet mode (no output except errors)

      --no-color
          Disable colored output

  -h, --help
          Print help (see a summary with '-h')
```

### `br stats -h` — `goldens/usage_help_short_stats.out`

<!-- help-text: stats-short -->
```text
Show project statistics

Usage: br stats [OPTIONS]

Options:
      --by-type
          Show breakdown by issue type
      --by-priority
          Show breakdown by priority
      --by-assignee
          Show breakdown by assignee
      --by-label
          Show breakdown by label
      --activity
          Include recent activity stats explicitly (default unless `--no-activity`)
      --no-activity
          Skip recent activity stats (for performance)
      --activity-hours <ACTIVITY_HOURS>
          Activity window in hours (default: 24) [default: 24]
      --format <FORMAT>
          Output format (text, json, toon). Env: BR_OUTPUT_FORMAT, TOON_DEFAULT_FORMAT [possible values: text, json, toon]
      --stats
          Show token savings stats when using TOON output
      --robot
          Machine-readable output (alias for --json)
      --db <DB>
          Database path (auto-discover .beads/*.db if not set; env: BEADS_DB)
      --actor <ACTOR>
          Actor name for audit trail
      --json
          Output as JSON
      --no-daemon
          Force direct mode (no daemon) - effectively no-op in br v1
      --no-auto-flush
          Skip auto JSONL export
      --no-auto-import
          Skip auto import check
      --allow-stale
          Allow stale DB (bypass freshness check warning)
      --lock-timeout <LOCK_TIMEOUT>
          `SQLite` busy/write-lock timeout in ms
      --no-db
          JSONL-only mode (no DB connection)
  -v, --verbose...
          Increase logging verbosity (-v, -vv)
  -q, --quiet
          Quiet mode (no output except errors)
      --no-color
          Disable colored output
  -h, --help
          Print help (see more with '--help')
```

### `br ready --help` — `goldens/usage_help_ready.out`

<!-- help-text: ready -->
```text
List ready issues (open, unblocked, not deferred)

Usage: br ready [OPTIONS]

Options:
      --limit <LIMIT>
          Maximum number of issues to return (0 = unlimited; default: unlimited — the full ready set)
          
          [default: 0]

      --assignee [<ASSIGNEE>]
          Filter by assignee (no value = current actor)

      --unassigned
          Show only unassigned issues

  -l, --label <LABEL>
          Filter by label (AND logic, can be repeated)

      --label-any <LABEL_ANY>
          Filter by label (OR logic, can be repeated)

  -t, --type <TYPE>
          Filter by issue type (can be repeated)

  -p, --priority <PRIORITY>
          Filter by priority: 0-4 or P0-P4, ranges like 0-1, comma lists; repeatable

      --sort <SORT>
          Sort policy: hybrid (default), priority, oldest

          Possible values:
          - hybrid:   P0/P1 first by `created_at`, then others by `created_at`
          - priority: Sort by priority ASC, then `created_at` ASC
          - oldest:   Sort by `created_at` ASC only
          
          [default: hybrid]

      --include-deferred
          Include deferred issues

      --parent <PARENT>
          Filter to children of this parent issue ID

  -r, --recursive
          Include all descendants (grandchildren, etc.) with --parent

      --epic <EPIC>
          Scope to an epic: ready issues anywhere beneath the given epic/parent ID (sugar for `--parent <id> --recursive`, depth-unbounded and cycle-safe). Composes with --label/--type/--priority/--limit

      --wrap
          Wrap long lines instead of truncating in text output

      --format <FORMAT>
          Output format (text, json, toon). Env: BR_OUTPUT_FORMAT, TOON_DEFAULT_FORMAT

          Possible values:
          - text: Human-readable text (default)
          - json: JSON output
          - toon: TOON format (token-optimized object notation)

      --stats
          Show token savings stats when using TOON output

      --robot
          Machine-readable output (alias for --json)

      --db <DB>
          Database path (auto-discover .beads/*.db if not set; env: BEADS_DB)

      --actor <ACTOR>
          Actor name for audit trail

      --json
          Output as JSON

      --no-daemon
          Force direct mode (no daemon) - effectively no-op in br v1

      --no-auto-flush
          Skip auto JSONL export

      --no-auto-import
          Skip auto import check

      --allow-stale
          Allow stale DB (bypass freshness check warning)

      --lock-timeout <LOCK_TIMEOUT>
          `SQLite` busy/write-lock timeout in ms

      --no-db
          JSONL-only mode (no DB connection)

  -v, --verbose...
          Increase logging verbosity (-v, -vv)

  -q, --quiet
          Quiet mode (no output except errors)

      --no-color
          Disable colored output

  -h, --help
          Print help (see a summary with '-h')
```

### `br ready -h` — `goldens/usage_help_short_ready.out`

<!-- help-text: ready-short -->
```text
List ready issues (open, unblocked, not deferred)

Usage: br ready [OPTIONS]

Options:
      --limit <LIMIT>                Maximum number of issues to return (0 = unlimited; default: unlimited — the full ready set) [default: 0]
      --assignee [<ASSIGNEE>]        Filter by assignee (no value = current actor)
      --unassigned                   Show only unassigned issues
  -l, --label <LABEL>                Filter by label (AND logic, can be repeated)
      --label-any <LABEL_ANY>        Filter by label (OR logic, can be repeated)
  -t, --type <TYPE>                  Filter by issue type (can be repeated)
  -p, --priority <PRIORITY>          Filter by priority: 0-4 or P0-P4, ranges like 0-1, comma lists; repeatable
      --sort <SORT>                  Sort policy: hybrid (default), priority, oldest [default: hybrid] [possible values: hybrid, priority, oldest]
      --include-deferred             Include deferred issues
      --parent <PARENT>              Filter to children of this parent issue ID
  -r, --recursive                    Include all descendants (grandchildren, etc.) with --parent
      --epic <EPIC>                  Scope to an epic: ready issues anywhere beneath the given epic/parent ID (sugar for `--parent <id> --recursive`, depth-unbounded and cycle-safe). Composes with --label/--type/--priority/--limit
      --wrap                         Wrap long lines instead of truncating in text output
      --format <FORMAT>              Output format (text, json, toon). Env: BR_OUTPUT_FORMAT, TOON_DEFAULT_FORMAT [possible values: text, json, toon]
      --stats                        Show token savings stats when using TOON output
      --robot                        Machine-readable output (alias for --json)
      --db <DB>                      Database path (auto-discover .beads/*.db if not set; env: BEADS_DB)
      --actor <ACTOR>                Actor name for audit trail
      --json                         Output as JSON
      --no-daemon                    Force direct mode (no daemon) - effectively no-op in br v1
      --no-auto-flush                Skip auto JSONL export
      --no-auto-import               Skip auto import check
      --allow-stale                  Allow stale DB (bypass freshness check warning)
      --lock-timeout <LOCK_TIMEOUT>  `SQLite` busy/write-lock timeout in ms
      --no-db                        JSONL-only mode (no DB connection)
  -v, --verbose...                   Increase logging verbosity (-v, -vv)
  -q, --quiet                        Quiet mode (no output except errors)
      --no-color                     Disable colored output
  -h, --help                         Print help (see more with '--help')
```

### `br blocked --help` — `goldens/usage_help_blocked.out`

<!-- help-text: blocked -->
```text
List blocked issues

Usage: br blocked [OPTIONS]

Options:
      --limit <LIMIT>
          Maximum number of issues to return (default: 50, 0 = unlimited)
          
          [default: 50]

      --detailed
          Include full blocker details in text output

      --wrap
          Wrap long lines instead of truncating in text output

  -t, --type <TYPE>
          Filter by issue type (can be repeated)

  -p, --priority <PRIORITY>
          Filter by priority (can be repeated, 0-4)

  -l, --label <LABEL>
          Filter by label (AND logic, can be repeated)

      --format <FORMAT>
          Output format (text, json, toon). Env: BR_OUTPUT_FORMAT, TOON_DEFAULT_FORMAT

          Possible values:
          - text: Human-readable text (default)
          - json: JSON output
          - toon: TOON format (token-optimized object notation)

      --stats
          Show token savings stats when using TOON output

      --robot
          Machine-readable output (alias for --json)

      --db <DB>
          Database path (auto-discover .beads/*.db if not set; env: BEADS_DB)

      --actor <ACTOR>
          Actor name for audit trail

      --json
          Output as JSON

      --no-daemon
          Force direct mode (no daemon) - effectively no-op in br v1

      --no-auto-flush
          Skip auto JSONL export

      --no-auto-import
          Skip auto import check

      --allow-stale
          Allow stale DB (bypass freshness check warning)

      --lock-timeout <LOCK_TIMEOUT>
          `SQLite` busy/write-lock timeout in ms

      --no-db
          JSONL-only mode (no DB connection)

  -v, --verbose...
          Increase logging verbosity (-v, -vv)

  -q, --quiet
          Quiet mode (no output except errors)

      --no-color
          Disable colored output

  -h, --help
          Print help (see a summary with '-h')
```

### `br blocked -h` — `goldens/usage_help_short_blocked.out`

<!-- help-text: blocked-short -->
```text
List blocked issues

Usage: br blocked [OPTIONS]

Options:
      --limit <LIMIT>                Maximum number of issues to return (default: 50, 0 = unlimited) [default: 50]
      --detailed                     Include full blocker details in text output
      --wrap                         Wrap long lines instead of truncating in text output
  -t, --type <TYPE>                  Filter by issue type (can be repeated)
  -p, --priority <PRIORITY>          Filter by priority (can be repeated, 0-4)
  -l, --label <LABEL>                Filter by label (AND logic, can be repeated)
      --format <FORMAT>              Output format (text, json, toon). Env: BR_OUTPUT_FORMAT, TOON_DEFAULT_FORMAT [possible values: text, json, toon]
      --stats                        Show token savings stats when using TOON output
      --robot                        Machine-readable output (alias for --json)
      --db <DB>                      Database path (auto-discover .beads/*.db if not set; env: BEADS_DB)
      --actor <ACTOR>                Actor name for audit trail
      --json                         Output as JSON
      --no-daemon                    Force direct mode (no daemon) - effectively no-op in br v1
      --no-auto-flush                Skip auto JSONL export
      --no-auto-import               Skip auto import check
      --allow-stale                  Allow stale DB (bypass freshness check warning)
      --lock-timeout <LOCK_TIMEOUT>  `SQLite` busy/write-lock timeout in ms
      --no-db                        JSONL-only mode (no DB connection)
  -v, --verbose...                   Increase logging verbosity (-v, -vv)
  -q, --quiet                        Quiet mode (no output except errors)
      --no-color                     Disable colored output
  -h, --help                         Print help (see more with '--help')
```

### `br where --help` — `goldens/usage_help_where.out`

<!-- help-text: where -->
```text
Show the active .beads directory

Usage: br where [OPTIONS]

Options:
      --db <DB>                      Database path (auto-discover .beads/*.db if not set; env: BEADS_DB)
      --actor <ACTOR>                Actor name for audit trail
      --json                         Output as JSON
      --no-daemon                    Force direct mode (no daemon) - effectively no-op in br v1
      --no-auto-flush                Skip auto JSONL export
      --no-auto-import               Skip auto import check
      --allow-stale                  Allow stale DB (bypass freshness check warning)
      --lock-timeout <LOCK_TIMEOUT>  `SQLite` busy/write-lock timeout in ms
      --no-db                        JSONL-only mode (no DB connection)
  -v, --verbose...                   Increase logging verbosity (-v, -vv)
  -q, --quiet                        Quiet mode (no output except errors)
      --no-color                     Disable colored output
  -h, --help                         Print help
```

### `br where -h` — `goldens/usage_help_short_where.out`

<!-- help-text: where-short -->
```text
Show the active .beads directory

Usage: br where [OPTIONS]

Options:
      --db <DB>                      Database path (auto-discover .beads/*.db if not set; env: BEADS_DB)
      --actor <ACTOR>                Actor name for audit trail
      --json                         Output as JSON
      --no-daemon                    Force direct mode (no daemon) - effectively no-op in br v1
      --no-auto-flush                Skip auto JSONL export
      --no-auto-import               Skip auto import check
      --allow-stale                  Allow stale DB (bypass freshness check warning)
      --lock-timeout <LOCK_TIMEOUT>  `SQLite` busy/write-lock timeout in ms
      --no-db                        JSONL-only mode (no DB connection)
  -v, --verbose...                   Increase logging verbosity (-v, -vv)
  -q, --quiet                        Quiet mode (no output except errors)
      --no-color                     Disable colored output
  -h, --help                         Print help
```

### `br version --help` — `goldens/usage_help_version.out`

<!-- help-text: version -->
```text
Show version information

Usage: br version [OPTIONS]

Options:
  -c, --check                        Check if a newer version is available (exit 0=up-to-date, 1=update-available)
  -s, --short                        Output only the version number (for scripts)
      --db <DB>                      Database path (auto-discover .beads/*.db if not set; env: BEADS_DB)
      --actor <ACTOR>                Actor name for audit trail
      --json                         Output as JSON
      --no-daemon                    Force direct mode (no daemon) - effectively no-op in br v1
      --no-auto-flush                Skip auto JSONL export
      --no-auto-import               Skip auto import check
      --allow-stale                  Allow stale DB (bypass freshness check warning)
      --lock-timeout <LOCK_TIMEOUT>  `SQLite` busy/write-lock timeout in ms
      --no-db                        JSONL-only mode (no DB connection)
  -v, --verbose...                   Increase logging verbosity (-v, -vv)
  -q, --quiet                        Quiet mode (no output except errors)
      --no-color                     Disable colored output
  -h, --help                         Print help
```

### `br version -h` — `goldens/usage_help_short_version.out`

<!-- help-text: version-short -->
```text
Show version information

Usage: br version [OPTIONS]

Options:
  -c, --check                        Check if a newer version is available (exit 0=up-to-date, 1=update-available)
  -s, --short                        Output only the version number (for scripts)
      --db <DB>                      Database path (auto-discover .beads/*.db if not set; env: BEADS_DB)
      --actor <ACTOR>                Actor name for audit trail
      --json                         Output as JSON
      --no-daemon                    Force direct mode (no daemon) - effectively no-op in br v1
      --no-auto-flush                Skip auto JSONL export
      --no-auto-import               Skip auto import check
      --allow-stale                  Allow stale DB (bypass freshness check warning)
      --lock-timeout <LOCK_TIMEOUT>  `SQLite` busy/write-lock timeout in ms
      --no-db                        JSONL-only mode (no DB connection)
  -v, --verbose...                   Increase logging verbosity (-v, -vv)
  -q, --quiet                        Quiet mode (no output except errors)
      --no-color                     Disable colored output
  -h, --help                         Print help
```

### `br dep add --help` — `goldens/usage_help_dep_add.out`

<!-- help-text: dep.add -->
```text
Add a dependency: <issue> depends on <depends-on>

Usage: br dep add [OPTIONS] <ISSUE> <DEPENDS_ON>

Arguments:
  <ISSUE>       Issue ID (the one that will depend on something)
  <DEPENDS_ON>  Target issue ID (the one being depended on)

Options:
  -t, --type <DEP_TYPE>              Dependency type (blocks, parent-child, related, etc.) [default: blocks]
      --metadata <METADATA>          Optional JSON metadata
      --db <DB>                      Database path (auto-discover .beads/*.db if not set; env: BEADS_DB)
      --actor <ACTOR>                Actor name for audit trail
      --json                         Output as JSON
      --no-daemon                    Force direct mode (no daemon) - effectively no-op in br v1
      --no-auto-flush                Skip auto JSONL export
      --no-auto-import               Skip auto import check
      --allow-stale                  Allow stale DB (bypass freshness check warning)
      --lock-timeout <LOCK_TIMEOUT>  `SQLite` busy/write-lock timeout in ms
      --no-db                        JSONL-only mode (no DB connection)
  -v, --verbose...                   Increase logging verbosity (-v, -vv)
  -q, --quiet                        Quiet mode (no output except errors)
      --no-color                     Disable colored output
  -h, --help                         Print help
```

### `br dep add -h` — `goldens/usage_help_short_dep_add.out`

<!-- help-text: dep.add-short -->
```text
Add a dependency: <issue> depends on <depends-on>

Usage: br dep add [OPTIONS] <ISSUE> <DEPENDS_ON>

Arguments:
  <ISSUE>       Issue ID (the one that will depend on something)
  <DEPENDS_ON>  Target issue ID (the one being depended on)

Options:
  -t, --type <DEP_TYPE>              Dependency type (blocks, parent-child, related, etc.) [default: blocks]
      --metadata <METADATA>          Optional JSON metadata
      --db <DB>                      Database path (auto-discover .beads/*.db if not set; env: BEADS_DB)
      --actor <ACTOR>                Actor name for audit trail
      --json                         Output as JSON
      --no-daemon                    Force direct mode (no daemon) - effectively no-op in br v1
      --no-auto-flush                Skip auto JSONL export
      --no-auto-import               Skip auto import check
      --allow-stale                  Allow stale DB (bypass freshness check warning)
      --lock-timeout <LOCK_TIMEOUT>  `SQLite` busy/write-lock timeout in ms
      --no-db                        JSONL-only mode (no DB connection)
  -v, --verbose...                   Increase logging verbosity (-v, -vv)
  -q, --quiet                        Quiet mode (no output except errors)
      --no-color                     Disable colored output
  -h, --help                         Print help
```

### `br dep remove --help` — `goldens/usage_help_dep_remove.out`

<!-- help-text: dep.remove -->
```text
Remove a dependency

Usage: br dep remove [OPTIONS] <ISSUE> <DEPENDS_ON>

Arguments:
  <ISSUE>       Issue ID
  <DEPENDS_ON>  Target issue ID to remove dependency to

Options:
  -t, --type <DEP_TYPE>              Dependency type to remove (required when the pair has multiple types)
      --db <DB>                      Database path (auto-discover .beads/*.db if not set; env: BEADS_DB)
      --actor <ACTOR>                Actor name for audit trail
      --json                         Output as JSON
      --no-daemon                    Force direct mode (no daemon) - effectively no-op in br v1
      --no-auto-flush                Skip auto JSONL export
      --no-auto-import               Skip auto import check
      --allow-stale                  Allow stale DB (bypass freshness check warning)
      --lock-timeout <LOCK_TIMEOUT>  `SQLite` busy/write-lock timeout in ms
      --no-db                        JSONL-only mode (no DB connection)
  -v, --verbose...                   Increase logging verbosity (-v, -vv)
  -q, --quiet                        Quiet mode (no output except errors)
      --no-color                     Disable colored output
  -h, --help                         Print help
```

### `br dep remove -h` — `goldens/usage_help_short_dep_remove.out`

<!-- help-text: dep.remove-short -->
```text
Remove a dependency

Usage: br dep remove [OPTIONS] <ISSUE> <DEPENDS_ON>

Arguments:
  <ISSUE>       Issue ID
  <DEPENDS_ON>  Target issue ID to remove dependency to

Options:
  -t, --type <DEP_TYPE>              Dependency type to remove (required when the pair has multiple types)
      --db <DB>                      Database path (auto-discover .beads/*.db if not set; env: BEADS_DB)
      --actor <ACTOR>                Actor name for audit trail
      --json                         Output as JSON
      --no-daemon                    Force direct mode (no daemon) - effectively no-op in br v1
      --no-auto-flush                Skip auto JSONL export
      --no-auto-import               Skip auto import check
      --allow-stale                  Allow stale DB (bypass freshness check warning)
      --lock-timeout <LOCK_TIMEOUT>  `SQLite` busy/write-lock timeout in ms
      --no-db                        JSONL-only mode (no DB connection)
  -v, --verbose...                   Increase logging verbosity (-v, -vv)
  -q, --quiet                        Quiet mode (no output except errors)
      --no-color                     Disable colored output
  -h, --help                         Print help
```

### `br dep list --help` — `goldens/usage_help_dep_list.out`

<!-- help-text: dep.list -->
```text
List dependencies of an issue

Usage: br dep list [OPTIONS] <ISSUE>

Arguments:
  <ISSUE>
          Issue ID

Options:
      --direction <DIRECTION>
          Direction: down (what issue depends on), up (what depends on issue), both

          Possible values:
          - down: Dependencies this issue has (what it waits on)
          - up:   Dependents (what waits on this issue)
          - both: Both directions
          
          [default: down]

  -t, --type <DEP_TYPE>
          Filter by dependency type

      --format <FORMAT>
          Output format (text, json, toon). Env: BR_OUTPUT_FORMAT, TOON_DEFAULT_FORMAT

          Possible values:
          - text: Human-readable text (default)
          - json: JSON output
          - toon: TOON format (token-optimized object notation)

      --stats
          Show token savings stats when using TOON output

      --db <DB>
          Database path (auto-discover .beads/*.db if not set; env: BEADS_DB)

      --actor <ACTOR>
          Actor name for audit trail

      --json
          Output as JSON

      --no-daemon
          Force direct mode (no daemon) - effectively no-op in br v1

      --no-auto-flush
          Skip auto JSONL export

      --no-auto-import
          Skip auto import check

      --allow-stale
          Allow stale DB (bypass freshness check warning)

      --lock-timeout <LOCK_TIMEOUT>
          `SQLite` busy/write-lock timeout in ms

      --no-db
          JSONL-only mode (no DB connection)

  -v, --verbose...
          Increase logging verbosity (-v, -vv)

  -q, --quiet
          Quiet mode (no output except errors)

      --no-color
          Disable colored output

  -h, --help
          Print help (see a summary with '-h')
```

### `br dep list -h` — `goldens/usage_help_short_dep_list.out`

<!-- help-text: dep.list-short -->
```text
List dependencies of an issue

Usage: br dep list [OPTIONS] <ISSUE>

Arguments:
  <ISSUE>  Issue ID

Options:
      --direction <DIRECTION>        Direction: down (what issue depends on), up (what depends on issue), both [default: down] [possible values: down, up, both]
  -t, --type <DEP_TYPE>              Filter by dependency type
      --format <FORMAT>              Output format (text, json, toon). Env: BR_OUTPUT_FORMAT, TOON_DEFAULT_FORMAT [possible values: text, json, toon]
      --stats                        Show token savings stats when using TOON output
      --db <DB>                      Database path (auto-discover .beads/*.db if not set; env: BEADS_DB)
      --actor <ACTOR>                Actor name for audit trail
      --json                         Output as JSON
      --no-daemon                    Force direct mode (no daemon) - effectively no-op in br v1
      --no-auto-flush                Skip auto JSONL export
      --no-auto-import               Skip auto import check
      --allow-stale                  Allow stale DB (bypass freshness check warning)
      --lock-timeout <LOCK_TIMEOUT>  `SQLite` busy/write-lock timeout in ms
      --no-db                        JSONL-only mode (no DB connection)
  -v, --verbose...                   Increase logging verbosity (-v, -vv)
  -q, --quiet                        Quiet mode (no output except errors)
      --no-color                     Disable colored output
  -h, --help                         Print help (see more with '--help')
```

### `br dep tree --help` — `goldens/usage_help_dep_tree.out`

<!-- help-text: dep.tree -->
```text
Show dependency tree rooted at issue

Usage: br dep tree [OPTIONS] <ISSUE>

Arguments:
  <ISSUE>
          Issue ID (root of tree)

Options:
  -d, --direction <DIRECTION>
          Tree direction (default: down)

          Possible values:
          - down: Dependencies this issue has (what it waits on)
          - up:   Dependents (what waits on this issue)
          - both: Both directions
          
          [default: down]

      --max-depth <MAX_DEPTH>
          Maximum depth (default: 10)
          
          [default: 10]

      --format <FORMAT>
          Output format: text, mermaid
          
          [default: text]

      --db <DB>
          Database path (auto-discover .beads/*.db if not set; env: BEADS_DB)

      --actor <ACTOR>
          Actor name for audit trail

      --json
          Output as JSON

      --no-daemon
          Force direct mode (no daemon) - effectively no-op in br v1

      --no-auto-flush
          Skip auto JSONL export

      --no-auto-import
          Skip auto import check

      --allow-stale
          Allow stale DB (bypass freshness check warning)

      --lock-timeout <LOCK_TIMEOUT>
          `SQLite` busy/write-lock timeout in ms

      --no-db
          JSONL-only mode (no DB connection)

  -v, --verbose...
          Increase logging verbosity (-v, -vv)

  -q, --quiet
          Quiet mode (no output except errors)

      --no-color
          Disable colored output

  -h, --help
          Print help (see a summary with '-h')
```

### `br dep tree -h` — `goldens/usage_help_short_dep_tree.out`

<!-- help-text: dep.tree-short -->
```text
Show dependency tree rooted at issue

Usage: br dep tree [OPTIONS] <ISSUE>

Arguments:
  <ISSUE>  Issue ID (root of tree)

Options:
  -d, --direction <DIRECTION>        Tree direction (default: down) [default: down] [possible values: down, up, both]
      --max-depth <MAX_DEPTH>        Maximum depth (default: 10) [default: 10]
      --format <FORMAT>              Output format: text, mermaid [default: text]
      --db <DB>                      Database path (auto-discover .beads/*.db if not set; env: BEADS_DB)
      --actor <ACTOR>                Actor name for audit trail
      --json                         Output as JSON
      --no-daemon                    Force direct mode (no daemon) - effectively no-op in br v1
      --no-auto-flush                Skip auto JSONL export
      --no-auto-import               Skip auto import check
      --allow-stale                  Allow stale DB (bypass freshness check warning)
      --lock-timeout <LOCK_TIMEOUT>  `SQLite` busy/write-lock timeout in ms
      --no-db                        JSONL-only mode (no DB connection)
  -v, --verbose...                   Increase logging verbosity (-v, -vv)
  -q, --quiet                        Quiet mode (no output except errors)
      --no-color                     Disable colored output
  -h, --help                         Print help (see more with '--help')
```

### `br dep cycles --help` — `goldens/usage_help_dep_cycles.out`

<!-- help-text: dep.cycles -->
```text
Detect and report dependency cycles

Usage: br dep cycles [OPTIONS]

Options:
      --blocking-only                Only check blocking dependency types
      --include-closed               Include archived cycles where every issue is closed or tombstoned
      --db <DB>                      Database path (auto-discover .beads/*.db if not set; env: BEADS_DB)
      --actor <ACTOR>                Actor name for audit trail
      --json                         Output as JSON
      --no-daemon                    Force direct mode (no daemon) - effectively no-op in br v1
      --no-auto-flush                Skip auto JSONL export
      --no-auto-import               Skip auto import check
      --allow-stale                  Allow stale DB (bypass freshness check warning)
      --lock-timeout <LOCK_TIMEOUT>  `SQLite` busy/write-lock timeout in ms
      --no-db                        JSONL-only mode (no DB connection)
  -v, --verbose...                   Increase logging verbosity (-v, -vv)
  -q, --quiet                        Quiet mode (no output except errors)
      --no-color                     Disable colored output
  -h, --help                         Print help
```

### `br dep cycles -h` — `goldens/usage_help_short_dep_cycles.out`

<!-- help-text: dep.cycles-short -->
```text
Detect and report dependency cycles

Usage: br dep cycles [OPTIONS]

Options:
      --blocking-only                Only check blocking dependency types
      --include-closed               Include archived cycles where every issue is closed or tombstoned
      --db <DB>                      Database path (auto-discover .beads/*.db if not set; env: BEADS_DB)
      --actor <ACTOR>                Actor name for audit trail
      --json                         Output as JSON
      --no-daemon                    Force direct mode (no daemon) - effectively no-op in br v1
      --no-auto-flush                Skip auto JSONL export
      --no-auto-import               Skip auto import check
      --allow-stale                  Allow stale DB (bypass freshness check warning)
      --lock-timeout <LOCK_TIMEOUT>  `SQLite` busy/write-lock timeout in ms
      --no-db                        JSONL-only mode (no DB connection)
  -v, --verbose...                   Increase logging verbosity (-v, -vv)
  -q, --quiet                        Quiet mode (no output except errors)
      --no-color                     Disable colored output
  -h, --help                         Print help
```

### `br label add --help` — `goldens/usage_help_label_add.out`

<!-- help-text: label.add -->
```text
Add label(s) to issue(s)

Usage: br label add [OPTIONS] [ISSUES]...

Arguments:
  [ISSUES]...  Issue ID(s) to add label to; positional labels may follow the IDs

Options:
  -l, --label <LABEL>                Label(s) to add (repeatable or comma-separated)
      --db <DB>                      Database path (auto-discover .beads/*.db if not set; env: BEADS_DB)
      --actor <ACTOR>                Actor name for audit trail
      --json                         Output as JSON
      --no-daemon                    Force direct mode (no daemon) - effectively no-op in br v1
      --no-auto-flush                Skip auto JSONL export
      --no-auto-import               Skip auto import check
      --allow-stale                  Allow stale DB (bypass freshness check warning)
      --lock-timeout <LOCK_TIMEOUT>  `SQLite` busy/write-lock timeout in ms
      --no-db                        JSONL-only mode (no DB connection)
  -v, --verbose...                   Increase logging verbosity (-v, -vv)
  -q, --quiet                        Quiet mode (no output except errors)
      --no-color                     Disable colored output
  -h, --help                         Print help
```

### `br label add -h` — `goldens/usage_help_short_label_add.out`

<!-- help-text: label.add-short -->
```text
Add label(s) to issue(s)

Usage: br label add [OPTIONS] [ISSUES]...

Arguments:
  [ISSUES]...  Issue ID(s) to add label to; positional labels may follow the IDs

Options:
  -l, --label <LABEL>                Label(s) to add (repeatable or comma-separated)
      --db <DB>                      Database path (auto-discover .beads/*.db if not set; env: BEADS_DB)
      --actor <ACTOR>                Actor name for audit trail
      --json                         Output as JSON
      --no-daemon                    Force direct mode (no daemon) - effectively no-op in br v1
      --no-auto-flush                Skip auto JSONL export
      --no-auto-import               Skip auto import check
      --allow-stale                  Allow stale DB (bypass freshness check warning)
      --lock-timeout <LOCK_TIMEOUT>  `SQLite` busy/write-lock timeout in ms
      --no-db                        JSONL-only mode (no DB connection)
  -v, --verbose...                   Increase logging verbosity (-v, -vv)
  -q, --quiet                        Quiet mode (no output except errors)
      --no-color                     Disable colored output
  -h, --help                         Print help
```

### `br label remove --help` — `goldens/usage_help_label_remove.out`

<!-- help-text: label.remove -->
```text
Remove label(s) from issue(s)

Usage: br label remove [OPTIONS] [ISSUES]...

Arguments:
  [ISSUES]...  Issue ID(s) to remove label from; positional labels may follow the IDs

Options:
  -l, --label <LABEL>                Label(s) to remove (repeatable or comma-separated)
      --db <DB>                      Database path (auto-discover .beads/*.db if not set; env: BEADS_DB)
      --actor <ACTOR>                Actor name for audit trail
      --json                         Output as JSON
      --no-daemon                    Force direct mode (no daemon) - effectively no-op in br v1
      --no-auto-flush                Skip auto JSONL export
      --no-auto-import               Skip auto import check
      --allow-stale                  Allow stale DB (bypass freshness check warning)
      --lock-timeout <LOCK_TIMEOUT>  `SQLite` busy/write-lock timeout in ms
      --no-db                        JSONL-only mode (no DB connection)
  -v, --verbose...                   Increase logging verbosity (-v, -vv)
  -q, --quiet                        Quiet mode (no output except errors)
      --no-color                     Disable colored output
  -h, --help                         Print help
```

### `br label remove -h` — `goldens/usage_help_short_label_remove.out`

<!-- help-text: label.remove-short -->
```text
Remove label(s) from issue(s)

Usage: br label remove [OPTIONS] [ISSUES]...

Arguments:
  [ISSUES]...  Issue ID(s) to remove label from; positional labels may follow the IDs

Options:
  -l, --label <LABEL>                Label(s) to remove (repeatable or comma-separated)
      --db <DB>                      Database path (auto-discover .beads/*.db if not set; env: BEADS_DB)
      --actor <ACTOR>                Actor name for audit trail
      --json                         Output as JSON
      --no-daemon                    Force direct mode (no daemon) - effectively no-op in br v1
      --no-auto-flush                Skip auto JSONL export
      --no-auto-import               Skip auto import check
      --allow-stale                  Allow stale DB (bypass freshness check warning)
      --lock-timeout <LOCK_TIMEOUT>  `SQLite` busy/write-lock timeout in ms
      --no-db                        JSONL-only mode (no DB connection)
  -v, --verbose...                   Increase logging verbosity (-v, -vv)
  -q, --quiet                        Quiet mode (no output except errors)
      --no-color                     Disable colored output
  -h, --help                         Print help
```

### `br label list --help` — `goldens/usage_help_label_list.out`

<!-- help-text: label.list -->
```text
List labels for an issue or all unique labels

Usage: br label list [OPTIONS] [ISSUE]

Arguments:
  [ISSUE]  Issue ID (optional - if omitted, lists all unique labels)

Options:
      --db <DB>                      Database path (auto-discover .beads/*.db if not set; env: BEADS_DB)
      --actor <ACTOR>                Actor name for audit trail
      --json                         Output as JSON
      --no-daemon                    Force direct mode (no daemon) - effectively no-op in br v1
      --no-auto-flush                Skip auto JSONL export
      --no-auto-import               Skip auto import check
      --allow-stale                  Allow stale DB (bypass freshness check warning)
      --lock-timeout <LOCK_TIMEOUT>  `SQLite` busy/write-lock timeout in ms
      --no-db                        JSONL-only mode (no DB connection)
  -v, --verbose...                   Increase logging verbosity (-v, -vv)
  -q, --quiet                        Quiet mode (no output except errors)
      --no-color                     Disable colored output
  -h, --help                         Print help
```

### `br label list -h` — `goldens/usage_help_short_label_list.out`

<!-- help-text: label.list-short -->
```text
List labels for an issue or all unique labels

Usage: br label list [OPTIONS] [ISSUE]

Arguments:
  [ISSUE]  Issue ID (optional - if omitted, lists all unique labels)

Options:
      --db <DB>                      Database path (auto-discover .beads/*.db if not set; env: BEADS_DB)
      --actor <ACTOR>                Actor name for audit trail
      --json                         Output as JSON
      --no-daemon                    Force direct mode (no daemon) - effectively no-op in br v1
      --no-auto-flush                Skip auto JSONL export
      --no-auto-import               Skip auto import check
      --allow-stale                  Allow stale DB (bypass freshness check warning)
      --lock-timeout <LOCK_TIMEOUT>  `SQLite` busy/write-lock timeout in ms
      --no-db                        JSONL-only mode (no DB connection)
  -v, --verbose...                   Increase logging verbosity (-v, -vv)
  -q, --quiet                        Quiet mode (no output except errors)
      --no-color                     Disable colored output
  -h, --help                         Print help
```

### `br label list-all --help` — `goldens/usage_help_label_list_all.out`

<!-- help-text: label.list-all -->
```text
List all unique labels with counts

Usage: br label list-all [OPTIONS]

Options:
      --db <DB>                      Database path (auto-discover .beads/*.db if not set; env: BEADS_DB)
      --actor <ACTOR>                Actor name for audit trail
      --json                         Output as JSON
      --no-daemon                    Force direct mode (no daemon) - effectively no-op in br v1
      --no-auto-flush                Skip auto JSONL export
      --no-auto-import               Skip auto import check
      --allow-stale                  Allow stale DB (bypass freshness check warning)
      --lock-timeout <LOCK_TIMEOUT>  `SQLite` busy/write-lock timeout in ms
      --no-db                        JSONL-only mode (no DB connection)
  -v, --verbose...                   Increase logging verbosity (-v, -vv)
  -q, --quiet                        Quiet mode (no output except errors)
      --no-color                     Disable colored output
  -h, --help                         Print help
```

### `br label list-all -h` — `goldens/usage_help_short_label_list_all.out`

<!-- help-text: label.list-all-short -->
```text
List all unique labels with counts

Usage: br label list-all [OPTIONS]

Options:
      --db <DB>                      Database path (auto-discover .beads/*.db if not set; env: BEADS_DB)
      --actor <ACTOR>                Actor name for audit trail
      --json                         Output as JSON
      --no-daemon                    Force direct mode (no daemon) - effectively no-op in br v1
      --no-auto-flush                Skip auto JSONL export
      --no-auto-import               Skip auto import check
      --allow-stale                  Allow stale DB (bypass freshness check warning)
      --lock-timeout <LOCK_TIMEOUT>  `SQLite` busy/write-lock timeout in ms
      --no-db                        JSONL-only mode (no DB connection)
  -v, --verbose...                   Increase logging verbosity (-v, -vv)
  -q, --quiet                        Quiet mode (no output except errors)
      --no-color                     Disable colored output
  -h, --help                         Print help
```

### `br label rename --help` — `goldens/usage_help_label_rename.out`

<!-- help-text: label.rename -->
```text
Rename a label across all issues

Usage: br label rename [OPTIONS] <OLD_NAME> <NEW_NAME>

Arguments:
  <OLD_NAME>  Current label name
  <NEW_NAME>  New label name

Options:
      --db <DB>                      Database path (auto-discover .beads/*.db if not set; env: BEADS_DB)
      --actor <ACTOR>                Actor name for audit trail
      --json                         Output as JSON
      --no-daemon                    Force direct mode (no daemon) - effectively no-op in br v1
      --no-auto-flush                Skip auto JSONL export
      --no-auto-import               Skip auto import check
      --allow-stale                  Allow stale DB (bypass freshness check warning)
      --lock-timeout <LOCK_TIMEOUT>  `SQLite` busy/write-lock timeout in ms
      --no-db                        JSONL-only mode (no DB connection)
  -v, --verbose...                   Increase logging verbosity (-v, -vv)
  -q, --quiet                        Quiet mode (no output except errors)
      --no-color                     Disable colored output
  -h, --help                         Print help
```

### `br label rename -h` — `goldens/usage_help_short_label_rename.out`

<!-- help-text: label.rename-short -->
```text
Rename a label across all issues

Usage: br label rename [OPTIONS] <OLD_NAME> <NEW_NAME>

Arguments:
  <OLD_NAME>  Current label name
  <NEW_NAME>  New label name

Options:
      --db <DB>                      Database path (auto-discover .beads/*.db if not set; env: BEADS_DB)
      --actor <ACTOR>                Actor name for audit trail
      --json                         Output as JSON
      --no-daemon                    Force direct mode (no daemon) - effectively no-op in br v1
      --no-auto-flush                Skip auto JSONL export
      --no-auto-import               Skip auto import check
      --allow-stale                  Allow stale DB (bypass freshness check warning)
      --lock-timeout <LOCK_TIMEOUT>  `SQLite` busy/write-lock timeout in ms
      --no-db                        JSONL-only mode (no DB connection)
  -v, --verbose...                   Increase logging verbosity (-v, -vv)
  -q, --quiet                        Quiet mode (no output except errors)
      --no-color                     Disable colored output
  -h, --help                         Print help
```

### `br comments --help` — `goldens/usage_help_comments.out`

<!-- help-text: comments -->
```text
Manage comments

Usage: br comments [OPTIONS] [ID] [COMMAND]

Commands:
  add   
  list  
  help  Print this message or the help of the given subcommand(s)

Arguments:
  [ID]  Issue ID (for listing comments)

Options:
      --wrap                         Wrap long lines instead of truncating in text output
      --db <DB>                      Database path (auto-discover .beads/*.db if not set; env: BEADS_DB)
      --actor <ACTOR>                Actor name for audit trail
      --json                         Output as JSON
      --no-daemon                    Force direct mode (no daemon) - effectively no-op in br v1
      --no-auto-flush                Skip auto JSONL export
      --no-auto-import               Skip auto import check
      --allow-stale                  Allow stale DB (bypass freshness check warning)
      --lock-timeout <LOCK_TIMEOUT>  `SQLite` busy/write-lock timeout in ms
      --no-db                        JSONL-only mode (no DB connection)
  -v, --verbose...                   Increase logging verbosity (-v, -vv)
  -q, --quiet                        Quiet mode (no output except errors)
      --no-color                     Disable colored output
  -h, --help                         Print help
```

### `br comments -h` — `goldens/usage_help_short_comments.out`

<!-- help-text: comments-short -->
```text
Manage comments

Usage: br comments [OPTIONS] [ID] [COMMAND]

Commands:
  add   
  list  
  help  Print this message or the help of the given subcommand(s)

Arguments:
  [ID]  Issue ID (for listing comments)

Options:
      --wrap                         Wrap long lines instead of truncating in text output
      --db <DB>                      Database path (auto-discover .beads/*.db if not set; env: BEADS_DB)
      --actor <ACTOR>                Actor name for audit trail
      --json                         Output as JSON
      --no-daemon                    Force direct mode (no daemon) - effectively no-op in br v1
      --no-auto-flush                Skip auto JSONL export
      --no-auto-import               Skip auto import check
      --allow-stale                  Allow stale DB (bypass freshness check warning)
      --lock-timeout <LOCK_TIMEOUT>  `SQLite` busy/write-lock timeout in ms
      --no-db                        JSONL-only mode (no DB connection)
  -v, --verbose...                   Increase logging verbosity (-v, -vv)
  -q, --quiet                        Quiet mode (no output except errors)
      --no-color                     Disable colored output
  -h, --help                         Print help
```

### `br comments add --help` — `goldens/usage_help_comments_add.out`

<!-- help-text: comments.add -->
```text
Usage: br comments add [OPTIONS] <ID> [TEXT]...

Arguments:
  <ID>       Issue ID
  [TEXT]...  Comment text

Options:
  -f, --file <FILE>                  Read comment text from file
      --author <AUTHOR>              Override author (defaults to actor/env/user)
  -m, --message <MESSAGE>            Comment text (alternative flag) [alias: --content]
      --db <DB>                      Database path (auto-discover .beads/*.db if not set; env: BEADS_DB)
      --actor <ACTOR>                Actor name for audit trail
      --json                         Output as JSON
      --no-daemon                    Force direct mode (no daemon) - effectively no-op in br v1
      --no-auto-flush                Skip auto JSONL export
      --no-auto-import               Skip auto import check
      --allow-stale                  Allow stale DB (bypass freshness check warning)
      --lock-timeout <LOCK_TIMEOUT>  `SQLite` busy/write-lock timeout in ms
      --no-db                        JSONL-only mode (no DB connection)
  -v, --verbose...                   Increase logging verbosity (-v, -vv)
  -q, --quiet                        Quiet mode (no output except errors)
      --no-color                     Disable colored output
  -h, --help                         Print help
```

### `br comments add -h` — `goldens/usage_help_short_comments_add.out`

<!-- help-text: comments.add-short -->
```text
Usage: br comments add [OPTIONS] <ID> [TEXT]...

Arguments:
  <ID>       Issue ID
  [TEXT]...  Comment text

Options:
  -f, --file <FILE>                  Read comment text from file
      --author <AUTHOR>              Override author (defaults to actor/env/user)
  -m, --message <MESSAGE>            Comment text (alternative flag) [alias: --content]
      --db <DB>                      Database path (auto-discover .beads/*.db if not set; env: BEADS_DB)
      --actor <ACTOR>                Actor name for audit trail
      --json                         Output as JSON
      --no-daemon                    Force direct mode (no daemon) - effectively no-op in br v1
      --no-auto-flush                Skip auto JSONL export
      --no-auto-import               Skip auto import check
      --allow-stale                  Allow stale DB (bypass freshness check warning)
      --lock-timeout <LOCK_TIMEOUT>  `SQLite` busy/write-lock timeout in ms
      --no-db                        JSONL-only mode (no DB connection)
  -v, --verbose...                   Increase logging verbosity (-v, -vv)
  -q, --quiet                        Quiet mode (no output except errors)
      --no-color                     Disable colored output
  -h, --help                         Print help
```

### `br comments list --help` — `goldens/usage_help_comments_list.out`

<!-- help-text: comments.list -->
```text
Usage: br comments list [OPTIONS] <ID>

Arguments:
  <ID>  Issue ID

Options:
      --wrap                         Wrap long lines instead of truncating in text output
      --db <DB>                      Database path (auto-discover .beads/*.db if not set; env: BEADS_DB)
      --actor <ACTOR>                Actor name for audit trail
      --json                         Output as JSON
      --no-daemon                    Force direct mode (no daemon) - effectively no-op in br v1
      --no-auto-flush                Skip auto JSONL export
      --no-auto-import               Skip auto import check
      --allow-stale                  Allow stale DB (bypass freshness check warning)
      --lock-timeout <LOCK_TIMEOUT>  `SQLite` busy/write-lock timeout in ms
      --no-db                        JSONL-only mode (no DB connection)
  -v, --verbose...                   Increase logging verbosity (-v, -vv)
  -q, --quiet                        Quiet mode (no output except errors)
      --no-color                     Disable colored output
  -h, --help                         Print help
```

### `br comments list -h` — `goldens/usage_help_short_comments_list.out`

<!-- help-text: comments.list-short -->
```text
Usage: br comments list [OPTIONS] <ID>

Arguments:
  <ID>  Issue ID

Options:
      --wrap                         Wrap long lines instead of truncating in text output
      --db <DB>                      Database path (auto-discover .beads/*.db if not set; env: BEADS_DB)
      --actor <ACTOR>                Actor name for audit trail
      --json                         Output as JSON
      --no-daemon                    Force direct mode (no daemon) - effectively no-op in br v1
      --no-auto-flush                Skip auto JSONL export
      --no-auto-import               Skip auto import check
      --allow-stale                  Allow stale DB (bypass freshness check warning)
      --lock-timeout <LOCK_TIMEOUT>  `SQLite` busy/write-lock timeout in ms
      --no-db                        JSONL-only mode (no DB connection)
  -v, --verbose...                   Increase logging verbosity (-v, -vv)
  -q, --quiet                        Quiet mode (no output except errors)
      --no-color                     Disable colored output
  -h, --help                         Print help
```

### `br epic status --help` — `goldens/usage_help_epic_status.out`

<!-- help-text: epic.status -->
```text
Show status of all epics (progress, eligibility)

Usage: br epic status [OPTIONS]

Options:
      --eligible-only                Only show epics eligible for closure
      --db <DB>                      Database path (auto-discover .beads/*.db if not set; env: BEADS_DB)
      --actor <ACTOR>                Actor name for audit trail
      --json                         Output as JSON
      --no-daemon                    Force direct mode (no daemon) - effectively no-op in br v1
      --no-auto-flush                Skip auto JSONL export
      --no-auto-import               Skip auto import check
      --allow-stale                  Allow stale DB (bypass freshness check warning)
      --lock-timeout <LOCK_TIMEOUT>  `SQLite` busy/write-lock timeout in ms
      --no-db                        JSONL-only mode (no DB connection)
  -v, --verbose...                   Increase logging verbosity (-v, -vv)
  -q, --quiet                        Quiet mode (no output except errors)
      --no-color                     Disable colored output
  -h, --help                         Print help
```

### `br epic status -h` — `goldens/usage_help_short_epic_status.out`

<!-- help-text: epic.status-short -->
```text
Show status of all epics (progress, eligibility)

Usage: br epic status [OPTIONS]

Options:
      --eligible-only                Only show epics eligible for closure
      --db <DB>                      Database path (auto-discover .beads/*.db if not set; env: BEADS_DB)
      --actor <ACTOR>                Actor name for audit trail
      --json                         Output as JSON
      --no-daemon                    Force direct mode (no daemon) - effectively no-op in br v1
      --no-auto-flush                Skip auto JSONL export
      --no-auto-import               Skip auto import check
      --allow-stale                  Allow stale DB (bypass freshness check warning)
      --lock-timeout <LOCK_TIMEOUT>  `SQLite` busy/write-lock timeout in ms
      --no-db                        JSONL-only mode (no DB connection)
  -v, --verbose...                   Increase logging verbosity (-v, -vv)
  -q, --quiet                        Quiet mode (no output except errors)
      --no-color                     Disable colored output
  -h, --help                         Print help
```

### `br epic close-eligible --help` — `goldens/usage_help_epic_close_eligible.out`

<!-- help-text: epic.close-eligible -->
```text
Close epics that are eligible (all children closed)

Usage: br epic close-eligible [OPTIONS]

Options:
      --dry-run                       Preview only, no changes
      --transition-comment <COMMENT>  New comment committed atomically with every eligible epic close
      --db <DB>                       Database path (auto-discover .beads/*.db if not set; env: BEADS_DB)
      --actor <ACTOR>                 Actor name for audit trail
      --json                          Output as JSON
      --no-daemon                     Force direct mode (no daemon) - effectively no-op in br v1
      --no-auto-flush                 Skip auto JSONL export
      --no-auto-import                Skip auto import check
      --allow-stale                   Allow stale DB (bypass freshness check warning)
      --lock-timeout <LOCK_TIMEOUT>   `SQLite` busy/write-lock timeout in ms
      --no-db                         JSONL-only mode (no DB connection)
  -v, --verbose...                    Increase logging verbosity (-v, -vv)
  -q, --quiet                         Quiet mode (no output except errors)
      --no-color                      Disable colored output
  -h, --help                          Print help
```

### `br epic close-eligible -h` — `goldens/usage_help_short_epic_close_eligible.out`

<!-- help-text: epic.close-eligible-short -->
```text
Close epics that are eligible (all children closed)

Usage: br epic close-eligible [OPTIONS]

Options:
      --dry-run                       Preview only, no changes
      --transition-comment <COMMENT>  New comment committed atomically with every eligible epic close
      --db <DB>                       Database path (auto-discover .beads/*.db if not set; env: BEADS_DB)
      --actor <ACTOR>                 Actor name for audit trail
      --json                          Output as JSON
      --no-daemon                     Force direct mode (no daemon) - effectively no-op in br v1
      --no-auto-flush                 Skip auto JSONL export
      --no-auto-import                Skip auto import check
      --allow-stale                   Allow stale DB (bypass freshness check warning)
      --lock-timeout <LOCK_TIMEOUT>   `SQLite` busy/write-lock timeout in ms
      --no-db                         JSONL-only mode (no DB connection)
  -v, --verbose...                    Increase logging verbosity (-v, -vv)
  -q, --quiet                         Quiet mode (no output except errors)
      --no-color                      Disable colored output
  -h, --help                          Print help
```

### `br dep -h` — `goldens/usage_help_short_dep.out`

<!-- help-text: dep-short -->
```text
Manage dependencies

Usage: br dep [OPTIONS] <COMMAND>

Commands:
  add     Add a dependency: <issue> depends on <depends-on>
  import  Bulk import dependency edges from JSONL
  remove  Remove a dependency [alias: rm]
  list    List dependencies of an issue
  tree    Show dependency tree rooted at issue
  cycles  Detect and report dependency cycles
  help    Print this message or the help of the given subcommand(s)

Options:
      --db <DB>                      Database path (auto-discover .beads/*.db if not set; env: BEADS_DB)
      --actor <ACTOR>                Actor name for audit trail
      --json                         Output as JSON
      --no-daemon                    Force direct mode (no daemon) - effectively no-op in br v1
      --no-auto-flush                Skip auto JSONL export
      --no-auto-import               Skip auto import check
      --allow-stale                  Allow stale DB (bypass freshness check warning)
      --lock-timeout <LOCK_TIMEOUT>  `SQLite` busy/write-lock timeout in ms
      --no-db                        JSONL-only mode (no DB connection)
  -v, --verbose...                   Increase logging verbosity (-v, -vv)
  -q, --quiet                        Quiet mode (no output except errors)
      --no-color                     Disable colored output
  -h, --help                         Print help
```

### `br label -h` — `goldens/usage_help_short_label.out`

<!-- help-text: label-short -->
```text
Manage labels

Usage: br label [OPTIONS] <COMMAND>

Commands:
  add       Add label(s) to issue(s)
  remove    Remove label(s) from issue(s)
  list      List labels for an issue or all unique labels
  list-all  List all unique labels with counts
  rename    Rename a label across all issues
  help      Print this message or the help of the given subcommand(s)

Options:
      --db <DB>                      Database path (auto-discover .beads/*.db if not set; env: BEADS_DB)
      --actor <ACTOR>                Actor name for audit trail
      --json                         Output as JSON
      --no-daemon                    Force direct mode (no daemon) - effectively no-op in br v1
      --no-auto-flush                Skip auto JSONL export
      --no-auto-import               Skip auto import check
      --allow-stale                  Allow stale DB (bypass freshness check warning)
      --lock-timeout <LOCK_TIMEOUT>  `SQLite` busy/write-lock timeout in ms
      --no-db                        JSONL-only mode (no DB connection)
  -v, --verbose...                   Increase logging verbosity (-v, -vv)
  -q, --quiet                        Quiet mode (no output except errors)
      --no-color                     Disable colored output
  -h, --help                         Print help
```

### `br epic -h` — `goldens/usage_help_short_epic.out`

<!-- help-text: epic-short -->
```text
Epic management commands

Usage: br epic [OPTIONS] <COMMAND>

Commands:
  status          Show status of all epics (progress, eligibility)
  close-eligible  Close epics that are eligible (all children closed)
  help            Print this message or the help of the given subcommand(s)

Options:
      --db <DB>                      Database path (auto-discover .beads/*.db if not set; env: BEADS_DB)
      --actor <ACTOR>                Actor name for audit trail
      --json                         Output as JSON
      --no-daemon                    Force direct mode (no daemon) - effectively no-op in br v1
      --no-auto-flush                Skip auto JSONL export
      --no-auto-import               Skip auto import check
      --allow-stale                  Allow stale DB (bypass freshness check warning)
      --lock-timeout <LOCK_TIMEOUT>  `SQLite` busy/write-lock timeout in ms
      --no-db                        JSONL-only mode (no DB connection)
  -v, --verbose...                   Increase logging verbosity (-v, -vv)
  -q, --quiet                        Quiet mode (no output except errors)
      --no-color                     Disable colored output
  -h, --help                         Print help
```

### `br -h` — `goldens/usage_help_short_top.out`

<!-- help-text: top-short -->
```text
Agent-first issue tracker (SQLite + JSONL)

Usage: br [OPTIONS] <COMMAND>

Commands:
  agents        Manage AGENTS.md workflow instructions
  audit         Record and label agent interactions (append-only JSONL)
  blocked       List blocked issues
  capabilities  Describe br's machine-readable contracts and safety guarantees
  capacity      Workflow capacity management: audited issue-specific exemptions (GitHub #384)
  changelog     Generate changelog from closed issues
  close         Close an issue
  comments      Manage comments
  completions   Generate shell completions
  config        Configuration management
  coordination  Diagnose swarm coordination state without mutating claims
  count         Count issues with optional grouping
  create        Create a new issue
  defer         Defer issues (schedule for later)
  delete        Delete an issue (creates tombstone)
  dep           Manage dependencies
  doctor        Run diagnostics and optionally repair issues
  epic          Epic management commands
  gate          Workflow gate engine: record and inspect gate results (issue #312)
  graph         Visualize the dependents graph: what an issue unblocks
  history       Manage local history backups
  info          Show diagnostic metadata about the workspace
  init          Initialize a beads workspace
  label         Manage labels
  lint          Check issues for missing template sections
  list          List issues
  orphans       List orphan issues (referenced in commits but open)
  q             Quick capture (create issue, print ID only)
  query         Manage saved queries
  ready         List ready issues (open, unblocked, not deferred)
  reopen        Reopen an issue
  robot-docs    Print concise in-tool docs for automation agents
  scheduler     Rank ready work for agent swarms with explainable evidence
  schema        Emit JSON Schemas and per-command output envelope shapes (for agent/tooling integration)
  search        Search issues (matches title, description, id, and comment text)
  show          Show issue details
  stale         List stale issues
  stats         Show project statistics
  status        Alias for stats
  sync          Sync database with JSONL file (export or import)
  undefer       Undefer issues (make ready again)
  update        Update an issue
  vcs-status    Explicitly inspect Git visibility for the configured JSONL export
  upgrade       Upgrade br to the latest version
  version       Show version information
  where         Show the active .beads directory
  help          Print this message or the help of the given subcommand(s)

Options:
      --db <DB>                      Database path (auto-discover .beads/*.db if not set; env: BEADS_DB)
      --actor <ACTOR>                Actor name for audit trail
      --json                         Output as JSON
      --no-daemon                    Force direct mode (no daemon) - effectively no-op in br v1
      --no-auto-flush                Skip auto JSONL export
      --no-auto-import               Skip auto import check
      --allow-stale                  Allow stale DB (bypass freshness check warning)
      --lock-timeout <LOCK_TIMEOUT>  `SQLite` busy/write-lock timeout in ms
      --no-db                        JSONL-only mode (no DB connection)
  -v, --verbose...                   Increase logging verbosity (-v, -vv)
  -q, --quiet                        Quiet mode (no output except errors)
      --no-color                     Disable colored output
  -h, --help                         Print help
  -V, --version                      Print version
```
