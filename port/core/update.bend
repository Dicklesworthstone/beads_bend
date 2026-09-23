# core/update — `update`: edit stored issues (S4.260–S4.275, S5.39).
# Refusals that need no store come first (a terminal `--status`, a bad
# priority); then EVERY id is resolved before any issue is touched (S4.212);
# then each issue is edited in command-line order, and the first refusal
# discards everything. The store is rewritten only when some issue changed
# (S4.203); `.beads/last-touched` names the last id either way (S4.209).
# `--transition-comment` adds a comment to an issue whose status really moved
# (S4.396); `--session` is refused by the dispatcher (only a close takes it);
# the acceptance-list flags edit the checklist in place (S4.398, Acceptance).
# Not here yet, refused with the port's own failure by the dispatcher:
# `--agent-context`. Nothing here consults the original.
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
import ./edges.bend as Edges
import ./status.bend as Status
import ./acceptance.bend as Acceptance
import ./labels.bend as Labels

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

# S4.395 (spec twin) the notes after `--append-notes`: the text alone onto empty notes, directly after notes that
# already end in a newline, after one `\n` otherwise (`scn_append_notes`)
def appended_to(+old: String, +text: String) -> String:
  Bool.pick(String, String.is_empty(old), text, Bool.pick(String, String.ends_with(old, "\n"), old ++ text, old ++ "\n" ++ text))

# S4.395 (spec twin) the notes with the text appended; an empty text is refused (`error_update_append_empty`)
def append_written(+i: Model.Issue, +text: String) -> Edit:
  Bool.pick(Edit, String.is_empty(text), EditBad{Create.invalid("append-notes", "text to append must not be empty")}, EditOk{set_text(4, i, Some{appended_to(Maybe.default(&2, String, Model.notes_of(i), ""), text)}), True{}})

# S4.395 (spec twin) `--append-notes` folded in, after `--notes` (the two are refused together by the parser)
def with_append(e: Edit, given: Maybe<&2, String>) -> Edit:
  match e given:
    case EditBad{f} _:
      EditBad{f}
    case EditOk{i, changed} None{}:
      EditOk{i, changed}
    case EditOk{i, changed} Some{text}:
      append_written(i, text)

# S4.270 (spec twin) the refusal of a re-parent that would close a cycle: `CYCLE_DETECTED`, exit 5, with its own
# message and the cycle hint of S4.354 (`error_update_parent_cycle`, `error_update_parent_cycle_json`)
def parent_cycle(+child: String, +parent: String) -> Failure.Failure:
  Failure.Failure{"CYCLE_DETECTED", "Cycle detected in dependencies: Setting parent of " ++ child ++ " to " ++ parent ++ " would create a cycle", Some{"Remove one dependency to break the cycle. Note: epic containment participates in blocking cycles — depending on an epic implies depending on its entire subtree, so the cycle may traverse parent-child edges that the message does not list (see docs/CLI_REFERENCE.md, `dep add`)"}, False{}, [Failure.CtxMember{"cycle_path", Failure.CStr{"Setting parent of " ++ child ++ " to " ++ parent ++ " would create a cycle"}}], 5}

# S4.270 (spec twin) an issue's edges without its `parent-child` ones
def without_parents(edges: List<&2, Model.Dependency>) -> List<&2, Model.Dependency>:
  match edges:
    case Nil{}:
      Nil{}
    case Con{+e, rest}:
      Edges.edge_keep(e, Bool.not(String.eq(Model.dep_type_of(e), "parent-child")), without_parents(rest))

# S4.270 (spec twin) the issue with its parent edge replaced: the old `parent-child` edges removed and, unless the
# new parent is `""`, one new edge at the end, stamped now by the actor (`update_parent`, `update_parent_clear`)
def reparented(i: Model.Issue, +id: String, +parent: String, actor: String, now: Time.Instant) -> Model.Issue:
  match i:
    case Model.Issue{head, texts, people, times, closing, source, deletion, compaction, meta, flags, labels, +dependencies, comments}:
      Model.Issue{head, texts, people, times, closing, source, deletion, compaction, meta, flags, labels, Bool.pick(List<&2, Model.Dependency>, String.is_empty(parent), without_parents(dependencies), List.append(&2, Model.Dependency, without_parents(dependencies), Model.Dependency{id, parent, "parent-child", now, Some{actor}, Some{"{}"}, Some{""}} <> Nil{})), comments}

