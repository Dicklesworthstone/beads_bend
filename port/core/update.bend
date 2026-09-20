# core/update — `update`: edit stored issues (S4.260–S4.275, S5.39).
# Refusals that need no store come first (a terminal `--status`, a bad
# priority); then EVERY id is resolved before any issue is touched (S4.212);
# then each issue is edited in command-line order, and the first refusal
# discards everything. The store is rewritten only when some issue changed
# (S4.203); `.beads/last-touched` names the last id either way (S4.209).
# Not here yet, each refused with the port's own failure by the dispatcher:
# `--parent`, `--append-notes`, the acceptance-list flags, `--transition-comment`,
# `--description-file`, `--agent-context`, `--session`. Nothing here consults the original.
import Base
import ./time.bend as Time
import ./model.bend as Model
import ./failure.bend as Failure
import ./cli.bend as Cli
import ./query.bend as Query
import ./create.bend as Create
import ./blocked.bend as Blocked
import ./when.bend as When
import ./render.bend as Render

# S4.262–S4.268 (data) an issue under edit: the refusal (sticky), or the issue so far and whether a stored column changed
type Edit is Data:
  EditBad{failure: Failure.Failure}
  EditOk{issue: Model.Issue, changed: Bool}

# S4.265 (spec twin) a value as an optional member holds it: the empty string clears the member
def optional(value: String) -> Maybe<&2, String>:
  match value:
    case SNil{}:
      None{}
    case SCon{h, t}:
      Some{SCon{h, t}}

# S4.262 S4.264 S4.265 (spec twin) the head members replaced: 0 the title, 1 the status, 2 the priority, 3 the type
def set_head(which: U32, i: Model.Issue, value: String) -> Model.Issue:
  match which i:
    case 0 Model.Issue{Model.Head{id, title, status, priority, kind}, texts, people, times, closing, source, deletion, compaction, meta, flags, labels, dependencies, comments}:
      Model.Issue{Model.Head{id, value, status, priority, kind}, texts, people, times, closing, source, deletion, compaction, meta, flags, labels, dependencies, comments}
    case 1 Model.Issue{Model.Head{id, title, status, priority, kind}, texts, people, times, closing, source, deletion, compaction, meta, flags, labels, dependencies, comments}:
      Model.Issue{Model.Head{id, title, value, priority, kind}, texts, people, times, closing, source, deletion, compaction, meta, flags, labels, dependencies, comments}
    case 2 Model.Issue{Model.Head{id, title, status, priority, kind}, texts, people, times, closing, source, deletion, compaction, meta, flags, labels, dependencies, comments}:
      Model.Issue{Model.Head{id, title, status, value, kind}, texts, people, times, closing, source, deletion, compaction, meta, flags, labels, dependencies, comments}
    case _ Model.Issue{Model.Head{id, title, status, priority, kind}, texts, people, times, closing, source, deletion, compaction, meta, flags, labels, dependencies, comments}:
      Model.Issue{Model.Head{id, title, status, priority, value}, texts, people, times, closing, source, deletion, compaction, meta, flags, labels, dependencies, comments}

# S4.265 (spec twin) a body replaced: 0 description, 1 design, 2 acceptance criteria, 3 prerequisites, 4 notes
def set_text(which: U32, i: Model.Issue, value: Maybe<&2, String>) -> Model.Issue:
  match which i:
    case 0 Model.Issue{head, Model.Texts{a, b, c, d, e}, people, times, closing, source, deletion, compaction, meta, flags, labels, dependencies, comments}:
      Model.Issue{head, Model.Texts{value, b, c, d, e}, people, times, closing, source, deletion, compaction, meta, flags, labels, dependencies, comments}
    case 1 Model.Issue{head, Model.Texts{a, b, c, d, e}, people, times, closing, source, deletion, compaction, meta, flags, labels, dependencies, comments}:
      Model.Issue{head, Model.Texts{a, value, c, d, e}, people, times, closing, source, deletion, compaction, meta, flags, labels, dependencies, comments}
    case 2 Model.Issue{head, Model.Texts{a, b, c, d, e}, people, times, closing, source, deletion, compaction, meta, flags, labels, dependencies, comments}:
      Model.Issue{head, Model.Texts{a, b, value, d, e}, people, times, closing, source, deletion, compaction, meta, flags, labels, dependencies, comments}
    case 3 Model.Issue{head, Model.Texts{a, b, c, d, e}, people, times, closing, source, deletion, compaction, meta, flags, labels, dependencies, comments}:
      Model.Issue{head, Model.Texts{a, b, c, value, e}, people, times, closing, source, deletion, compaction, meta, flags, labels, dependencies, comments}
    case _ Model.Issue{head, Model.Texts{a, b, c, d, e}, people, times, closing, source, deletion, compaction, meta, flags, labels, dependencies, comments}:
      Model.Issue{head, Model.Texts{a, b, c, d, value}, people, times, closing, source, deletion, compaction, meta, flags, labels, dependencies, comments}

