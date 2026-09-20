# Feature parity — the Bend 2 port of BEADS_RUST

<!-- Generated from the spec's in-scope rows and kept current by hand after
     every gate run. `scripts/parity-board.sh docs/FEATURE_PARITY.md`
     computes the verdict: FULL, PARTIAL, DEBT (exclusions exist) or
     MALFORMED (a "present" row with neither a golden nor a law). Rules:
     partial never rounds up; excluded is debt; a present feature names
     its evidence. Statuses: present | partial | missing | excluded | n/a. -->

Last gate run: 2026-09-20 · lanes: `scripts/lanes.sh` → `FAIL` (interpreter, c-1t, c-8t, js: 1 of 235 on each; the program under test is the scaffold template; gpu MISSING: no device, no bang) ·
proofs: `$BEND_CLI port/PROOF.bend` → `All terms check.` with 0 unsafe (the scaffold's law; bend 2.0.20) · board: `PARTIAL` (every in-scope row `missing`: Phase 3 has not begun).

| feature | original ref | port def | goldens | laws | status | notes |
|---|---|---|---|---|---|---|
| argv grammar, usage and parse errors | S1.1–S1.67 | `Cli.parse` | `usage_none`, `usage_unknown_cmd`, `usage_unknown_flag`, `usage_empty_arg`, `usage_json_twice`, `usage_limit_noval`, `usage_limit_bad`, `usage_unexpected_flag`, `usage_dep_alone`, `usage_label_alone`, `usage_epic_alone`, `usage_search_alone`, `usage_show_alone`, `usage_close_alone`, `usage_update_alone`, `usage_delete_alone`, `usage_dep_add_one_arg` | none | missing | not started: Phase 3 |
| workspace discovery, `where` | S2.1–S2.23, S5.200–S5.201 | `Discover.decide`, `Shell.probe`, `Render.plain_where` | `error_no_workspace_list`, `error_no_workspace_list_json`, `error_no_workspace_create`, `where_plain`, `where_json` | none | missing | not started: Phase 3 |
| `version` | S5.202, OQ-003 | `Render.plain_version` | `version_plain`, `version_json` | none | missing | not started: Phase 3 |
| JSONL load, normalization, refusals | S2.24–S2.42, S9.26–S9.37 | `Json.parse`, `Model.of_json`, `Store.load` | `empty_list`, `empty_list_json`, `empty_ready`, `empty_ready_json`, `empty_blocked`, `empty_blocked_json`, `empty_stats`, `empty_stats_json`, `empty_count`, `empty_search`, `empty_dep_cycles`, `edge_precision_list_json`, `edge_precision_show_json`, `error_conflict_markers`, `error_conflict_markers_json`, `error_malformed_jsonl`, `error_malformed_jsonl_json` | none | missing | not started: Phase 3; planned laws (PROPOSED_ARCHITECTURE §8, not yet stated): utf8_roundtrip, json_string_roundtrip |
| JSONL write-back | S5.1–S5.19, S6.2–S6.5 | `Store.text`, `Model.normalize` | `edge_precision_rewrite` | none | missing | not started: Phase 3; planned laws (PROPOSED_ARCHITECTURE §8, not yet stated): labels_normalize_idempotent, store_text_fixpoint_basic |
| timestamps: parse, order, print | S4.52–S4.64, S7.14 | `Time.*` | `edge_precision_ready`, `edge_precision_sort_created`, `edge_precision_sort_title` | `time_whole_second`, `time_millis`, `time_nanos`, `time_tenth_widens`, `time_offset_to_utc`, `time_borrow_across_month`, `time_borrow_into_leap_day`, `time_carry_across_year`, `time_micros`, `time_lowercase_t_z`, `time_refuses_feb_30`, `time_refuses_words`, `time_refuses_hour_24`, `time_refuses_no_zone`, `time_offset_suffix` | missing | `port/core/time.bend` exists and its laws are proved; no command uses it yet, so the row stays missing until its goldens pass on the lanes |
| id generation and child ids | S4.1–S4.27, S7.1–S7.9 | `Sha.digest`, `Id.*` | `scn_dup_title`, `scn_child_ids` | `sha_empty`, `sha_abc`, `sha_two_blocks`, `id_fyw`, `id_mta`, `id_170`, `id_q_asw`, `id_ladder_0`, `id_ladder_1`, `id_ladder_2` | missing | not started: Phase 3; planned laws (PROPOSED_ARCHITECTURE §8, not yet stated): id_fyw, id_length_table |
| partial-id resolution | S4.40–S4.49, S6.31 | `Id.resolve` | `show_partial_hash`, `show_partial_ambiguous`, `error_show_ambiguous_json`, `error_update_ambiguous` | none | missing | not started: Phase 3 |
| `list` | S4.100–S4.136, S5.120–S5.129, S5.30–S5.58, S6.6–S6.11 | `Query.*`, `Render.*_list` | `list_plain`, `list_json`, `list_json_again`, `list_all`, `list_all_json`, `list_status_open`, `list_status_closed`, `list_status_in_progress`, `list_type_bug`, `list_priority_one`, `list_priority_min_max`, `list_assignee`, `list_unassigned`, `list_label`, `list_label_two_and`, `list_label_any`, `list_title_contains`, `list_limit_one`, `list_limit_offset`, `list_sort_title`, `list_sort_created`, `list_sort_updated`, `list_sort_bad`, `list_reverse`, `list_deferred`, `list_long`, `list_fields`, `list_quiet`, `list_id_filter`, `list_status_bad` | none | missing | not started: Phase 3 |
| `search` | S4.137–S4.143, S5.156–S5.160 | `Query.search` | `search_plain`, `search_json`, `search_case_insensitive`, `search_description`, `search_none`, `search_unicode`, `search_status` | none | missing | not started: Phase 3 |
| `count` | S4.144–S4.150, S5.161–S5.166 | `Query.count` | `count_plain`, `count_json`, `count_by_status`, `count_by_priority_json`, `count_by_type`, `count_by_assignee`, `count_by_label`, `count_include_closed` | none | missing | not started: Phase 3; planned laws (PROPOSED_ARCHITECTURE §8, not yet stated): counts_sum_to_total |
| `stats` | S4.151–S4.156, S5.167–S5.172, S7.20 | `Query.stats` | `stats_plain`, `stats_json` | none | missing | not started: Phase 3 |
| `ready` | S4.171–S4.178, S5.130–S5.136, S6.12–S6.14 | `Query.ready` | `ready_plain`, `ready_json`, `ready_limit`, `ready_sort_priority`, `ready_sort_oldest`, `ready_include_deferred`, `ready_type`, `ready_unassigned`, `ready_label` | none | missing | not started: Phase 3 |
| the BLOCKED relation, `blocked` | S4.157–S4.170, S5.137–S5.142, S6.15–S6.16 | `Blocked.*`, `Query.blocked` | `blocked_plain`, `blocked_json` | none | missing | not started: Phase 3 |
| `show` | S4.194–S4.198, S5.143–S5.155, S6.26–S6.27, S6.41 | `Show.gather`, `Render.*_show` | `show_plain`, `show_json`, `show_comments`, `show_comments_json`, `show_closed`, `show_deferred_json`, `show_unicode`, `show_unicode_json`, `show_epic`, `show_two`, `error_show_missing`, `error_show_missing_json` | none | missing | not started: Phase 3 |
| `dep list`, `dep tree`, `dep cycles` | S4.179–S4.188, S5.173–S5.182, S6.24–S6.29 | `Tree.*` | `dep_list`, `dep_list_json`, `dep_list_none`, `dep_tree`, `dep_tree_json`, `dep_tree_leaf`, `dep_cycles`, `dep_cycles_json` | none | missing | not started: Phase 3 |
| `label list`, `label list-all` | S5.183–S5.190, S6.20–S6.21 | `Render.*_label` | `label_list`, `label_list_json`, `label_list_all`, `label_list_all_json` | none | missing | not started: Phase 3 |
| `comments list` | S5.191–S5.195, S6.22 | `Render.*_comments` | `comments_list`, `comments_list_json`, `comments_list_empty` | none | missing | not started: Phase 3 |
| `epic status` | S4.189–S4.193, S5.196–S5.199 | `Epic.status` | `epic_status`, `epic_status_json` | none | missing | not started: Phase 3 |
| `create`, `q` | S4.200–S4.254, S5.203–S5.212 | `Mutate.create`, `Mutate.q` | `create_min`, `create_min_json`, `create_full_json`, `create_title_flag`, `create_silent`, `create_dry_run`, `create_dry_run_json`, `create_with_parent`, `create_with_deps`, `create_status_in_progress`, `create_priority_p_form`, `create_custom_type`, `create_unicode`, `create_ephemeral`, `error_create_bad_priority`, `error_create_bad_priority_json`, `error_create_empty_title`, `error_create_blank_title`, `error_create_long_title`, `edge_create_max_title`, `error_create_missing_parent`, `error_create_bad_label`, `q_basic`, `q_priority`, `actor_flag_create` | none | missing | not started: Phase 3 |
| `update` and last-touched | S4.260–S4.275, S5.213–S5.219, S8.17, S8.25 | `Mutate.update` | `update_status`, `update_status_json`, `update_priority`, `update_title`, `update_assignee`, `update_claim`, `update_notes`, `update_add_label`, `update_remove_label`, `update_set_labels`, `update_two_ids`, `update_noop_same_value`, `update_status_closed`, `update_last_touched`, `error_update_missing`, `error_update_bad_priority`, `error_update_blocked_claim`, `scn_last_touched` | none | missing | not started: Phase 3 |
| `close`, `reopen` | S4.290–S4.315, S5.220–S5.228 | `Mutate.close`, `Mutate.reopen` | `close_basic`, `close_reason_json`, `close_suggest_next`, `close_two`, `error_close_blocked`, `error_close_blocked_json`, `close_blocked_force`, `close_already_closed`, `error_close_missing`, `close_epic_with_open_child`, `reopen_closed`, `reopen_closed_json`, `reopen_open`, `error_reopen_missing`, `scn_lifecycle` | none | missing | not started: Phase 3 |
| `defer`, `undefer` | S4.320–S4.328, S5.229–S5.235 | `Mutate.defer`, `Mutate.undefer` | `defer_until_date`, `defer_no_until`, `defer_relative`, `error_defer_bad_until`, `undefer_basic`, `undefer_not_deferred` | none | missing | not started: Phase 3 |
| `delete` | S4.330–S4.341, S5.236–S5.244, S8.26 | `Mutate.delete`, `Sys.remove` | `delete_basic`, `delete_json`, `delete_dry_run`, `delete_with_dependents`, `delete_with_dependents_force`, `delete_cascade`, `error_delete_missing` | none | missing | not started: Phase 3 |
| `dep add`, `dep remove` | S4.350–S4.363 | `Mutate.dep_add`, `Mutate.dep_remove` | `dep_add_blocks`, `dep_add_json`, `dep_add_related`, `dep_add_custom_type`, `error_dep_add_cycle`, `error_dep_add_cycle_json`, `error_dep_add_self`, `dep_add_duplicate`, `error_dep_add_missing`, `dep_add_external`, `dep_remove_basic`, `dep_remove_absent` | none | missing | not started: Phase 3 |
| `label add/remove/rename` | S4.370–S4.379 | `Mutate.label_*` | `label_add`, `label_add_json`, `label_add_existing`, `error_label_add_invalid`, `label_remove`, `label_remove_absent`, `label_rename` | none | missing | not started: Phase 3 |
| `comments add` | S4.380–S4.385, S7.12 | `Mutate.comment_add` | `comments_add`, `comments_add_json`, `comments_add_author`, `comments_add_second`, `error_comments_add_empty`, `error_comments_add_missing`, `actor_flag_comment` | none | missing | not started: Phase 3; planned laws (PROPOSED_ARCHITECTURE §8, not yet stated): digits_succ_is_nat_succ |
| `epic close-eligible` | S4.390–S4.393 | `Mutate.epic_close` | (case to add: `epic_close_eligible_json` — a scenario with an eligible epic; OQ register) | none | missing | not started: Phase 3 |
| errors, exit codes, both renderings | S9.1–S9.25 | `Failure.*`, `Render.error_*` | (cases cited under the commands that raise them) | none | missing | not started: Phase 3 |
| the SQLite store and the default (non `--no-db`) mode | PLAN §3 | - | - | - | excluded | PLAN §3: external-dependency |
| `doctor`, schema migration, `sync --import-only/--rebuild/--merge/--reconcile*`, `history` | PLAN §3 | - | - | - | excluded | PLAN §3: external-dependency |
| `init` creating `beads.db` | PLAN §3 | - | - | - | excluded | PLAN §3: external-dependency (OQ-005 for the `--no-db` form) |
| `serve` (MCP) | PLAN §3 | - | - | - | excluded | PLAN §3: out-of-scope (not compiled into the pinned binary) |
| `upgrade`, `completions`, `agents`, `config edit` | PLAN §3 | - | - | - | excluded | PLAN §3: platform |
| `changelog`, `orphans`, `vcs-status`, commit activity in `stats` | PLAN §3 | - | - | - | excluded | PLAN §3: external-dependency (git subprocess) |
| Rich (TTY) output | PLAN §3 | - | - | - | excluded | PLAN §3: platform |
| TOON output | PLAN §3 | - | - | - | excluded | PLAN §3: out-of-scope (debt) |
| cross-process write locks, opener leases, the inode lock | PLAN §3 | - | - | - | excluded | PLAN §3: concurrency-observable; the blocker is a missing lock effect in Bend (`fcntl`/exclusive create), DISC-002 |
| `.br_history/` backups and the lock sidecars | PLAN §3 | - | - | - | excluded | PLAN §3: platform (DISC-004) |
| `audit`, `capacity`, `gate`, `coordination`, `scheduler`, `query`, `lint`, `stale`, `graph`, `info`, `schema`, `capabilities`, `robot-docs`, `config list/get/set` | PLAN §3 | - | - | - | excluded | PLAN §3: out-of-scope (debt) |
| close policy workflows (`strict` transitions, gates, required fields) | PLAN §3 | - | - | - | excluded | PLAN §3: out-of-scope (debt) |
| `clap` help texts beyond the captured shapes | PLAN §3 | - | - | - | excluded | PLAN §3: external-dependency (debt) |

(The scaffolded board reads PARTIAL until rows are filled; a row whose
feature cell is still `<…>` is reported as PLACEHOLDER by `parity-board.sh`.)

## Proof coverage

| kind | count | list |
|---|---|---|
| fast == spec laws | `<n>` | |
| round-trip / conservation laws | `<n>` | |
| closed goldens as laws | `<n>` | |
| `@unsafe` defs | `<n>` | each with its comment and bead |

## Lanes

| lane | cases | verdict | date |
|---|---|---|---|
| interpreter | `<n>/<n>` | PASS | |
| c-1t | | | |
| c-<N>t | | | |
| js | | | |
| gpu (`--gpu on`) | | PASS · MISSING (no device: stated) | |