# S4.270 (spec twin) a resolved parent against one issue: itself refused (S4.356); refused when the issue already
# reaches the new parent in the cycle graph of S4.354 (the new edge's arc would run parent → child and close it:
# `proj-170` blocks on `proj-mta`, `proj-uly` contains `proj-170`); else re-parented
def parent_written(+i: Model.Issue, +parent: String, +model: List<&2, Model.Issue>, actor: String, now: Time.Instant) -> Edit:
  Bool.pick(Edit, String.eq(parent, Model.id_of(i)), EditBad{Edges.self_edge(parent)}, Bool.pick(Edit, (Bool.not(String.is_empty(parent)) && Edges.reaches(model, Model.id_of(i), parent)), EditBad{parent_cycle(Model.id_of(i), parent)}, EditOk{reparented(i, Model.id_of(i), parent, actor, now), True{}}))

# S4.270 (spec twin) `--parent` folded in; `parent` is the resolved id, `""` to clear, none when the flag is absent
def with_parent(e: Edit, parent: Maybe<&2, String>, model: List<&2, Model.Issue>, actor: String, now: Time.Instant) -> Edit:
  match e parent:
    case EditBad{f} _:
      EditBad{f}
    case EditOk{i, changed} None{}:
      EditOk{i, changed}
    case EditOk{i, changed} Some{p}:
      parent_written(i, p, model, actor, now)

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
  Bool.pick(Edit, Nat.is_gt(List.length(&2, String, after), 64n), EditBad{Create.invalid("labels", "exceeds 64 labels")}, EditOk{set_labels(i, after), (changed || Bool.not(same_labels(Model.labels_of(i), after)))})

# S4.268 S4.372 (spec twin) the label flags once every named label passed the rules of S4.372: the first that fails
# (a `--set-labels` item, an `--add-label`, a `--remove-label`, in that order; `--add-label` is never split at commas)
# refuses the update
def labels_valid(+i: Model.Issue, +set: List<&2, String>, +add: List<&2, String>, +remove: List<&2, String>, replacing: Bool, changed: Bool, +bad: String) -> Edit:
  match bad:
    case SCon{h, t}:
      EditBad{Labels.label_refusal(SCon{h, t})}
    case SNil{}:
      labels_written(i, labels_after(Model.labels_of(i), set, add, remove, replacing), changed)

# S4.268 (spec twin) the label flags, when any is given
def with_labels(e: Edit, +set: List<&2, String>, +add: List<&2, String>, +remove: List<&2, String>, any: Bool, +replacing: Bool) -> Edit:
  match e any:
    case EditBad{f} _:
      EditBad{f}
    case EditOk{i, changed} False{}:
      EditOk{i, changed}
    case EditOk{+i, changed} True{}:
      labels_valid(i, set, add, remove, replacing, changed, Labels.first_bad(List.concat(&2, String, [Bool.pick(List<&2, String>, replacing, Query.comma_split(set), Nil{}), add, remove])))

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

# S4.395 (spec twin) how many newlines a text holds
def newlines(s: String) -> Nat:
  match s:
    case SNil{}:
      0n
    case SCon{Chr{+c}, rest}:
      (Bool.pick(Nat, U32.is_eq(c, 10), 1n, 0n) + newlines(rest) : Nat)

# S4.395 (spec twin) the lines of a text as Rust's `str::lines` counts them: none for the empty text, and a trailing
# newline ends the last line rather than opening another
def line_count(+s: String) -> Nat:
  Bool.pick(Nat, String.is_empty(s), 0n, Bool.pick(Nat, String.ends_with(s, "\n"), newlines(s), (newlines(s) + 1n : Nat)))