# S4.265 (spec twin) a person replaced: 0 the assignee, 1 the owner
def set_person(which: U32, i: Model.Issue, value: Maybe<&2, String>) -> Model.Issue:
  match which i:
    case 0 Model.Issue{head, texts, Model.People{assignee, owner, created_by, sender}, times, closing, source, deletion, compaction, meta, flags, labels, dependencies, comments}:
      Model.Issue{head, texts, Model.People{value, owner, created_by, sender}, times, closing, source, deletion, compaction, meta, flags, labels, dependencies, comments}
    case _ Model.Issue{head, texts, Model.People{assignee, owner, created_by, sender}, times, closing, source, deletion, compaction, meta, flags, labels, dependencies, comments}:
      Model.Issue{head, texts, Model.People{assignee, value, created_by, sender}, times, closing, source, deletion, compaction, meta, flags, labels, dependencies, comments}

# S4.265 (spec twin) a source member replaced: 0 `external_ref`, 1 `source_repo`, 2 `source_repo_path`
def set_source(which: U32, i: Model.Issue, value: Maybe<&2, String>) -> Model.Issue:
  match which i:
    case 0 Model.Issue{head, texts, people, times, closing, Model.Source{a, b, c, d, e}, deletion, compaction, meta, flags, labels, dependencies, comments}:
      Model.Issue{head, texts, people, times, closing, Model.Source{value, b, c, d, e}, deletion, compaction, meta, flags, labels, dependencies, comments}
    case 1 Model.Issue{head, texts, people, times, closing, Model.Source{a, b, c, d, e}, deletion, compaction, meta, flags, labels, dependencies, comments}:
      Model.Issue{head, texts, people, times, closing, Model.Source{a, b, value, d, e}, deletion, compaction, meta, flags, labels, dependencies, comments}
    case _ Model.Issue{head, texts, people, times, closing, Model.Source{a, b, c, d, e}, deletion, compaction, meta, flags, labels, dependencies, comments}:
      Model.Issue{head, texts, people, times, closing, Model.Source{a, b, c, value, e}, deletion, compaction, meta, flags, labels, dependencies, comments}

# S4.265 (spec twin) the estimate replaced
def set_estimate(i: Model.Issue, value: Maybe<&2, String>) -> Model.Issue:
  match i:
    case Model.Issue{head, texts, people, times, closing, source, deletion, compaction, meta, flags, labels, dependencies, comments}:
      Model.Issue{head, texts, people, times, closing, source, deletion, compaction, Model.Meta{value}, flags, labels, dependencies, comments}

# S4.268 (spec twin) the labels replaced
def set_labels(i: Model.Issue, value: List<&2, String>) -> Model.Issue:
  match i:
    case Model.Issue{head, texts, people, times, closing, source, deletion, compaction, meta, flags, labels, dependencies, comments}:
      Model.Issue{head, texts, people, times, closing, source, deletion, compaction, meta, flags, value, dependencies, comments}

