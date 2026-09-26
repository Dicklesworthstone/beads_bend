# core/remove — `delete`: a soft delete that tombstones (S4.330–S4.341, S5.44).
# The named ids are deduplicated and sorted ascending before resolution
# (S4.340), so the command line's order never reaches the output. Dependents
# that neither `--force` nor `--cascade` accounts for turn the run into a
# PREVIEW that writes nothing. Every edge touching a deleted id is removed
# from both ends, then the tombstones are written; `--hard` drops the records
# instead, and `--hard` with no ids purges every tombstone (S4.339).
# Not here yet, refused with the port's own failure by the dispatcher:
# `--from-file`. Nothing here consults the original.
import Base
import ./time.bend as Time
import ./model.bend as Model
import ./failure.bend as Failure
import ./blocked.bend as Blocked
import ./render.bend as Render

# S4.330 (spec twin) the record as a tombstone: the status, the instant, the actor, the reason and the type the
# issue had; `issue_type` itself, the title, the priority and the labels are left alone; an empty `--reason` stores no
# `delete_reason` (round 19)
def tombstoned(i: Model.Issue, +now: Time.Instant, actor: String, +reason: String) -> Model.Issue:
  match i:
    case Model.Issue{Model.Head{id, title, status, priority, +kind}, texts, people, Model.Times{created_at, updated_at, closed_at, due_at, defer_until, deleted_at, compacted_at}, closing, source, deletion, compaction, meta, flags, labels, dependencies, comments}:
      Model.Issue{Model.Head{id, title, "tombstone", priority, kind}, texts, people, Model.Times{created_at, now, closed_at, due_at, defer_until, Some{now}, compacted_at}, closing, source, Model.Deletion{Some{actor}, Bool.pick(Maybe<&2, String>, String.is_empty(reason), None{}, Some{reason}), Some{kind}}, compaction, meta, flags, labels, dependencies, comments}

# S4.331 (spec twin) keep an edge whose target survives
def edge_put(e: Model.Dependency, drop: Bool, rest: List<&2, Model.Dependency>) -> List<&2, Model.Dependency>:
  match drop:
    case True{}:
      rest
    case False{}:
      e <> rest

# S4.331 (spec twin) the edges of one issue that point at none of the deleted ids
def edges_without(edges: List<&2, Model.Dependency>, +ids: List<&2, String>) -> List<&2, Model.Dependency>:
  match edges:
    case Nil{}:
      Nil{}
    case Con{+e, rest}:
      edge_put(e, Blocked.among(ids, Model.target_of(e)), edges_without(rest, ids))

# S4.336 (spec twin) how many edges of one issue touch a deleted id, from either end
def touching(edges: List<&2, Model.Dependency>, +mine: Bool, +ids: List<&2, String>, acc: U32) -> U32:
  match edges:
    case Nil{}:
      acc
    case Con{+e, rest}:
      touching(rest, mine, ids, (acc + Bool.to_u32((mine || Blocked.among(ids, Model.target_of(e)))) : U32))

# S4.336 (spec twin) every edge of the store that touches a deleted id, counted once
def links_removed(issues: List<&2, Model.Issue>, +ids: List<&2, String>, acc: U32) -> U32:
  match issues:
    case Nil{}:
      acc
    case Con{+i, rest}:
      links_removed(rest, ids, touching(Model.deps_of(i), Blocked.among(ids, Model.id_of(i)), ids, acc))

# S4.331 (spec twin) an issue without its own edges
def without_edges(i: Model.Issue) -> Model.Issue:
  match i:
    case Model.Issue{head, texts, people, times, closing, source, deletion, compaction, meta, flags, labels, dependencies, comments}:
      Model.Issue{head, texts, people, times, closing, source, deletion, compaction, meta, flags, labels, Nil{}, comments}

# S4.331 (spec twin) an issue with these edges
def with_edges(i: Model.Issue, edges: List<&2, Model.Dependency>) -> Model.Issue:
  match i:
    case Model.Issue{head, texts, people, times, closing, source, deletion, compaction, meta, flags, labels, dependencies, comments}:
      Model.Issue{head, texts, people, times, closing, source, deletion, compaction, meta, flags, labels, edges, comments}

# S4.331 (spec twin) `updated_at` becomes the invocation instant
def bumped(i: Model.Issue, now: Time.Instant) -> Model.Issue:
  match i:
    case Model.Issue{head, texts, people, Model.Times{created_at, updated_at, c, d, e, f, g}, closing, source, deletion, compaction, meta, flags, labels, dependencies, comments}:
      Model.Issue{head, texts, people, Model.Times{created_at, now, c, d, e, f, g}, closing, source, deletion, compaction, meta, flags, labels, dependencies, comments}

