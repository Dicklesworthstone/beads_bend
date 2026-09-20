# core/remove — `delete`: a soft delete that tombstones (S4.330–S4.341, S5.44).
# The named ids are deduplicated and sorted ascending before resolution
# (S4.340), so the command line's order never reaches the output. Dependents
# that neither `--force` nor `--cascade` accounts for turn the run into a
# PREVIEW that writes nothing. Every edge touching a deleted id is removed
# from both ends, then the tombstones are written.
# Not here yet, each refused with the port's own failure by the dispatcher:
# `--hard` (a purge) and `--from-file`. Nothing here consults the original.
import Base
import ./time.bend as Time
import ./model.bend as Model
import ./failure.bend as Failure
import ./blocked.bend as Blocked
import ./render.bend as Render

# S4.330 (spec twin) the record as a tombstone: the status, the instant, the actor, the reason and the type the
# issue had; `issue_type` itself, the title, the priority and the labels are left alone
def tombstoned(i: Model.Issue, +now: Time.Instant, actor: String, reason: String) -> Model.Issue:
  match i:
    case Model.Issue{Model.Head{id, title, status, priority, +kind}, texts, people, Model.Times{created_at, updated_at, closed_at, due_at, defer_until, deleted_at, compacted_at}, closing, source, deletion, compaction, meta, flags, labels, dependencies, comments}:
      Model.Issue{Model.Head{id, title, "tombstone", priority, kind}, texts, people, Model.Times{created_at, now, closed_at, due_at, defer_until, Some{now}, compacted_at}, closing, source, Model.Deletion{Some{actor}, Some{reason}, Some{kind}}, compaction, meta, flags, labels, dependencies, comments}

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

# S4.330 S4.331 (spec twin) one record after the delete: a deleted id becomes a tombstone without edges, another
# issue loses its edges to deleted ids (and has its `updated_at` bumped only when it lost one)
def applied_one(+i: Model.Issue, +ids: List<&2, String>, +now: Time.Instant, actor: String, reason: String, +kept: List<&2, Model.Dependency>) -> Model.Issue:
  Bool.pick(Model.Issue, Blocked.among(ids, Model.id_of(i)), tombstoned(without_edges(i), now, actor, reason), Bool.pick(Model.Issue, Nat.is_eq(List.length(&2, Model.Dependency, kept), List.length(&2, Model.Dependency, Model.deps_of(i))), i, bumped(with_edges(i, kept), now)))

# S4.330 S4.331 (spec twin) the model after the delete
def applied(issues: List<&2, Model.Issue>, +ids: List<&2, String>, +now: Time.Instant, +actor: String, +reason: String) -> List<&2, Model.Issue>:
  match issues:
    case Nil{}:
      Nil{}
    case Con{+i, rest}:
      applied_one(i, ids, now, actor, reason, edges_without(Model.deps_of(i), ids)) <> applied(rest, ids, now, actor, reason)

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
# or the text with the model to write and the ids that were deleted (`.beads/last-touched` is removed when it
# names one of them, S4.210)
type Done is Data:
  DelBad{failure: Failure.Failure}
  DelPreview{out: String}
  DelDone{out: String, model: List<&2, Model.Issue>, deleted: List<&2, String>}

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

# S4.336 (spec twin) the seven counters of `delete --json`; `labels_removed`, `events_removed` and
# `references_updated` are zero on every soft delete
def json_text(+ids: List<&2, String>, links: U32, orphans: List<&2, String>) -> String:
  String.concat(["{\"deleted\":[", String.join(quoted_all(ids), ","), "],\"deleted_count\":", Nat.show(List.length(&2, String, ids)), ",\"dependencies_removed\":", U32.show(links), ",\"labels_removed\":0,\"events_removed\":0,\"references_updated\":0,\"orphaned_issues\":[", String.join(quoted_all(orphans), ","), "]}\n"])

# S4.330 S4.331 S4.336 (spec twin) the delete itself: the edges of the whole set go first, then the tombstones,
# and the report names the ids, the links that went and the orphans `--force` left behind
def deleted(+model: List<&2, Model.Issue>, +set: List<&2, String>, +orphans: List<&2, String>, now: Time.Instant, actor: String, reason: String, json: Bool) -> Done:
  DelDone{Bool.pick(String, json, json_text(set, links_removed(model, set, 0), orphans), plain_text(set, links_removed(model, set, 0), orphans)), applied(model, set, now, actor, reason), set}

# S4.338 (spec twin) a `--dry-run` that reached this far writes nothing and prints what it would have deleted
def dry_run(+model: List<&2, Model.Issue>, +set: List<&2, String>, orphans: List<&2, String>, now: Time.Instant, actor: String, reason: String, json: Bool, dry: Bool) -> Done:
  match dry:
    case True{}:
      DelPreview{dry_text(model, set)}
    case False{}:
      deleted(model, set, orphans, now, actor, reason, json)

# S4.333 S4.334 S4.335 (spec twin) `delete` once its ids are resolved: dependents that neither `--force` nor
# `--cascade` accounts for make the run a preview; `--force` orphans them; `--cascade` deletes them too
def run(+model: List<&2, Model.Issue>, +ids: List<&2, String>, +direct: List<&2, String>, now: Time.Instant, actor: String, reason: String, previewing: Bool, force: Bool, cascade: Bool, json: Bool, dry: Bool) -> Done:
  match previewing force:
    case True{} _:
      DelPreview{preview_text(direct, drop_known(deleted_set(model, ids, True{}), List.append(&2, String, ids, direct)), List.length(&2, String, drop_known(deleted_set(model, ids, True{}), ids)))}
    case False{} True{}:
      dry_run(model, deleted_set(model, ids, False{}), direct, now, actor, reason, json, dry)
    case False{} False{}:
      dry_run(model, deleted_set(model, ids, cascade), Nil{}, now, actor, reason, json, dry)