# S4.265 (spec twin) a date replaced: 0 `due_at`, 1 `defer_until`
def set_date(which: U32, i: Model.Issue, value: Maybe<&2, Time.Instant>) -> Model.Issue:
  match which i:
    case 0 Model.Issue{head, texts, people, Model.Times{a, b, c, due, defer, f, g}, closing, source, deletion, compaction, meta, flags, labels, dependencies, comments}:
      Model.Issue{head, texts, people, Model.Times{a, b, c, value, defer, f, g}, closing, source, deletion, compaction, meta, flags, labels, dependencies, comments}
    case _ Model.Issue{head, texts, people, Model.Times{a, b, c, due, defer, f, g}, closing, source, deletion, compaction, meta, flags, labels, dependencies, comments}:
      Model.Issue{head, texts, people, Model.Times{a, b, c, due, value, f, g}, closing, source, deletion, compaction, meta, flags, labels, dependencies, comments}

# S4.263 (spec twin) a non-terminal status clears `closed_at`, `close_reason` and `closed_by_session`
def reopened(i: Model.Issue) -> Model.Issue:
  match i:
    case Model.Issue{head, texts, people, Model.Times{a, b, closed_at, d, e, f, g}, Model.Closing{reason, session, bypassed, bypass_reason, gates}, source, deletion, compaction, meta, flags, labels, dependencies, comments}:
      Model.Issue{head, texts, people, Model.Times{a, b, None{}, d, e, f, g}, Model.Closing{None{}, None{}, bypassed, bypass_reason, gates}, source, deletion, compaction, meta, flags, labels, dependencies, comments}

# S4.204 (spec twin) `updated_at` becomes the invocation instant
def stamped(i: Model.Issue, now: Time.Instant) -> Model.Issue:
  match i:
    case Model.Issue{head, texts, people, Model.Times{a, updated_at, c, d, e, f, g}, closing, source, deletion, compaction, meta, flags, labels, dependencies, comments}:
      Model.Issue{head, texts, people, Model.Times{a, now, c, d, e, f, g}, closing, source, deletion, compaction, meta, flags, labels, dependencies, comments}

# ---------------------------------------------------------------- the edits, one flag at a time

# S4.265 (spec twin) a member written whenever its flag is present: 0 title, 1 assignee, 2 owner, 3 `external_ref`
# (trimmed, S2.36), 4 `source_repo`, 5 `source_repo_path`, 6 the estimate; an empty value clears an optional member
def put(kind: U32, i: Model.Issue, value: String) -> Model.Issue:
  match kind:
    case 0:
      set_head(0, i, value)
    case 1:
      set_person(0, i, optional(value))
    case 2:
      set_person(1, i, optional(value))
    case 3:
      set_source(0, i, optional(String.trim(value)))
    case 4:
      set_source(1, i, optional(value))
    case 5:
      set_source(2, i, optional(value))
    case _:
      set_estimate(i, Create.minutes(optional(value)))

# S4.265 (spec twin) one always-written flag folded in; a refusal is sticky
def with_flag(e: Edit, given: Maybe<&2, String>, kind: U32) -> Edit:
  match e given:
    case EditBad{f} _:
      EditBad{f}
    case EditOk{i, changed} None{}:
      EditOk{i, changed}
    case EditOk{i, changed} Some{value}:
      EditOk{put(kind, i, value), True{}}

# S4.262 S4.263 (spec twin) `--status`: written unconditionally, in the model's spelling; a non-terminal status clears
# the closing members (a terminal one was refused before any issue was read, S4.269)
def with_status(e: Edit, given: Maybe<&2, String>) -> Edit:
  match e given:
    case EditBad{f} _:
      EditBad{f}
    case EditOk{i, changed} None{}:
      EditOk{i, changed}
    case EditOk{i, changed} Some{value}:
      EditOk{reopened(set_head(1, i, Model.status_repaired(Model.lowered(value)))), True{}}

# S4.264 (spec twin) a compared member (2 the priority, 3 the type): nothing is touched when the value is already held
def with_compared(e: Edit, given: Maybe<&2, String>, +which: U32) -> Edit:
  match e given:
    case EditBad{f} _:
      EditBad{f}
    case EditOk{i, changed} None{}:
      EditOk{i, changed}
    case EditOk{+i, changed} Some{+value}:
      EditOk{set_head(which, i, value), (changed || Bool.not(String.eq(value, Bool.pick(String, U32.is_eq(which, 2), Model.priority_of(i), Model.type_of(i)))))}