# S4.330 S4.331 S4.341 (spec twin) one record after the delete: a deleted id that is still live becomes a
# tombstone without edges; an id that is ALREADY a tombstone is a silent no-op, not a second tombstone; another
# issue loses its edges to deleted ids (and has its `updated_at` bumped only when it lost one)
def applied_one(+i: Model.Issue, +ids: List<&2, String>, +now: Time.Instant, actor: String, reason: String, +kept: List<&2, Model.Dependency>) -> Model.Issue:
  Bool.pick(Model.Issue, (Blocked.among(ids, Model.id_of(i)) && Bool.not(String.eq(Model.status_of(i), "tombstone"))), tombstoned(without_edges(i), now, actor, reason), Bool.pick(Model.Issue, Nat.is_eq(List.length(&2, Model.Dependency, kept), List.length(&2, Model.Dependency, Model.deps_of(i))), i, bumped(with_edges(i, kept), now)))

# S4.330 S4.331 (spec twin) the model after the delete
def applied(issues: List<&2, Model.Issue>, +ids: List<&2, String>, +now: Time.Instant, +actor: String, +reason: String) -> List<&2, Model.Issue>:
  match issues:
    case Nil{}:
      Nil{}
    case Con{+i, rest}:
      applied_one(i, ids, now, actor, reason, edges_without(Model.deps_of(i), ids)) <> applied(rest, ids, now, actor, reason)

# S4.339 (spec twin) one record after a `--hard` delete: a deleted id leaves the store, tombstone or not; another
# issue loses its edges to deleted ids as in S4.331
def purged_one(+i: Model.Issue, +ids: List<&2, String>, +now: Time.Instant, +kept: List<&2, Model.Dependency>, +rest: List<&2, Model.Issue>) -> List<&2, Model.Issue>:
  Bool.pick(List<&2, Model.Issue>, Blocked.among(ids, Model.id_of(i)), rest, Bool.pick(Model.Issue, Nat.is_eq(List.length(&2, Model.Dependency, kept), List.length(&2, Model.Dependency, Model.deps_of(i))), i, bumped(with_edges(i, kept), now)) <> rest)

# S4.339 (spec twin) the model after a `--hard` delete
def purged(issues: List<&2, Model.Issue>, +ids: List<&2, String>, +now: Time.Instant) -> List<&2, Model.Issue>:
  match issues:
    case Nil{}:
      Nil{}
    case Con{+i, rest}:
      purged_one(i, ids, now, edges_without(Model.deps_of(i), ids), purged(rest, ids, now))

# S4.336 S4.339 (spec twin) the labels the deleted records carry, which `--hard` removes with them
def labels_removed(issues: List<&2, Model.Issue>, +ids: List<&2, String>, acc: U32) -> U32:
  match issues:
    case Nil{}:
      acc
    case Con{+i, rest}:
      labels_removed(rest, ids, (acc + Bool.pick(U32, Blocked.among(ids, Model.id_of(i)), U32.from_nat(List.length(&2, String, Model.labels_of(i))), 0) : U32))

# S4.336 (spec twin) one edge's verdict: when `mine`, is its target not purged earlier; otherwise does it point at `x`
def edge_hit(mine: Bool, +e: Model.Dependency, +x: String, +before: List<&2, String>) -> Bool:
  match mine:
    case True{}:
      Bool.not(Blocked.among(before, Model.target_of(e)))
    case False{}:
      String.eq(Model.target_of(e), x)

# S4.336 (spec twin) does an edge list hold an edge to `x`, or (when `mine`) one whose target was not purged earlier
def edge_left(edges: List<&2, Model.Dependency>, +x: String, +before: List<&2, String>, +mine: Bool) -> Bool:
  match edges:
    case Nil{}:
      False{}
    case Con{+e, rest}:
      (edge_hit(mine, e, x, before) || edge_left(rest, x, before, mine))

# S4.336 (spec twin) one record's verdict: its own edges when it is `x`, else its edges to `x` when it was not purged
# before `x`
def record_hit(own: Bool, +i: Model.Issue, +x: String, +before: List<&2, String>) -> Bool:
  match own:
    case True{}:
      edge_left(Model.deps_of(i), x, before, True{})
    case False{}:
      (Bool.not(Blocked.among(before, Model.id_of(i))) && edge_left(Model.deps_of(i), x, before, False{}))