# S4.395 (spec twin) the notes line of `--append-notes`: `  notes: appended <n> chars (now <l> line[s], <c> chars)`;
# `chars` counts code points and is never singular, `line` is (`update_append_notes_unicode`, `scn_append_notes`)
def append_line(appended: Maybe<&2, String>, +notes: String) -> String:
  match appended:
    case None{}:
      ""
    case Some{text}:
      String.concat(["  notes: appended ", Nat.show(String.length(text)), " chars (now ", Nat.show(line_count(notes)), Bool.pick(String, Nat.is_eq(line_count(notes), 1n), " line, ", " lines, "), Nat.show(String.length(notes)), " chars)\n"])

# S4.272 S4.273 S4.395 (spec twin) the plain block of one updated issue: `Updated <id>: <title>` and one line per
# observed change, in the fixed order status, priority, type, assignee, owner, then the notes line of
# `--append-notes`; without any field flag, one other line
def block_plain(+old: Model.Issue, +new: Model.Issue, any_flag: Bool, appended: Maybe<&2, String>) -> String:
  match any_flag:
    case False{}:
      "No updates specified for " ++ Render.inline(Model.id_of(new)) ++ "\n"
    case True{}:
      String.concat(["Updated ", Render.inline(Model.id_of(new)), ": ", Render.inline(Model.title_of(new)), "\n", change_line("status", Model.status_of(old), Model.status_of(new)), change_line("priority", "P" ++ Model.priority_of(old), "P" ++ Model.priority_of(new)), change_line("type", Model.type_of(old), Model.type_of(new)), change_line("assignee", person_text(Model.assignee_of(old)), person_text(Model.assignee_of(new))), change_line("owner", person_text(Model.owner_of(old)), person_text(Model.owner_of(new))), append_line(appended, Maybe.default(&2, String, Model.notes_of(new), ""))])

# S5.39 (spec twin) a person in the JSON element: an explicit `null` when unset
def person_json(value: Maybe<&2, String>) -> String:
  match value:
    case None{}:
      "null"
    case Some{v}:
      Failure.quoted(v)

# S5.39 S4.395 (spec twin) the `notes` member `--append-notes` adds: the text, `applied`, the lengths before and
# after in code points, and the new notes (`update_append_notes_json`)
def append_json(appended: Maybe<&2, String>, +before: String, +after: String) -> String:
  match appended:
    case None{}:
      ""
    case Some{text}:
      String.concat([",\"notes\":{\"appended\":", Failure.quoted(text), ",\"applied\":true,\"chars_before\":", Nat.show(String.length(before)), ",\"chars_after\":", Nat.show(String.length(after)), ",\"text\":", Failure.quoted(after), "}"])

# S5.39 S4.398 (spec twin) the JSON element of one updated issue: seven members in this order, `notes` after them
# under `--append-notes`, then `acceptance_criteria` under the acceptance-list flags (`extra`)
def block_json(+old: Model.Issue, +i: Model.Issue, appended: Maybe<&2, String>, extra: String) -> String:
  String.concat(["{\"id\":", Failure.quoted(Model.id_of(i)), ",\"title\":", Failure.quoted(Model.title_of(i)), ",\"status\":", Failure.quoted(Model.status_of(i)), ",\"priority\":", Model.priority_of(i), ",\"assignee\":", person_json(Model.assignee_of(i)), ",\"owner\":", person_json(Model.owner_of(i)), ",\"updated_at\":", Failure.quoted(Time.print(Model.updated_of(i), "Z")), append_json(appended, Maybe.default(&2, String, Model.notes_of(old), ""), Maybe.default(&2, String, Model.notes_of(i), "")), extra, "}"])

# S4.398 (spec twin) the acceptance-list flags on one edited issue: their refusal, or the criteria rewritten, with
# `updated_at` stamped, when a byte changed
def acceptance_applied(e: Edit, acc: Acceptance.Done, +now: Time.Instant) -> Edit:
  match e acc:
    case EditBad{f} _:
      EditBad{f}
    case EditOk{i, changed} Acceptance.AccBad{f}:
      EditBad{f}
    case EditOk{+i, changed} Acceptance.AccOk{text, moved, items, checked, unchecked, added}:
      Bool.pick(Edit, moved, EditOk{stamped(set_text(2, i, Some{text}), now), True{}}, EditOk{i, changed})