# S4.266 (spec twin) the hint of the accumulated-context guard
def context_hint() -> String:
  "These fields accumulate context: a write that clears the field or keeps less than half its length needs --force; run `br show <id>` first to read what is there, or use --append-notes / --add-acceptance to extend instead of replace."

# S4.266 (spec twin) the refusal of the accumulated-context guard: an empty value, or one under half the stored length
def context_refusal(id: String, +field: String, +old: Nat, +new: Nat) -> Failure.Failure:
  Failure.Failure{"VALIDATION_FAILED", "Validation failed: update: " ++ id ++ ": refusing to overwrite non-empty '" ++ field ++ "' (" ++ Nat.show(old) ++ " chars) with " ++ Bool.pick(String, Nat.is_eq(new, 0n), "an empty value", "different content (" ++ Nat.show(new) ++ " chars, " ++ Nat.show(Nat.div(Nat.mul(new, 100n), Nat.max(old, 1n))) ++ "% of the current length)") ++ " without --force", Some{context_hint()}, True{}, Nil{}, 4}

# S4.266 (spec twin) the name of a guarded body: 0 description, 1 design, 2 acceptance criteria, 3 prerequisites, 4 notes
def body_name(which: U32) -> String:
  match which:
    case 0:
      "description"
    case 1:
      "design"
    case 2:
      "acceptance_criteria"
    case 3:
      "prerequisites"
    case _:
      "notes"

# S4.266 (spec twin) the stored text of a guarded body, "" when it is not set
def body_of(+which: U32, +i: Model.Issue) -> String:
  Maybe.default(&2, String, Bool.pick(Maybe<&2, String>, U32.is_eq(which, 0), Model.description_of(i), Bool.pick(Maybe<&2, String>, U32.is_eq(which, 1), Model.design_of(i), Bool.pick(Maybe<&2, String>, U32.is_eq(which, 2), Model.acceptance_of(i), Bool.pick(Maybe<&2, String>, U32.is_eq(which, 3), Model.prerequisites_of(i), Model.notes_of(i))))), "")

# S4.265 S4.266 (spec twin) a guarded body written: refused when it would clear a non-empty text, or keep less than
# half of it, with different content and without `--force`
def body_written(+i: Model.Issue, +which: U32, +value: String, +old: String, force: Bool) -> Edit:
  Bool.pick(Edit, (Bool.not(force) && Bool.not(String.is_empty(old)) && Bool.not(String.eq(old, value)) && Nat.is_lt(Nat.mul(String.length(value), 2n), String.length(old))), EditBad{context_refusal(Model.id_of(i), body_name(which), String.length(old), String.length(value))}, EditOk{set_text(which, i, optional(value)), True{}})

# S4.265 S4.266 (spec twin) one body flag folded in
def with_body(e: Edit, given: Maybe<&2, String>, +which: U32, force: Bool) -> Edit:
  match e given:
    case EditBad{f} _:
      EditBad{f}
    case EditOk{i, changed} None{}:
      EditOk{i, changed}
    case EditOk{+i, changed} Some{value}:
      body_written(i, which, value, body_of(which, i), force)

# S4.265 (spec twin) a date read by the grammar of core/when; a text that names no instant refuses the update
def date_written(i: Model.Issue, which: U32, n: When.Named, field: String) -> Edit:
  match n:
    case When.NoTime{why}:
      EditBad{Create.invalid(field, When.reason(why))}
    case When.AtTime{at}:
      EditOk{set_date(which, i, Some{at}), True{}}

# S4.265 (spec twin) `--due` (0) or `--defer` (1) folded in; an empty value clears the date
def with_date(e: Edit, given: Maybe<&2, String>, +which: U32, now: Time.Instant, field: String) -> Edit:
  match e given:
    case EditBad{f} _:
      EditBad{f}
    case EditOk{i, changed} None{}:
      EditOk{i, changed}
    case EditOk{i, changed} Some{SNil{}}:
      EditOk{set_date(which, i, None{}), True{}}
    case EditOk{i, changed} Some{SCon{h, t}}:
      date_written(i, which, When.named(String.trim(SCon{h, t}), now), field)