# S4.336 (spec twin) does an edge still touch `x` when it is purged: one of its own edges whose target was not purged
# before it, or an edge of a record not purged before it that points at `x`
def event_of(issues: List<&2, Model.Issue>, +x: String, +before: List<&2, String>) -> Bool:
  match issues:
    case Nil{}:
      False{}
    case Con{+i, rest}:
      (record_hit(String.eq(Model.id_of(i), x), i, x, before) || event_of(rest, x, before))

# S4.336 (spec twin) the count so far, one more when the record had an event
def event_count(hit: Bool, acc: U32) -> U32:
  match hit:
    case True{}:
      (acc + 1 : U32)
    case False{}:
      acc

# S4.336 (spec twin) `events_removed` of `--hard`: one per purged record that an edge still touches when its turn
# comes, the records taken in `set` order (round 19, measured: two edges of one record are one event; a record with
# labels or comments only is none; two purged records with their own edges are two). The original takes the records
# in an order that varies between runs, so a shared edge counts for either end (DISC-011); the port's order is fixed
def events_go(+issues: List<&2, Model.Issue>, ids: List<&2, String>, +before: List<&2, String>, acc: U32) -> U32:
  match ids:
    case Nil{}:
      acc
    case Con{+x, rest}:
      events_go(issues, rest, x <> before, event_count(event_of(issues, x, before), acc))

# ---------------------------------------------------------------- dependents (S4.332)

# S4.332 (spec twin) does one issue depend on a deleted id: it has a BLOCKING edge pointing at one
def depends_on(edges: List<&2, Model.Dependency>, +ids: List<&2, String>) -> Bool:
  match edges:
    case Nil{}:
      False{}
    case Con{+e, rest}:
      ((Blocked.blocking(Model.dep_type_of(e)) && Blocked.among(ids, Model.target_of(e))) || depends_on(rest, ids))

# S4.332 (spec twin) keep a word unless it is to be dropped
def word_put(word: String, drop: Bool, rest: List<&2, String>) -> List<&2, String>:
  match drop:
    case True{}:
      rest
    case False{}:
      word <> rest

# S4.339 (spec twin) the ids of the tombstones, in store order
def tombstone_ids(issues: List<&2, Model.Issue>) -> List<&2, String>:
  match issues:
    case Nil{}:
      Nil{}
    case Con{+i, rest}:
      word_put(Model.id_of(i), Bool.not(String.eq(Model.status_of(i), "tombstone")), tombstone_ids(rest))

# S4.332 (spec twin) the parents named by the `parent-child` edges of a deleted id
def parents_of(edges: List<&2, Model.Dependency>, +mine: Bool) -> List<&2, String>:
  match edges:
    case Nil{}:
      Nil{}
    case Con{+e, rest}:
      word_put(Model.target_of(e), Bool.not((mine && String.eq(Model.dep_type_of(e), "parent-child"))), parents_of(rest, mine))

# S4.332 (spec twin) the ids that depend on the deleted set: every issue with a blocking edge into it, plus the
# parent of every deleted child; the deleted ids themselves are excluded
def dependents_go(issues: List<&2, Model.Issue>, +ids: List<&2, String>) -> List<&2, String>:
  match issues:
    case Nil{}:
      Nil{}
    case Con{+i, rest}:
      List.append(&2, String, word_put(Model.id_of(i), Bool.not((depends_on(Model.deps_of(i), ids) && Bool.not(Blocked.among(ids, Model.id_of(i))))), parents_of(Model.deps_of(i), Blocked.among(ids, Model.id_of(i)))), dependents_go(rest, ids))

# S4.332 (spec twin) drop the ids that are already in the delete set
def drop_known(words: List<&2, String>, +ids: List<&2, String>) -> List<&2, String>:
  match words:
    case Nil{}:
      Nil{}
    case Con{+w, rest}:
      word_put(w, Blocked.among(ids, w), drop_known(rest, ids))

# S4.332 (spec twin) the ids that depend on the deleted set, sorted, de-duplicated, and without the deleted ids
def dependents(+issues: List<&2, Model.Issue>, +ids: List<&2, String>) -> List<&2, String>:
  Model.dedup(List.sort(~String, ~String.is_le, drop_known(dependents_go(issues, ids), ids)))