# S4.398 (spec twin) the acceptance-list flags, when any was given
def with_acceptance(e: Edit, acc: Acceptance.Done, given: Bool, now: Time.Instant) -> Edit:
  match given:
    case False{}:
      e
    case True{}:
      acceptance_applied(e, acc, now)

# S4.262–S4.268 (spec twin) every flag of one `update` applied to one issue, in a fixed order; `priority` is the
# priority's digits when `-p` was given and judged
def edited(i: Model.Issue, +opts: List<&2, Cli.Occ>, priority: Maybe<&2, String>, relation: List<&2, Blocked.Entry>, +actor: String, +now: Time.Instant, parent: Maybe<&2, String>, model: List<&2, Model.Issue>) -> Edit:
  finished(with_parent(with_labels(with_claim(with_date(with_date(with_flag(with_flag(with_flag(with_flag(with_flag(with_flag(with_flag(with_append(with_body(with_body(with_body(with_body(with_body(with_compared(with_compared(with_status(start(i), Cli.value(opts, "status")), priority, 2), lowered_kind(Cli.value(opts, "type")), 3), Cli.value(opts, "description"), 0, Cli.given(opts, "force")), Cli.value(opts, "design"), 1, Cli.given(opts, "force")), Cli.value(opts, "acceptance-criteria"), 2, Cli.given(opts, "force")), Cli.value(opts, "prerequisites"), 3, Cli.given(opts, "force")), Cli.value(opts, "notes"), 4, Cli.given(opts, "force")), Cli.value(opts, "append-notes")), Cli.value(opts, "title"), 0), Cli.value(opts, "assignee"), 1), Cli.value(opts, "owner"), 2), Cli.value(opts, "external-ref"), 3), Cli.value(opts, "source-repo"), 4), Cli.value(opts, "source-repo-path"), 5), Cli.value(opts, "estimate"), 6), Cli.value(opts, "due"), 0, now, "due_at"), Cli.value(opts, "defer"), 1, now, "defer_until"), Cli.given(opts, "claim"), relation, actor, Cli.given(opts, "force")), Cli.values(opts, "set-labels"), Cli.values(opts, "add-label"), Cli.values(opts, "remove-label"), (Cli.given(opts, "set-labels") || Cli.given(opts, "add-label") || Cli.given(opts, "remove-label")), Cli.given(opts, "set-labels")), parent, model, actor, now), now)

# S4.396 (spec twin) `--transition-comment` on one edited issue: refused unless `--status` moved it to another
# status; otherwise a comment by the actor at the invocation instant
def transition_noted(e: Edit, +old: String, +text: String, given: Bool, actor: String, now: Time.Instant, comment_id: String) -> Edit:
  match e given:
    case EditBad{f} _:
      EditBad{f}
    case EditOk{+i, changed} False{}:
      EditBad{Create.invalid("status", "issue " ++ Model.id_of(i) ++ ": transition comments and workflow-policy bypasses require a real status transition")}
    case EditOk{+i, changed} True{}:
      Bool.pick(Edit, String.eq(Model.status_of(i), old), EditBad{Create.invalid("status", "issue " ++ Model.id_of(i) ++ ": transition comments and workflow-policy bypasses cannot be attached to a same-status update")}, EditOk{Status.with_comment(i, Model.Comment{comment_id, Model.id_of(i), actor, text, now}), changed})

# S4.396 (spec twin) an edit with its transition comment, when one was given
def transition_note(e: Edit, +old: String, comment: Maybe<&2, String>, given: Bool, actor: String, now: Time.Instant, comment_id: String) -> Edit:
  match comment:
    case None{}:
      e
    case Some{text}:
      transition_noted(e, old, text, given, actor, now, comment_id)

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
def batch_put(b: Batch, e: Edit, +old: Model.Issue, any_flag: Bool, +appended: Maybe<&2, String>, plain_extra: String, json_extra: String) -> Batch:
  match b e:
    case BatchBad{f} _:
      BatchBad{f}
    case BatchOk{model, plain, json, changed, last} EditBad{f}:
      BatchBad{f}
    case BatchOk{model, plain, json, changed, last} EditOk{+new, touched}:
      BatchOk{replaced(model, new), (block_plain(old, new, any_flag, appended) ++ plain_extra) <> plain, block_json(old, new, appended, json_extra) <> json, (changed || touched), Model.id_of(new)}