# S4.164 S4.268 (spec twin) keep a word unless it is to be dropped
def word_put(word: String, drop: Bool, rest: List<&2, String>) -> List<&2, String>:
  match drop:
    case True{}:
      rest
    case False{}:
      word <> rest

# S4.264 (spec twin) a type is compared and stored in lower case, as the model holds types (S2.32)
def lowered_kind(given: Maybe<&2, String>) -> Maybe<&2, String>:
  match given:
    case None{}:
      None{}
    case Some{value}:
      Some{Model.lowered(value)}

# S4.164 S4.219 S4.267 (spec twin) the start-blockers of an issue: its blocker refs without the epic rollup and the
# parent propagation, as ids
def start_blockers(refs: List<&2, String>) -> List<&2, String>:
  match refs:
    case Nil{}:
      Nil{}
    case Con{+r, rest}:
      word_put(Blocked.ref_id(r), (String.ends_with(r, ":child-open") || String.ends_with(r, ":parent-blocked")), start_blockers(rest))

# S4.267 (spec twin) `--claim`: the assignee becomes the actor and the status `in_progress`; an issue with
# start-blockers is refused unless `--force`
def claimed(+i: Model.Issue, +blockers: List<&2, String>, actor: String, force: Bool) -> Edit:
  Bool.pick(Edit, (Bool.not(force) && Bool.not(List.is_empty(&2, String, blockers))), EditBad{Create.invalid("claim", "cannot claim blocked issue: " ++ String.join(blockers, ", "))}, EditOk{reopened(set_head(1, set_person(0, i, Some{actor}), "in_progress")), True{}})

# S4.267 (spec twin) `--claim` folded in; `relation` is the BLOCKED relation of the store
def with_claim(e: Edit, claim: Bool, relation: List<&2, Blocked.Entry>, actor: String, force: Bool) -> Edit:
  match e claim:
    case EditBad{f} _:
      EditBad{f}
    case EditOk{i, changed} False{}:
      EditOk{i, changed}
    case EditOk{+i, changed} True{}:
      claimed(i, start_blockers(Blocked.refs_of(relation, Model.id_of(i))), actor, force)

# S4.268 (spec twin) the labels without the named ones
def labels_without(labels: List<&2, String>, +drop: List<&2, String>) -> List<&2, String>:
  match labels:
    case Nil{}:
      Nil{}
    case Con{+l, rest}:
      word_put(l, Query.among(drop, l), labels_without(rest, drop))

# S4.268 (spec twin) the label set after the three label flags: `--set-labels` replaces it (comma-split), then
# `--add-label` appends what is missing, then `--remove-label` drops what is there; sorted and without duplicates
def labels_after(+current: List<&2, String>, +set: List<&2, String>, add: List<&2, String>, remove: List<&2, String>, replacing: Bool) -> List<&2, String>:
  Model.labels_repaired(labels_without(List.append(&2, String, Bool.pick(List<&2, String>, replacing, Query.comma_split(set), current), add), remove))

# S4.268 (spec twin) are two sorted label lists the same
def same_labels(xs: List<&2, String>, ys: List<&2, String>) -> Bool:
  match xs ys:
    case Nil{} Nil{}:
      True{}
    case Con{x, xr} Con{y, yr}:
      (String.eq(x, y) && same_labels(xr, yr))
    case _ _:
      False{}

# S4.268 (spec twin) the label flags folded in: a no-op when the set does not change
def labels_written(+i: Model.Issue, +after: List<&2, String>, changed: Bool) -> Edit:
  EditOk{set_labels(i, after), (changed || Bool.not(same_labels(Model.labels_of(i), after)))}

# S4.268 (spec twin) the label flags, when any is given
def with_labels(e: Edit, +set: List<&2, String>, add: List<&2, String>, remove: List<&2, String>, any: Bool, replacing: Bool) -> Edit:
  match e any:
    case EditBad{f} _:
      EditBad{f}
    case EditOk{i, changed} False{}:
      EditOk{i, changed}
    case EditOk{+i, changed} True{}:
      labels_written(i, labels_after(Model.labels_of(i), set, add, remove, replacing), changed)