# S4.335 (spec twin) the transitive closure of the dependent relation, from the named ids; the next round's new
# ids arrive as a parameter (Bend has no mutual recursion), one unit of fuel per round, and a round that finds
# nothing new ends it
def closure(fuel: Nat, +issues: List<&2, Model.Issue>, +ids: List<&2, String>, more: List<&2, String>) -> List<&2, String>:
  match fuel more:
    case 0n _:
      ids
    case 1n+g Nil{}:
      ids
    case 1n+g Con{+m, +rest}:
      closure(g, issues, Model.dedup(List.sort(~String, ~String.is_le, List.append(&2, String, ids, m <> rest))), dependents(issues, Model.dedup(List.sort(~String, ~String.is_le, List.append(&2, String, ids, m <> rest)))))

# S4.335 (spec twin) the ids a run deletes: the named ones, or with `--cascade` their transitive dependents too,
# ascending in both cases
def deleted_set(+issues: List<&2, Model.Issue>, +ids: List<&2, String>, cascade: Bool) -> List<&2, String>:
  Bool.pick(List<&2, String>, cascade, closure(Nat.add(List.length(&2, Model.Issue, issues), 1n), issues, ids, dependents(issues, ids)), Model.dedup(List.sort(~String, ~String.is_le, ids)))

# ---------------------------------------------------------------- what one run answered (S4.333–S4.338)

# S4.333–S4.338 (data) the refusal, the text of a run that writes nothing (the dependents preview and `--dry-run`),
# or the text with the model to write, the ids that were deleted and whether any record actually changed
# (a second delete of the same id changes nothing, S4.341; `.beads/last-touched` is removed when it names one
# of the deleted ids either way, S4.210)
type Done is Data:
  DelBad{failure: Failure.Failure}
  DelPreview{out: String}
  DelDone{out: String, model: List<&2, Model.Issue>, deleted: List<&2, String>, changed: Bool}

# S4.333 S4.337 (spec twin) `  - <id>` per id, one line each
def id_lines(ids: List<&2, String>) -> String:
  match ids:
    case Nil{}:
      ""
    case Con{+id, rest}:
      "  - " ++ Render.inline(id) ++ "\n" ++ id_lines(rest)

# S4.338 (spec twin) `  - <id>: <title>` per id of the dry run, which names the titles
def title_lines(issues: List<&2, Model.Issue>, +ids: List<&2, String>) -> String:
  match issues:
    case Nil{}:
      ""
    case Con{+i, rest}:
      Bool.pick(String, Blocked.among(ids, Model.id_of(i)), "  - " ++ Render.inline(Model.id_of(i)) ++ ": " ++ Render.inline(Model.title_of(i)) ++ "\n", "") ++ title_lines(rest, ids)

# S4.333 (spec twin) the extra block of the preview: the ids `--cascade` would reach beyond the direct dependents
def extra_block(extra: List<&2, String>) -> String:
  match extra:
    case Nil{}:
      ""
    case Con{+e, +rest}:
      "\n" ++ Nat.show(List.length(&2, String, e <> rest)) ++ " additional issue(s) would be transitively affected by --cascade:\n" ++ id_lines(e <> rest)

# S4.333 (spec twin) the preview a delete with unaccounted dependents prints, writing nothing and exiting 0
def preview_text(+direct: List<&2, String>, extra: List<&2, String>, +total: Nat) -> String:
  String.concat(["The following issues depend on issues being deleted:\n", id_lines(direct), extra_block(extra), "\nUse --force to orphan these dependents, or --cascade to delete them recursively.\n--cascade would delete ", Nat.show(total), " total dependent(s).\nNo changes made (preview mode).\n"])

# S4.338 (spec twin) the text of a plain `--dry-run`: the ids it would delete, with their titles
def dry_text(issues: List<&2, Model.Issue>, +ids: List<&2, String>) -> String:
  "Dry-run: Would delete " ++ Nat.show(List.length(&2, String, ids)) ++ " issue(s):\n" ++ title_lines(issues, ids)

# S4.334 S4.337 (spec twin) the orphan block, which only `--force` can produce
def orphan_block(orphans: List<&2, String>) -> String:
  match orphans:
    case Nil{}:
      ""
    case Con{+o, +rest}:
      "Orphaned " ++ Nat.show(List.length(&2, String, o <> rest)) ++ " issue(s):\n" ++ id_lines(o <> rest)

