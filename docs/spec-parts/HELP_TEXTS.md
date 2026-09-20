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