# S4.204 (spec twin) an edit that changed a stored column stamps `updated_at`
def finished(e: Edit, now: Time.Instant) -> Edit:
  match e:
    case EditBad{f}:
      EditBad{f}
    case EditOk{i, False{}}:
      EditOk{i, False{}}
    case EditOk{i, True{}}:
      EditOk{stamped(i, now), True{}}

# S4.218 (spec twin) a tombstone is immutable to `update`
def start(+i: Model.Issue) -> Edit:
  Bool.pick(Edit, String.eq(Model.status_of(i), "tombstone"), EditBad{Create.invalid("issue_id", "cannot update tombstone issue: " ++ Model.id_of(i))}, EditOk{i, False{}})

# S4.273 (spec twin) one observed change: `  <name>: <old> → <new>`, nothing when the two are equal
def change_line(name: String, +old: String, +new: String) -> String:
  Bool.pick(String, String.eq(old, new), "", "  " ++ name ++ ": " ++ Render.inline(old) ++ " → " ++ Render.inline(new) ++ "\n")

# S4.273 (spec twin) an unset person prints as `(none)`
def person_text(value: Maybe<&2, String>) -> String:
  match value:
    case None{}:
      "(none)"
    case Some{v}:
      v

# S4.272 S4.273 (spec twin) the plain block of one updated issue: `Updated <id>: <title>` and one line per observed
# change, in the fixed order status, priority, type, assignee, owner; without any field flag, one other line
def block_plain(+old: Model.Issue, +new: Model.Issue, any_flag: Bool) -> String:
  match any_flag:
    case False{}:
      "No updates specified for " ++ Render.inline(Model.id_of(new)) ++ "\n"
    case True{}:
      String.concat(["Updated ", Render.inline(Model.id_of(new)), ": ", Render.inline(Model.title_of(new)), "\n", change_line("status", Model.status_of(old), Model.status_of(new)), change_line("priority", "P" ++ Model.priority_of(old), "P" ++ Model.priority_of(new)), change_line("type", Model.type_of(old), Model.type_of(new)), change_line("assignee", person_text(Model.assignee_of(old)), person_text(Model.assignee_of(new))), change_line("owner", person_text(Model.owner_of(old)), person_text(Model.owner_of(new)))])

# S5.39 (spec twin) a person in the JSON element: an explicit `null` when unset
def person_json(value: Maybe<&2, String>) -> String:
  match value:
    case None{}:
      "null"
    case Some{v}:
      Failure.quoted(v)

# S5.39 (spec twin) the JSON element of one updated issue: seven members in this order
def block_json(+i: Model.Issue) -> String:
  String.concat(["{\"id\":", Failure.quoted(Model.id_of(i)), ",\"title\":", Failure.quoted(Model.title_of(i)), ",\"status\":", Failure.quoted(Model.status_of(i)), ",\"priority\":", Model.priority_of(i), ",\"assignee\":", person_json(Model.assignee_of(i)), ",\"owner\":", person_json(Model.owner_of(i)), ",\"updated_at\":", Failure.quoted(Time.print(Model.updated_of(i), "Z")), "}"])

# S4.262–S4.268 (spec twin) every flag of one `update` applied to one issue, in a fixed order; `priority` is the
# priority's digits when `-p` was given and judged
def edited(i: Model.Issue, +opts: List<&2, Cli.Occ>, priority: Maybe<&2, String>, relation: List<&2, Blocked.Entry>, actor: String, +now: Time.Instant) -> Edit:
  finished(with_labels(with_claim(with_date(with_date(with_flag(with_flag(with_flag(with_flag(with_flag(with_flag(with_flag(with_body(with_body(with_body(with_body(with_body(with_compared(with_compared(with_status(start(i), Cli.value(opts, "status")), priority, 2), lowered_kind(Cli.value(opts, "type")), 3), Cli.value(opts, "description"), 0, Cli.given(opts, "force")), Cli.value(opts, "design"), 1, Cli.given(opts, "force")), Cli.value(opts, "acceptance-criteria"), 2, Cli.given(opts, "force")), Cli.value(opts, "prerequisites"), 3, Cli.given(opts, "force")), Cli.value(opts, "notes"), 4, Cli.given(opts, "force")), Cli.value(opts, "title"), 0), Cli.value(opts, "assignee"), 1), Cli.value(opts, "owner"), 2), Cli.value(opts, "external-ref"), 3), Cli.value(opts, "source-repo"), 4), Cli.value(opts, "source-repo-path"), 5), Cli.value(opts, "estimate"), 6), Cli.value(opts, "due"), 0, now, "due_at"), Cli.value(opts, "defer"), 1, now, "defer_until"), Cli.given(opts, "claim"), relation, actor, Cli.given(opts, "force")), Cli.values(opts, "set-labels"), Cli.values(opts, "add-label"), Cli.values(opts, "remove-label"), (Cli.given(opts, "set-labels") || Cli.given(opts, "add-label") || Cli.given(opts, "remove-label")), Cli.given(opts, "set-labels")), now)