# S4.337 (spec twin) the plain output of a soft delete: the ids, the link count when any edge went, the orphans
def plain_text(+ids: List<&2, String>, +links: U32, orphans: List<&2, String>) -> String:
  String.concat(["Deleted ", Nat.show(List.length(&2, String, ids)), " issue(s):\n", id_lines(ids), Bool.pick(String, U32.is_eq(links, 0), "", "Removed " ++ U32.show(links) ++ " dependency link(s)\n"), orphan_block(orphans)])

# S4.336 (spec twin) one quoted id per element of a JSON array
def quoted_all(ids: List<&2, String>) -> List<&2, String>:
  match ids:
    case Nil{}:
      Nil{}
    case Con{+id, rest}:
      Failure.quoted(id) <> quoted_all(rest)

# S4.336 (spec twin) the seven counters of `delete --json`; `labels_removed` and `events_removed` are zero on
# every soft delete, and `references_updated` is always zero
def json_text(+ids: List<&2, String>, links: U32, labels: U32, events: U32, orphans: List<&2, String>) -> String:
  String.concat(["{\"deleted\":[", String.join(quoted_all(ids), ","), "],\"deleted_count\":", Nat.show(List.length(&2, String, ids)), ",\"dependencies_removed\":", U32.show(links), ",\"labels_removed\":", U32.show(labels), ",\"events_removed\":", U32.show(events), ",\"references_updated\":0,\"orphaned_issues\":[", String.join(quoted_all(orphans), ","), "]}\n"])

# S4.333 S4.338 (spec twin) the JSON of a run that writes nothing: the dependents preview and every `--dry-run`
def preview_json(ids: List<&2, String>, cascade: List<&2, String>, blocked: List<&2, String>, orphans: List<&2, String>) -> String:
  String.concat(["{\"preview\":true,\"would_delete\":[", String.join(quoted_all(ids), ","), "],\"cascade_delete\":[", String.join(quoted_all(cascade), ","), "],\"blocked_dependents\":[", String.join(quoted_all(blocked), ","), "],\"orphaned_issues\":[", String.join(quoted_all(orphans), ","), "]}\n"])

# S4.338 (spec twin) a `Would …` block of a dry run, absent when it names no id
def would_block(lead: String, ids: List<&2, String>) -> String:
  match ids:
    case Nil{}:
      ""
    case Con{+w, +rest}:
      lead ++ Nat.show(List.length(&2, String, w <> rest)) ++ " dependent(s):\n" ++ id_lines(w <> rest)

# S4.338 (spec twin) the block a dry run adds under `--force` (the orphans) or `--cascade` (the closure beyond the
# named ids)
def dry_extra(direct: List<&2, String>, extra: List<&2, String>, force: Bool, cascade: Bool) -> String:
  match force cascade:
    case True{} _:
      would_block("Would orphan ", direct)
    case False{} True{}:
      would_block("Would also cascade delete ", extra)
    case False{} False{}:
      ""

# S4.339 (spec twin) the plain text of a purge and of its dry run
def purge_text(ids: List<&2, String>, dry: Bool) -> String:
  match ids dry:
    case Nil{} True{}:
      "Dry-run: no tombstones to purge.\n"
    case Nil{} False{}:
      "✓ No tombstones to purge.\n"
    case Con{+w, +rest} True{}:
      "Dry-run: Would purge " ++ Nat.show(List.length(&2, String, w <> rest)) ++ " tombstone(s):\n" ++ id_lines(w <> rest)
    case Con{+w, +rest} False{}:
      "✓ Purged " ++ Nat.show(List.length(&2, String, w <> rest)) ++ " tombstone(s)\n" ++ id_lines(w <> rest)

# S4.341 (spec twin) is any named id still a live record: a set of ids that are all tombstones already changes
# nothing, so the store is not rewritten at all
def any_live(issues: List<&2, Model.Issue>, +ids: List<&2, String>) -> Bool:
  match issues:
    case Nil{}:
      False{}
    case Con{+i, rest}:
      ((Blocked.among(ids, Model.id_of(i)) && Bool.not(String.eq(Model.status_of(i), "tombstone"))) || any_live(rest, ids))