# S4.261 (spec twin) the current model of a batch; nothing once it was refused
def batch_model(b: Batch) -> List<&2, Model.Issue>:
  match b:
    case BatchBad{f}:
      Nil{}
    case BatchOk{model, plain, json, changed, last}:
      model

# S4.261 S4.396 S4.398 (spec twin) one issue once its acceptance-list run is known: the edit, the checklist, the
# transition comment, and the blocks, with the acceptance block after the plain one when a list flag was given
def batch_checked(+b: Batch, +i: Model.Issue, +opts: List<&2, Cli.Occ>, priority: Maybe<&2, String>, relation: List<&2, Blocked.Entry>, +actor: String, +now: Time.Instant, any_flag: Bool, parent: Maybe<&2, String>, +acc: Acceptance.Done, +given: Bool) -> Batch:
  batch_put(b, transition_note(with_acceptance(edited(i, opts, priority, relation, actor, now, parent, batch_model(b)), acc, given, now), Model.status_of(i), Cli.value(opts, "transition-comment"), Cli.given(opts, "status"), actor, now, Status.next_comment_id(batch_model(b))), i, any_flag, Cli.value(opts, "append-notes"), Bool.pick(String, given, Acceptance.plain(acc, Model.id_of(i), Cli.given(opts, "check-acceptance"), Cli.given(opts, "uncheck-acceptance"), Cli.given(opts, "add-acceptance")), ""), Bool.pick(String, given, Acceptance.json(acc), ""))

# S4.261 (spec twin) one resolved id: the issue as the batch holds it NOW (an id named twice is edited twice)
def batch_id(+b: Batch, found: Maybe<&2, Model.Issue>, +opts: List<&2, Cli.Occ>, priority: Maybe<&2, String>, relation: List<&2, Blocked.Entry>, +actor: String, +now: Time.Instant, any_flag: Bool, parent: Maybe<&2, String>) -> Batch:
  match found:
    case None{}:
      b
    case Some{+i}:
      batch_checked(b, i, opts, priority, relation, actor, now, any_flag, parent, Acceptance.run(Model.id_of(i), Maybe.default(&2, String, Model.acceptance_of(i), ""), Cli.values(opts, "check-acceptance"), Cli.values(opts, "uncheck-acceptance"), Cli.values(opts, "add-acceptance")), (Cli.given(opts, "check-acceptance") || Cli.given(opts, "uncheck-acceptance") || Cli.given(opts, "add-acceptance")))

# S4.261 (spec twin) every resolved id, in command-line order
def batch_go(ids: List<&2, String>, +b: Batch, +opts: List<&2, Cli.Occ>, +priority: Maybe<&2, String>, +relation: List<&2, Blocked.Entry>, +actor: String, +now: Time.Instant, +any_flag: Bool, +parent: Maybe<&2, String>) -> Batch:
  match ids:
    case Nil{}:
      b
    case Con{id, rest}:
      batch_go(rest, batch_id(b, Blocked.lookup(batch_model(b), id), opts, priority, relation, actor, now, any_flag, parent), opts, priority, relation, actor, now, any_flag, parent)

# S4.260–S4.273 S4.270 (spec twin) `update` over resolved ids: `model` is the loaded model, `relation` its BLOCKED
# relation, `parent` the resolved `--parent` (`""` clears; none when the flag is absent)
def run(ids: List<&2, String>, model: List<&2, Model.Issue>, opts: List<&2, Cli.Occ>, priority: Maybe<&2, String>, relation: List<&2, Blocked.Entry>, actor: String, now: Time.Instant, any_flag: Bool, parent: Maybe<&2, String>) -> Batch:
  batch_go(ids, BatchOk{model, Nil{}, Nil{}, False{}, ""}, opts, priority, relation, actor, now, any_flag, parent)