# S4.261 (data) a batch so far: the refusal (sticky), or the model with the edits in it, the plain blocks and the JSON
# elements (both REVERSED), whether any stored column changed, and the last id acted on
type Batch is Data:
  BatchBad{failure: Failure.Failure}
  BatchOk{model: List<&2, Model.Issue>, plain: List<&2, String>, json: List<&2, String>, changed: Bool, last: String}

# S4.261 (spec twin) the model with one issue replaced by its edited self
def replaced(model: List<&2, Model.Issue>, +new: Model.Issue) -> List<&2, Model.Issue>:
  match model:
    case Nil{}:
      Nil{}
    case Con{+i, rest}:
      Bool.pick(Model.Issue, String.eq(Model.id_of(i), Model.id_of(new)), new, i) <> replaced(rest, new)

# S4.261 (spec twin) one edited issue folded into the batch
def batch_put(b: Batch, e: Edit, +old: Model.Issue, any_flag: Bool) -> Batch:
  match b e:
    case BatchBad{f} _:
      BatchBad{f}
    case BatchOk{model, plain, json, changed, last} EditBad{f}:
      BatchBad{f}
    case BatchOk{model, plain, json, changed, last} EditOk{+new, touched}:
      BatchOk{replaced(model, new), block_plain(old, new, any_flag) <> plain, block_json(new) <> json, (changed || touched), Model.id_of(new)}

# S4.261 (spec twin) the current model of a batch; nothing once it was refused
def batch_model(b: Batch) -> List<&2, Model.Issue>:
  match b:
    case BatchBad{f}:
      Nil{}
    case BatchOk{model, plain, json, changed, last}:
      model

# S4.261 (spec twin) one resolved id: the issue as the batch holds it NOW (an id named twice is edited twice)
def batch_id(+b: Batch, found: Maybe<&2, Model.Issue>, +opts: List<&2, Cli.Occ>, priority: Maybe<&2, String>, relation: List<&2, Blocked.Entry>, actor: String, now: Time.Instant, any_flag: Bool) -> Batch:
  match found:
    case None{}:
      b
    case Some{+i}:
      batch_put(b, edited(i, opts, priority, relation, actor, now), i, any_flag)

# S4.261 (spec twin) every resolved id, in command-line order
def batch_go(ids: List<&2, String>, +b: Batch, +opts: List<&2, Cli.Occ>, +priority: Maybe<&2, String>, +relation: List<&2, Blocked.Entry>, +actor: String, +now: Time.Instant, +any_flag: Bool) -> Batch:
  match ids:
    case Nil{}:
      b
    case Con{id, rest}:
      batch_go(rest, batch_id(b, Blocked.lookup(batch_model(b), id), opts, priority, relation, actor, now, any_flag), opts, priority, relation, actor, now, any_flag)

# S4.260–S4.273 (spec twin) `update` over resolved ids: `model` is the loaded model, `relation` its BLOCKED relation
def run(ids: List<&2, String>, model: List<&2, Model.Issue>, opts: List<&2, Cli.Occ>, priority: Maybe<&2, String>, relation: List<&2, Blocked.Entry>, actor: String, now: Time.Instant, any_flag: Bool) -> Batch:
  batch_go(ids, BatchOk{model, Nil{}, Nil{}, False{}, ""}, opts, priority, relation, actor, now, any_flag)