# S4.330 S4.331 S4.336 (spec twin) the delete itself: the edges of the whole set go first, then the tombstones,
# and the report names the ids, the links that went and the orphans `--force` left behind
def deleted(+model: List<&2, Model.Issue>, +set: List<&2, String>, +orphans: List<&2, String>, now: Time.Instant, actor: String, reason: String, json: Bool, hard: Bool) -> Done:
  match hard:
    case True{}:
      DelDone{Bool.pick(String, json, json_text(set, links_removed(model, set, 0), labels_removed(model, set, 0), events_go(model, set, Nil{}, 0), orphans), plain_text(set, links_removed(model, set, 0), orphans)), purged(model, set, now), set, True{}}
    case False{}:
      DelDone{Bool.pick(String, json, json_text(set, links_removed(model, set, 0), 0, 0, orphans), plain_text(set, links_removed(model, set, 0), orphans)), applied(model, set, now, actor, reason), set, (any_live(model, set) || Bool.not(U32.is_eq(links_removed(model, set, 0), 0)))}

# S4.338 (spec twin) a `--dry-run` that reached past the preview writes nothing and prints what it would have
# deleted, with the orphans of `--force` or the closure of `--cascade`; its JSON is the preview's shape
def dry_run(+model: List<&2, Model.Issue>, +ids: List<&2, String>, +direct: List<&2, String>, +force: Bool, +cascade: Bool, json: Bool) -> Done:
  match json:
    case True{}:
      DelPreview{preview_json(ids, Bool.pick(List<&2, String>, force, Nil{}, drop_known(deleted_set(model, ids, True{}), ids)), Bool.pick(List<&2, String>, (force || cascade), Nil{}, direct), Bool.pick(List<&2, String>, force, direct, Nil{}))}
    case False{}:
      DelPreview{dry_text(model, ids) ++ dry_extra(direct, drop_known(deleted_set(model, ids, True{}), ids), force, cascade)}

# S4.334 S4.335 S4.338 (spec twin) a run past the preview: `--force` orphans the dependents, `--cascade` deletes
# them too
def settled(+model: List<&2, Model.Issue>, +ids: List<&2, String>, +direct: List<&2, String>, now: Time.Instant, actor: String, reason: String, drying: Bool, forcing: Bool, cascade: Bool, json: Bool, hard: Bool) -> Done:
  match drying forcing:
    case True{} forced:
      dry_run(model, deleted_set(model, ids, False{}), direct, forced, cascade, json)
    case False{} True{}:
      deleted(model, deleted_set(model, ids, False{}), direct, now, actor, reason, json, hard)
    case False{} False{}:
      deleted(model, deleted_set(model, ids, cascade), Nil{}, now, actor, reason, json, hard)

# S4.333 S4.334 S4.335 (spec twin) `delete` once its ids are resolved: dependents that neither `--force` nor
# `--cascade` accounts for make the run a preview (JSON: the dependents as `blocked_dependents`), whatever
# `--dry-run` and `--hard` say
def run(+model: List<&2, Model.Issue>, +ids: List<&2, String>, +direct: List<&2, String>, now: Time.Instant, actor: String, reason: String, previewing: Bool, force: Bool, cascade: Bool, json: Bool, dry: Bool, hard: Bool) -> Done:
  match previewing json:
    case True{} False{}:
      DelPreview{preview_text(direct, drop_known(deleted_set(model, ids, True{}), List.append(&2, String, ids, direct)), List.length(&2, String, drop_known(deleted_set(model, ids, True{}), ids)))}
    case True{} True{}:
      DelPreview{preview_json(deleted_set(model, ids, False{}), drop_known(deleted_set(model, ids, True{}), ids), direct, Nil{})}
    case False{} js:
      settled(model, ids, direct, now, actor, reason, dry, force, cascade, js, hard)

# S4.339 (spec twin) `delete --hard` with no ids: every tombstone leaves the store, in ascending id order; the
# counters are those of S4.336 over that set, and an empty set writes nothing
def purge_of(+model: List<&2, Model.Issue>, +set: List<&2, String>, now: Time.Instant, dry: Bool, json: Bool) -> Done:
  match dry json:
    case True{} True{}:
      DelPreview{preview_json(set, Nil{}, Nil{}, Nil{})}
    case True{} False{}:
      DelPreview{purge_text(set, True{})}
    case False{} js:
      DelDone{Bool.pick(String, js, json_text(set, links_removed(model, set, 0), labels_removed(model, set, 0), events_go(model, set, Nil{}, 0), Nil{}), purge_text(set, False{})), purged(model, set, now), set, Bool.not(List.is_empty(&2, String, set))}

# S4.339 (spec twin) the purge of every tombstone
def purge(+model: List<&2, Model.Issue>, now: Time.Instant, json: Bool, dry: Bool) -> Done:
  purge_of(model, List.sort(~String, ~String.is_le, tombstone_ids(model)), now, dry, json)
