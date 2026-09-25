# core/views — the small read-only views: `dep list`, `dep tree`, `dep cycles`, `label list`,
# `label list-all`, `comments list`, `epic status`, `where` (S4.179–S4.192, S5.46–S5.56, S5.176–S5.200).
# Each answers its text for stdout (plain or JSON) or a refusal. `dep tree`
# walks the graph in full (`tree_walk`, S4.182–S4.185). `dep cycles` prunes the
# graph to what lies on or leads into a cycle, finds the strongly connected
# components there and reports one depth-first witness each (S4.186–S4.188,
# OQ-129, measured on hand-written cycle fixtures). Nothing here consults the
# original.
import Base
import ./time.bend as Time
import ./model.bend as Model
import ./failure.bend as Failure
import ./render.bend as Render
import ./resolve.bend as Resolve
import ./blocked.bend as Blocked
import ./work.bend as Work
import ./query.bend as Query

# S5.20 (data) what a view answers: a refusal; the text for stdout; or "this form is not ported yet"
type View is Data:
  ViewBad{failure: Failure.Failure}
  ViewOk{out: String}
  ViewLater{}
  ViewCode{out: String, err: String, code: U32}

# S3.1 (spec twin) every stored id, in store order
def ids_of(issues: List<&2, Model.Issue>) -> List<&2, String>:
  match issues:
    case Nil{}:
      Nil{}
    case Con{i, rest}:
      Model.id_of(i) <> ids_of(rest)

# ---------------------------------------------------------------- dep list (S4.179–S4.181, S5.46, S5.176–S5.178)

# S4.179 (data) one row: the edge, the record on its OTHER end when it is stored, and whether the queried issue is its source
type Edge is Data:
  Edge{issue_id: String, depends_on_id: String, kind: String, other: Maybe<&2, Model.Issue>, outgoing: Bool}

# S4.179 (spec twin) keep an edge whose type passes `--type` ("" keeps every type)
def edge_put(e: Edge, keep: Bool, rest: List<&2, Edge>) -> List<&2, Edge>:
  match keep:
    case True{}:
      e <> rest
    case False{}:
      rest

# S4.179 (spec twin) the issue's own edges, as rows
def down_edges(edges: List<&2, Model.Dependency>, +all: List<&2, Model.Issue>, +kind: String) -> List<&2, Edge>:
  match edges:
    case Nil{}:
      Nil{}
    case Con{Model.Dependency{issue_id, +depends_on_id, +dep_type, created_at, created_by, metadata, thread_id}, rest}:
      edge_put(Edge{issue_id, depends_on_id, dep_type, Blocked.lookup(all, depends_on_id), True{}}, (String.is_empty(kind) || String.eq(dep_type, kind)), down_edges(rest, all, kind))

# S4.179 (spec twin) the edges of ONE other record that point at the issue
def up_from(edges: List<&2, Model.Dependency>, +from: Model.Issue, +id: String, +kind: String, later: List<&2, Edge>) -> List<&2, Edge>:
  match edges:
    case Nil{}:
      later
    case Con{Model.Dependency{issue_id, +depends_on_id, +dep_type, created_at, created_by, metadata, thread_id}, rest}:
      edge_put(Edge{issue_id, depends_on_id, dep_type, Some{from}, False{}}, (String.eq(depends_on_id, id) && (String.is_empty(kind) || String.eq(dep_type, kind))), up_from(rest, from, id, kind, later))

# S4.179 (spec twin) every edge of the store that points at the issue
def up_edges(all: List<&2, Model.Issue>, +id: String, +kind: String) -> List<&2, Edge>:
  match all:
    case Nil{}:
      Nil{}
    case Con{+i, rest}:
      up_from(Model.deps_of(i), i, id, kind, up_edges(rest, id, kind))

# S4.180 (spec twin) the other end's priority; a missing end ranks as priority 2
def other_rank(other: Maybe<&2, Model.Issue>) -> U32:
  match other:
    case None{}:
      2
    case Some{i}:
      Query.priority_number(Model.priority_of(i))

# S4.180 (spec twin) the other end's id: the target of an outgoing edge, the source of an incoming one
def other_id(e: Edge) -> String:
  match e:
    case Edge{issue_id, depends_on_id, kind, other, True{}}:
      depends_on_id
    case Edge{issue_id, depends_on_id, kind, other, False{}}:
      issue_id

# S4.180 (spec twin) when the other end was created; a missing end compares as the earliest instant
def other_created(other: Maybe<&2, Model.Issue>) -> Time.Instant:
  match other:
    case None{}:
      Time.Instant{0, 0, 0}
    case Some{i}:
      Model.created_of(i)

# S4.180 (spec twin) the QUERY order, which JSON keeps: the other end's priority ascending, its `created_at`
# descending, its id ascending
def edge_le_query(x: Edge, y: Edge) -> Bool:
  match x y:
    case Edge{xi, xd, xk, +xo, xg} Edge{yi, yd, yk, +yo, yg}:
      Query.le3((other_rank(xo) < other_rank(yo) : U32), U32.is_eq(other_rank(xo), other_rank(yo)), Bool.not(Time.le(other_created(xo), other_created(yo))), Time.eq(other_created(xo), other_created(yo)), String.is_le(other_id(Edge{xi, xd, xk, xo, xg}), other_id(Edge{yi, yd, yk, yo, yg})))

# S4.180 (spec twin) the TEXT order: priority ascending, then `issue_id`, `depends_on_id` and the type, each ascending
def edge_le_text(x: Edge, y: Edge) -> Bool:
  match x y:
    case Edge{+xi, +xd, xk, +xo, xg} Edge{+yi, +yd, yk, +yo, yg}:
      ((other_rank(xo) < other_rank(yo) : U32) || (U32.is_eq(other_rank(xo), other_rank(yo)) && (String.is_lt(xi, yi) || (String.eq(xi, yi) && (String.is_lt(xd, yd) || (String.eq(xd, yd) && String.is_le(xk, yk)))))))

# S4.179 (spec twin) the rows of a direction: 0 down, 1 up, 2 both (down first); each half in the query order
def edges_of(+i: Model.Issue, +all: List<&2, Model.Issue>, direction: U32, +kind: String) -> List<&2, Edge>:
  match direction:
    case 0:
      List.sort(~Edge, ~edge_le_query, down_edges(Model.deps_of(i), all, kind))
    case 1:
      List.sort(~Edge, ~edge_le_query, up_edges(all, Model.id_of(i), kind))
    case _:
      List.append(&2, Edge, List.sort(~Edge, ~edge_le_query, down_edges(Model.deps_of(i), all, kind)), List.sort(~Edge, ~edge_le_query, up_edges(all, Model.id_of(i), kind)))

# S5.177 S5.151 (spec twin) the other end's title, priority and status; a missing end shows an empty title, priority 2 and
# `unknown` (OQ-122), except an `external:` end, which shows `⏳ {ref}` and `blocked` (OQ-045)
def other_title(other: Maybe<&2, Model.Issue>, +id: String) -> String:
  match other:
    case None{}:
      Bool.pick(String, String.starts_with(id, "external:"), "⏳ " ++ id, "")
    case Some{i}:
      Model.title_of(i)

# S5.177 (spec twin) the other end's priority digits
def other_priority(other: Maybe<&2, Model.Issue>) -> String:
  match other:
    case None{}:
      "2"
    case Some{i}:
      Model.priority_of(i)

# S5.177 S5.151 (spec twin) the other end's status
def other_status(other: Maybe<&2, Model.Issue>, +id: String) -> String:
  match other:
    case None{}:
      Bool.pick(String, String.starts_with(id, "external:"), "blocked", "unknown")
    case Some{i}:
      Model.status_of(i)

# S5.177 (spec twin) one text row: `  -> {other} ({type}): {title} [P{n}] [{status}]`, `<-` when the issue is the target
def edge_row(+oid: String, +kind: String, +other: Maybe<&2, Model.Issue>, outgoing: Bool) -> String:
  String.concat([Bool.pick(String, outgoing, "  -> ", "  <- "), Render.inline(oid), " (", Render.inline(kind), "): ", Render.inline(other_title(other, oid)), " [P", other_priority(other), "] [", Render.inline(other_status(other, oid)), "]\n"])

# S5.177 (spec twin) the text rows in order
def edge_lines(es: List<&2, Edge>) -> List<&2, String>:
  match es:
    case Nil{}:
      Nil{}
    case Con{Edge{issue_id, depends_on_id, +kind, +other, +outgoing}, rest}:
      edge_row(other_id(Edge{issue_id, depends_on_id, kind, other, outgoing}), kind, other, outgoing) <> edge_lines(rest)

# S5.46 (spec twin) one JSON row: six members in this order, all always present
def edge_objects(es: List<&2, Edge>, first: Bool) -> List<&2, String>:
  match es first:
    case Nil{} _:
      Nil{}
    case Con{Edge{issue_id, +depends_on_id, kind, +other, outgoing}, rest} lead:
      String.concat([Bool.pick(String, lead, "", ","), "{\"issue_id\":", Failure.quoted(issue_id), ",\"depends_on_id\":", Failure.quoted(depends_on_id), ",\"type\":", Failure.quoted(kind), ",\"title\":", Failure.quoted(other_title(other, depends_on_id)), ",\"status\":", Failure.quoted(other_status(other, depends_on_id)), ",\"priority\":", other_priority(other), "}"]) <> edge_objects(rest, False{})

# S5.176 S5.178 (spec twin) the noun phrase of a direction: `dependencies`, `dependents`, `dependencies or dependents`
# in the empty line; `Dependencies`, `Dependents`, `Dependencies and dependents` in the header
def direction_words(direction: U32, empty: Bool) -> String:
  match direction empty:
    case 0 True{}:
      "No dependencies for "
    case 1 True{}:
      "No dependents for "
    case _ True{}:
      "No dependencies or dependents for "
    case 0 False{}:
      "Dependencies of "
    case 1 False{}:
      "Dependents of "
    case _ False{}:
      "Dependencies and dependents of "

# S4.181 S5.176–S5.178 (spec twin) plain `dep list`: the header with the count and the rows in the TEXT order; one line when there are none
def dep_list_plain(+es: List<&2, Edge>, +id: String, +direction: U32) -> String:
  match es:
    case Nil{}:
      direction_words(direction, True{}) ++ Render.inline(id) ++ "\n"
    case Con{e, rest}:
      String.concat([direction_words(direction, False{}), Render.inline(id), " (", Nat.show(List.length(&2, Edge, es)), "):\n", String.concat(edge_lines(List.sort(~Edge, ~edge_le_text, es)))])

# S1.78 S4.179 (spec twin) the direction as a number: 0 down (the default), 1 up, 2 both
def direction_of(given: Maybe<&2, String>) -> U32:
  match given:
    case None{}:
      0
    case Some{+word}:
      Bool.pick(U32, String.eq(word, "up"), 1, Bool.pick(U32, String.eq(word, "both"), 2, 0))

# S4.41–S4.47 (data) the stored issue an input names, or the refusal
type Hit is Data:
  HitBad{failure: Failure.Failure}
  HitOk{issue: Model.Issue}

# S4.45 S4.47 (spec twin) a resolved id whose record is missing is "not found"
def hit_pick(found: Maybe<&2, Model.Issue>, id: String) -> Hit:
  match found:
    case None{}:
      HitBad{Resolve.not_found(id)}
    case Some{i}:
      HitOk{i}

# S4.45 (spec twin) the record of a resolved id
def hit_of(found: Resolve.Found, all: List<&2, Model.Issue>) -> Hit:
  match found:
    case Resolve.FoundBad{f}:
      HitBad{f}
    case Resolve.FoundOk{+id}:
      hit_pick(Blocked.lookup(all, id), id)

# S4.40–S4.47 (spec twin) the stored issue an input names
def hit(+all: List<&2, Model.Issue>, input: String, prefix: String) -> Hit:
  hit_of(Resolve.resolve(ids_of(all), input, prefix), all)

# S4.179–S4.181 S5.46 (spec twin) `dep list`: `kind` is the `--type` filter as the model spells types, "" for none
def dep_list(h: Hit, +all: List<&2, Model.Issue>, +direction: U32, kind: String, json: Bool) -> View:
  match h json:
    case HitBad{f} _:
      ViewBad{f}
    case HitOk{i} True{}:
      ViewOk{"[" ++ String.concat(edge_objects(edges_of(i, all, direction, kind), True{})) ++ "]\n"}
    case HitOk{+i} False{}:
      ViewOk{dep_list_plain(edges_of(i, all, direction, kind), Model.id_of(i), direction)}

# ---------------------------------------------------------------- dep tree (S4.182–S4.185, S5.47, S5.179)

# S4.184 (spec twin) the status rank that orders siblings after the priority:
# `open` 0, `in_progress` 1, `blocked` 2, `deferred` 3, `closed` 4, `deleted`/`tombstone` 5, anything else 6
def status_rank(+s: String) -> U32:
  Bool.pick(U32, String.eq(s, "open"), 0, Bool.pick(U32, String.eq(s, "in_progress"), 1, Bool.pick(U32, String.eq(s, "blocked"), 2, Bool.pick(U32, String.eq(s, "deferred"), 3, Bool.pick(U32, String.eq(s, "closed"), 4, Bool.pick(U32, (String.eq(s, "deleted") || String.eq(s, "tombstone")), 5, 6))))))

# S4.182 (spec twin) keep an id when the flag says so
def id_put(x: String, keep: Bool, rest: List<&2, String>) -> List<&2, String>:
  match keep:
    case True{}:
      x <> rest
    case False{}:
      rest

# S4.182 (spec twin) the ids an issue's own edges point at: the `down` adjacency. Edge type is ignored — every
# dependency type takes part in the tree
def down_ids(edges: List<&2, Model.Dependency>) -> List<&2, String>:
  match edges:
    case Nil{}:
      Nil{}
    case Con{+e, rest}:
      Model.target_of(e) <> down_ids(rest)

# S4.182 (spec twin) the ids of the records whose own edges point at `id`: the `up` adjacency
def up_ids(all: List<&2, Model.Issue>, +id: String) -> List<&2, String>:
  match all:
    case Nil{}:
      Nil{}
    case Con{+i, rest}:
      id_put(Model.id_of(i), Blocked.among(down_ids(Model.deps_of(i)), id), up_ids(rest, id))

# S4.182 (spec twin) an adjacency list is deduplicated: the first occurrence of each id survives
def dedup_ids(xs: List<&2, String>, +seen: List<&2, String>) -> List<&2, String>:
  match xs:
    case Nil{}:
      Nil{}
    case Con{+x, rest}:
      id_put(x, Bool.not(Blocked.among(seen, x)), dedup_ids(rest, x <> seen))

# S4.182 (spec twin) the neighbours of one stored record: 0 down, 1 up, 2 both (down first), deduplicated
def nb_of(found: Maybe<&2, Model.Issue>, +all: List<&2, Model.Issue>, direction: U32) -> List<&2, String>:
  match found direction:
    case None{} _:
      Nil{}
    case Some{+i} 0:
      dedup_ids(down_ids(Model.deps_of(i)), Nil{})
    case Some{+i} 1:
      dedup_ids(up_ids(all, Model.id_of(i)), Nil{})
    case Some{+i} _:
      dedup_ids(List.append(&2, String, down_ids(Model.deps_of(i)), up_ids(all, Model.id_of(i))), Nil{})

# S4.182 (spec twin) the neighbours of an id; an id with no stored record has none, so it is never expanded
def nb_ids(+all: List<&2, Model.Issue>, +id: String, direction: U32) -> List<&2, String>:
  nb_of(Blocked.lookup(all, id), all, direction)

# S4.185 (spec twin) has the id a neighbour at all in the chosen direction
def has_nb(+all: List<&2, Model.Issue>, +id: String, direction: U32) -> Bool:
  Bool.not(List.is_empty(&2, String, nb_ids(all, id, direction)))

# S4.185 (spec twin) is the id stored (an `external:` node is not, and is never expanded)
def stored(found: Maybe<&2, Model.Issue>) -> Bool:
  match found:
    case None{}:
      False{}
    case Some{i}:
      True{}

# S4.185 (spec twin) a node expands when its depth is below `--max-depth`, its id has not expanded anywhere
# else in this traversal, and it is stored
def expands(+all: List<&2, Model.Issue>, +id: String, depth: Nat, max_depth: Nat, +expanded: List<&2, String>) -> Bool:
  ((Nat.is_lt(depth, max_depth) && Bool.not(Blocked.among(expanded, id))) && stored(Blocked.lookup(all, id)))

# S4.185 (data) one sibling with the four keys that order it
type Kid is Data:
  Kid{id: String, rank: U32, srank: U32, title: String}

# S4.184 (spec twin) a neighbour with its sort keys; a node with no stored record ranks last on both ranks
def kid_of(found: Maybe<&2, Model.Issue>, +id: String) -> Kid:
  match found:
    case None{}:
      Kid{id, 256, 6, ""}
    case Some{+i}:
      Kid{id, Query.priority_number(Model.priority_of(i)), status_rank(Model.status_of(i)), Model.title_of(i)}

# S4.184 (spec twin) the neighbours as sortable siblings
def kids_of(ids: List<&2, String>, +all: List<&2, Model.Issue>) -> List<&2, Kid>:
  match ids:
    case Nil{}:
      Nil{}
    case Con{+x, rest}:
      kid_of(Blocked.lookup(all, x), x) <> kids_of(rest, all)

# S4.184 (spec twin) siblings: the target's priority ascending, then the status rank, then the title, then the
# id, each ascending
def kid_le(x: Kid, y: Kid) -> Bool:
  match x y:
    case Kid{+xi, +xr, +xs, +xt} Kid{+yi, +yr, +ys, +yt}:
      ((xr < yr : U32) || (U32.is_eq(xr, yr) && (((xs < ys : U32) || (U32.is_eq(xs, ys) && (String.is_lt(xt, yt) || (String.eq(xt, yt) && String.is_le(xi, yi))))))))

# S4.183 (data) one pending step of the walk: the id to emit, its depth, its parent's id, its ancestor path
type Step is Data:
  Step{id: String, depth: Nat, parent: String, path: List<&2, String>}

# S4.185 (spec twin) drop the neighbours already on this node's ancestor path: that, not the fuel, is what ends a cycle
def not_ancestors(xs: List<&2, String>, +path: List<&2, String>) -> List<&2, String>:
  match xs:
    case Nil{}:
      Nil{}
    case Con{+x, rest}:
      id_put(x, Bool.not(Blocked.among(path, x)), not_ancestors(rest, path))

# S4.183 (spec twin) the siblings as steps, all at the same depth and under the same parent
def kid_steps(kids: List<&2, Kid>, +depth: Nat, +parent: String, +path: List<&2, String>) -> List<&2, Step>:
  match kids:
    case Nil{}:
      Nil{}
    case Con{Kid{kid, r, s, t}, rest}:
      Step{kid, depth, parent, path} <> kid_steps(rest, depth, parent, path)

# S4.184 S4.185 (spec twin) the steps below a node: its neighbours in sibling order with the ancestors dropped,
# and nothing at all when the node does not expand
def steps_below(expand: Bool, +all: List<&2, Model.Issue>, +id: String, depth: Nat, +path: List<&2, String>, direction: U32) -> List<&2, Step>:
  match expand:
    case False{}:
      Nil{}
    case True{}:
      kid_steps(List.sort(~Kid, ~kid_le, kids_of(not_ancestors(nb_ids(all, id, direction), id <> path), all)), (1n + depth : Nat), id, id <> path)

# S4.185 (spec twin) the expansion slot is claimed only by an occurrence that really expands
def mark_id(expand: Bool, id: String, expanded: List<&2, String>) -> List<&2, String>:
  match expand:
    case True{}:
      id <> expanded
    case False{}:
      expanded

# S4.185 (data) one emitted node of the tree, in pre-order. `cut` is the `truncated` member and `again` the
# `repeat` member of S5.47
type TNode is Data:
  TNode{id: String, title: String, depth: Nat, parent: String, priority: String, status: String, cut: Bool, again: Bool}

# S4.183 S5.47 (spec twin) the emitted node; a neighbour with no stored record shows an empty title, priority 2
# and `unknown`, as `dep list` does for a missing end, and an `external:` one `⏳ {ref}` and `blocked`
def tnode_of(found: Maybe<&2, Model.Issue>, +id: String, depth: Nat, parent: String, cut: Bool, again: Bool) -> TNode:
  match found:
    case None{}:
      TNode{id, other_title(None{}, id), depth, parent, "2", other_status(None{}, id), cut, again}
    case Some{+i}:
      TNode{id, Model.title_of(i), depth, parent, Model.priority_of(i), Model.status_of(i), cut, again}

# S4.183 S4.185 (spec twin) the pre-order walk: pop a step, emit its node, push its children in front of the
# rest. `truncated` is "did not expand although it has neighbours"; `repeat` is "its id had already expanded
# and it has neighbours"; the two are independent and a node carries both when both hold
def tree_walk(fuel: Nat, stack: List<&2, Step>, +expanded: List<&2, String>, +all: List<&2, Model.Issue>, +direction: U32, +max_depth: Nat) -> List<&2, TNode>:
  match fuel stack:
    case Zero{} _:
      Nil{}
    case Succ{f} Nil{}:
      Nil{}
    case Succ{f} Con{Step{+id, +depth, parent, path}, rest}:
      tnode_of(Blocked.lookup(all, id), id, depth, parent, (Bool.not(expands(all, id, depth, max_depth, expanded)) && has_nb(all, id, direction)), (Blocked.among(expanded, id) && has_nb(all, id, direction))) <> tree_walk(f, List.append(&2, Step, steps_below(expands(all, id, depth, max_depth, expanded), all, id, depth, path, direction), rest), mark_id(expands(all, id, depth, max_depth, expanded), id, expanded), all, direction, max_depth)

# S4.185 (spec twin) every dependency of the store, as the measure the walk's fuel is built from
def all_deps(issues: List<&2, Model.Issue>) -> List<&2, String>:
  match issues:
    case Nil{}:
      Nil{}
    case Con{+i, rest}:
      List.append(&2, String, down_ids(Model.deps_of(i)), all_deps(rest))

# S4.185 (spec twin) the fuel: one unit per issue, two per stored dependency (a `both` walk may reach an edge
# from either end) and one for the root. Each id expands at most once, and only an expanded node pushes, so
# the walk cannot emit more nodes than that
def tree_fuel(+all: List<&2, Model.Issue>) -> Nat:
  Nat.add(Nat.add(List.length(&2, Model.Issue, all), Nat.double(List.length(&2, String, all_deps(all)))), 1n)

# S5.179 (spec twin) the prefix of one plain row: nothing at the root, `├── (truncated) ` when the subtree was
# cut off, `├── (shown above) ` when the node repeats an already-expanded one, `├── ` otherwise. `└──` is
# never used by this renderer, and `truncated` wins when a node carries both flags
def tree_prefix(root: Bool, cut: Bool, again: Bool) -> String:
  match root cut again:
    case True{} _ _:
      ""
    case False{} True{} _:
      "├── (truncated) "
    case False{} False{} True{}:
      "├── (shown above) "
    case False{} False{} False{}:
      "├── "

# S5.179 (spec twin) one plain row: two spaces of indent per depth level, the prefix, then the node
def tree_lines(ns: List<&2, TNode>) -> List<&2, String>:
  match ns:
    case Nil{}:
      Nil{}
    case Con{TNode{+id, +title, +depth, parent, +priority, +status, +cut, +again}, rest}:
      String.concat([String.repeat("  ", depth), tree_prefix(Nat.is_eq(depth, 0n), cut, again), Render.inline(id), ": ", Render.inline(title), " [P", priority, "] [", Render.inline(status), "]\n"]) <> tree_lines(rest)

# S5.47 (spec twin) one JSON node: eight members in this order, all always present, `parent_id` null at the root
def tree_objects(ns: List<&2, TNode>, first: Bool) -> List<&2, String>:
  match ns first:
    case Nil{} _:
      Nil{}
    case Con{TNode{+id, +title, +depth, +parent, +priority, +status, +cut, +again}, rest} lead:
      String.concat([Bool.pick(String, lead, "", ","), "{\"id\":", Failure.quoted(id), ",\"title\":", Failure.quoted(title), ",\"depth\":", Nat.show(depth), ",\"parent_id\":", Bool.pick(String, String.is_empty(parent), "null", Failure.quoted(parent)), ",\"priority\":", priority, ",\"status\":", Failure.quoted(status), ",\"truncated\":", Bool.pick(String, cut, "true", "false"), ",\"repeat\":", Bool.pick(String, again, "true", "false"), "}"]) <> tree_objects(rest, False{})

# S5.253 (spec twin) `"` becomes `'` in a mermaid label; every other character is kept
def mermaid_quote(s: String) -> String:
  match s:
    case SNil{}:
      ""
    case SCon{Chr{+c}, rest}:
      SCon{Chr{Bool.pick(U32, U32.is_eq(c, 34), 39, c)}, mermaid_quote(rest)}

# S5.253 (spec twin) the node lines, `    n{k}["{id}: {title} [P{n}]"]`, with k counting the pre-order from 0
def mermaid_nodes(ns: List<&2, TNode>, +k: Nat) -> List<&2, String>:
  match ns:
    case Nil{}:
      Nil{}
    case Con{TNode{id, title, depth, parent, priority, status, cut, again}, rest}:
      String.concat(["    n", Nat.show(k), "[\"", mermaid_quote(String.concat([Render.inline(id), ": ", Render.inline(title), " [P", priority, "]"])), "\"]\n"]) <> mermaid_nodes(rest, (1n + k : Nat))

# S5.253 (data) an emitted node's depth and its place in the pre-order
type Seen is Data:
  Seen{depth: Nat, index: Nat}

# S5.253 (spec twin) the place of the latest emitted node at depth `want` (`seen` is most recent first): in a
# pre-order listing that node is the parent of the next node one level deeper
def seen_at(seen: List<&2, Seen>, +want: Nat) -> Nat:
  match seen:
    case Nil{}:
      0n
    case Con{Seen{d, k}, rest}:
      Bool.pick(Nat, Nat.is_eq(d, want), k, seen_at(rest, want))

# S5.253 (spec twin) the edge line into node k at `depth`: none for the root, `    n{parent} --> n{k}` below it
def mermaid_edge(depth: Nat, +seen: List<&2, Seen>, +k: Nat) -> String:
  match depth:
    case Zero{}:
      ""
    case Succ{p}:
      String.concat(["    n", Nat.show(seen_at(seen, p)), " --> n", Nat.show(k), "\n"])

# S5.253 (spec twin) the edge lines, in the order of the nodes they lead into
def mermaid_edges(ns: List<&2, TNode>, +k: Nat, +seen: List<&2, Seen>) -> List<&2, String>:
  match ns:
    case Nil{}:
      Nil{}
    case Con{TNode{id, title, +depth, parent, priority, status, cut, again}, rest}:
      mermaid_edge(depth, seen, k) <> mermaid_edges(rest, (1n + k : Nat), Seen{depth, k} <> seen)

# S5.253 (spec twin) the mermaid rendering: `graph TD`, every node, then every edge. No status and no
# `truncated`/`repeat` mark: a repeated node is simply a node of its own
def tree_mermaid(+ns: List<&2, TNode>) -> String:
  String.concat(["graph TD\n", String.concat(mermaid_nodes(ns, 0n)), String.concat(mermaid_edges(ns, 0n, Nil{}))])

# S4.394 (spec twin) `--format` selects mermaid when it is `mermaid` in any ASCII case; any other value is text
def mermaid_of(given: Maybe<&2, String>) -> Bool:
  match given:
    case None{}:
      False{}
    case Some{word}:
      String.eq(Resolve.lowered(word), "mermaid")

# S4.183 (spec twin) `--max-depth` defaults to 10; the parser has already held the value to an unsigned integer
def max_depth_of(given: Maybe<&2, String>) -> Nat:
  match given:
    case None{}:
      10n
    case Some{+word}:
      U32.to_nat(Maybe.default(&2, U32, U32.read(word), 0))

# S4.182–S4.185 S4.394 S5.47 S5.179 S5.253 (spec twin) `dep tree`: the pre-order walk from the root, rendered
# as JSON (which `--format` does not change), as mermaid, or as text
def dep_tree(h: Hit, +all: List<&2, Model.Issue>, direction: U32, json: Bool, max_depth: Nat, mermaid: Bool) -> View:
  match h json mermaid:
    case HitBad{f} _ _:
      ViewBad{f}
    case HitOk{+i} True{} _:
      ViewOk{"[" ++ String.concat(tree_objects(tree_walk(tree_fuel(all), Step{Model.id_of(i), 0n, "", Nil{}} <> Nil{}, Nil{}, all, direction, max_depth), True{})) ++ "]\n"}
    case HitOk{+i} False{} True{}:
      ViewOk{tree_mermaid(tree_walk(tree_fuel(all), Step{Model.id_of(i), 0n, "", Nil{}} <> Nil{}, Nil{}, all, direction, max_depth))}
    case HitOk{+i} False{} False{}:
      ViewOk{String.concat(tree_lines(tree_walk(tree_fuel(all), Step{Model.id_of(i), 0n, "", Nil{}} <> Nil{}, Nil{}, all, direction, max_depth)))}

# ---------------------------------------------------------------- dep cycles (S4.186–S4.188, S5.48, S5.181)

# S4.186 (data) one edge of the cycle graph
type Arc is Data:
  Arc{from: String, to: String}

# S4.186 (spec twin) one edge as an arc of the cycle graph, when its type takes part
def arc_put(source: String, target: String, blocks: Bool, parent_child: Bool, rest: List<&2, Arc>) -> List<&2, Arc>:
  match blocks parent_child:
    case True{} _:
      Arc{source, target} <> rest
    case False{} True{}:
      Arc{target, source} <> rest
    case False{} False{}:
      rest

# S4.186 (spec twin) the arcs of one issue: a blocking edge runs source→target, a `parent-child` edge runs REVERSED, parent→child
def arcs_of(edges: List<&2, Model.Dependency>, +source: String) -> List<&2, Arc>:
  match edges:
    case Nil{}:
      Nil{}
    case Con{+e, rest}:
      arc_put(source, Model.target_of(e), Blocked.blocking(Model.dep_type_of(e)), String.eq(Model.dep_type_of(e), "parent-child"), arcs_of(rest, source))

# S4.186 (spec twin) every arc of the store
def arcs(issues: List<&2, Model.Issue>) -> List<&2, Arc>:
  match issues:
    case Nil{}:
      Nil{}
    case Con{+i, rest}:
      List.append(&2, Arc, arcs_of(Model.deps_of(i), Model.id_of(i)), arcs(rest))

# S4.187 (spec twin) does a node have an arc to a node that is still in play
def has_way(ways: List<&2, Arc>, +node: String, +alive: List<&2, String>) -> Bool:
  match ways:
    case Nil{}:
      False{}
    case Con{Arc{from, to}, rest}:
      ((String.eq(from, node) && Blocked.among(alive, to)) || has_way(rest, node, alive))

# S4.187 (spec twin) keep a node that still has a way on
def node_put(n: String, keep: Bool, rest: List<&2, String>) -> List<&2, String>:
  match keep:
    case True{}:
      n <> rest
    case False{}:
      rest

# S4.187 (spec twin) the nodes that still have a way on; `alive` is the set they are judged against
def pruned(nodes: List<&2, String>, +ways: List<&2, Arc>, +alive: List<&2, String>) -> List<&2, String>:
  match nodes:
    case Nil{}:
      Nil{}
    case Con{+n, rest}:
      node_put(n, has_way(ways, n, alive), pruned(rest, ways, alive))

# S4.187 (spec twin) drop dead ends until nothing changes: what is left lies on or leads into a cycle. One unit of fuel per round
def cyclic_core(fuel: Nat, +nodes: List<&2, String>, +ways: List<&2, Arc>) -> List<&2, String>:
  match fuel:
    case 0n:
      nodes
    case 1n+g:
      cyclic_core(g, pruned(nodes, ways, nodes), ways)

# S4.186 (spec twin) the sources of the arcs: only a node with an arc out can lie on a cycle
def sources(ways: List<&2, Arc>) -> List<&2, String>:
  match ways:
    case Nil{}:
      Nil{}
    case Con{Arc{from, to}, rest}:
      from <> sources(rest)

# S4.187 (spec twin) keep an arc's target when the arc leaves `node` and lands in `within`
def succ_put(keep: Bool, to: String, acc: List<&2, String>) -> List<&2, String>:
  match keep:
    case True{}:
      to <> acc
    case False{}:
      acc

# S4.187 (spec twin) the targets of `node`'s arcs that lie in `within`, onto acc
def succ_go(ways: List<&2, Arc>, +node: String, +within: List<&2, String>, acc: List<&2, String>) -> List<&2, String>:
  match ways:
    case Nil{}:
      acc
    case Con{Arc{from, +to}, rest}:
      succ_go(rest, node, within, succ_put((String.eq(from, node) && Blocked.among(within, to)), to, acc))

# S4.186 S4.187 (spec twin) a node's neighbours inside a set, sorted ascending and without repeats (S4.186: every
# adjacency list is sorted and deduplicated)
def succ(+ways: List<&2, Arc>, +node: String, +within: List<&2, String>) -> List<&2, String>:
  Model.dedup(List.sort(~String, ~String.is_le, succ_go(ways, node, within, Nil{})))

# S4.187 (spec twin) the neighbours of every node of a list, onto acc
def succs_all(nodes: List<&2, String>, +ways: List<&2, Arc>, +within: List<&2, String>, acc: List<&2, String>) -> List<&2, String>:
  match nodes:
    case Nil{}:
      acc
    case Con{+n, rest}:
      succs_all(rest, ways, within, List.append(&2, String, succ(ways, n, within), acc))

# S4.187 (spec twin) grow a reached set by one step per unit of fuel (the set's size bounds the steps it needs)
def reach_go(fuel: Nat, +ways: List<&2, Arc>, +within: List<&2, String>, +seen: List<&2, String>) -> List<&2, String>:
  match fuel:
    case 0n:
      seen
    case 1n+g:
      reach_go(g, ways, within, Model.dedup(List.sort(~String, ~String.is_le, succs_all(seen, ways, within, seen))))

# S4.187 (spec twin) the nodes of `within` reachable from `start` in one step or more (`start` itself only on a cycle)
def reach(+ways: List<&2, Arc>, +within: List<&2, String>, +start: String) -> List<&2, String>:
  reach_go(Nat.add(List.length(&2, String, within), 1n), ways, within, succ(ways, start, within))

# S4.187 (spec twin) keep a node of the start's reach that reaches the start back
def mutual_put(keep: Bool, m: String, acc: List<&2, String>) -> List<&2, String>:
  match keep:
    case True{}:
      m <> acc
    case False{}:
      acc

# S4.187 (spec twin) the members of the start's strongly connected component other than itself
def mutual(ms: List<&2, String>, +ways: List<&2, Arc>, +within: List<&2, String>, +start: String, acc: List<&2, String>) -> List<&2, String>:
  match ms:
    case Nil{}:
      acc
    case Con{+m, rest}:
      mutual(rest, ways, within, start, mutual_put((Bool.not(String.eq(m, start)) && Blocked.among(reach(ways, within, m), start)), m, acc))

# S4.187 (data) one frame of the witness walk: a node and the neighbours still to try
type Frame is Data:
  Frame{node: String, todo: List<&2, String>}

# S4.187 (data) the witness walk: its frames (innermost first), the nodes entered, and whether the start was reached
type Walk is Data:
  Walk{frames: List<&2, Frame>, seen: List<&2, String>, found: Bool}

# S4.187 (spec twin) one neighbour tried: the start ends the walk; a node already entered is passed over; any other is
# entered with its own sorted neighbours
def walk_try(home: Bool, entered: Bool, +t: String, node: String, more: List<&2, String>, below: List<&2, Frame>, seen: List<&2, String>, +ways: List<&2, Arc>, +comp: List<&2, String>) -> Walk:
  match home entered:
    case True{} _:
      Walk{Frame{node, more} <> below, seen, True{}}
    case False{} True{}:
      Walk{Frame{node, more} <> below, seen, False{}}
    case False{} False{}:
      Walk{Frame{t, succ(ways, t, comp)} <> (Frame{node, more} <> below), t <> seen, False{}}

# S4.187 (spec twin) the top frame: no neighbour left pops it (backtracking); otherwise its next neighbour is tried
def walk_top(frames: List<&2, Frame>, +seen: List<&2, String>, +ways: List<&2, Arc>, +comp: List<&2, String>, +start: String) -> Walk:
  match frames:
    case Nil{}:
      Walk{Nil{}, seen, False{}}
    case Con{Frame{node, Nil{}}, below}:
      Walk{below, seen, False{}}
    case Con{Frame{node, Con{+t, more}}, below}:
      walk_try(String.eq(t, start), Blocked.among(seen, t), t, node, more, below, seen, ways, comp)

# S4.187 (spec twin) one step of the walk; a finished walk stays as it is
def walk_step(w: Walk, +ways: List<&2, Arc>, +comp: List<&2, String>, +start: String) -> Walk:
  match w:
    case Walk{frames, seen, True{}}:
      Walk{frames, seen, True{}}
    case Walk{frames, seen, False{}}:
      walk_top(frames, seen, ways, comp, start)

# S4.187 (spec twin) the walk, one unit of fuel per step (each step pops a frame or tries one arc)
def walk_go(fuel: Nat, +ways: List<&2, Arc>, +comp: List<&2, String>, +start: String, w: Walk) -> Walk:
  match fuel:
    case 0n:
      w
    case 1n+g:
      walk_go(g, ways, comp, start, walk_step(w, ways, comp, start))

# S4.187 (spec twin) the frames' nodes, outermost first, onto acc
def frame_nodes(frames: List<&2, Frame>, acc: List<&2, String>) -> List<&2, String>:
  match frames:
    case Nil{}:
      acc
    case Con{Frame{node, todo}, below}:
      frame_nodes(below, node <> acc)

# S4.187 (spec twin) the witness of a walk that reached the start: the start, the path, the start again
def walk_witness(w: Walk, +start: String) -> List<&2, String>:
  match w:
    case Walk{frames, seen, found}:
      start <> List.append(&2, String, frame_nodes(frames, Nil{}), [start])

# S4.187 (spec twin) the first neighbour of the start that is not the start itself
def first_other(ns: List<&2, String>, +start: String) -> Maybe<&2, String>:
  match ns:
    case Nil{}:
      None{}
    case Con{+n, rest}:
      Bool.pick(Maybe<&2, String>, String.eq(n, start), first_other(rest, start), Some{n})

# S4.187 (spec twin) the walk from the start's first other neighbour back to the start, depth first over sorted
# neighbours with backtracking: `path` (a→b; b→c, b→d; c→e→a; d→a) gives a b c e a, not the shorter a b d a
def walk_from(first: Maybe<&2, String>, +ways: List<&2, Arc>, +comp: List<&2, String>, +start: String) -> List<&2, String>:
  match first:
    case None{}:
      [start, start]
    case Some{+u}:
      walk_witness(walk_go(Nat.mul(Nat.add(Nat.add(List.length(&2, Arc, ways), List.length(&2, String, comp)), 1n), 2n), ways, comp, start, Walk{Frame{u, succ(ways, u, comp)} <> Nil{}, [u], False{}}), start)

# S4.188 (spec twin) a member counts as closed when it is a stored record whose status is `closed` or `tombstone`
def closed_member(found: Maybe<&2, Model.Issue>) -> Bool:
  match found:
    case None{}:
      False{}
    case Some{+i}:
      (String.eq(Model.status_of(i), "closed") || String.eq(Model.status_of(i), "tombstone"))

# S4.188 (spec twin) every member closed: the component is archived
def all_closed(ms: List<&2, String>, +all: List<&2, Model.Issue>) -> Bool:
  match ms:
    case Nil{}:
      True{}
    case Con{+m, rest}:
      (closed_member(Blocked.lookup(all, m)) && all_closed(rest, all))

# S4.187 S4.188 (data) one reported cycle: its witness, and whether its component is archived
type Wit is Data:
  Wit{ids: List<&2, String>, archived: Bool}

# S4.187 (data) the component search: the nodes already placed and the witnesses so far (REVERSED)
type Comps is Data:
  Comps{done: List<&2, String>, wits: List<&2, Wit>}

# S4.187 (spec twin) a component's report: one node reports only on a self-edge (`[id, id]`); a larger one reports the
# walk from its lowest id, which is `n` because the nodes are visited in ascending order and a smaller member would
# have placed `n` already. `members` is the whole component, `n` included
def comp_wits(single: Bool, self_edge: Bool, +n: String, +members: List<&2, String>, +ways: List<&2, Arc>, +all: List<&2, Model.Issue>, wits: List<&2, Wit>) -> List<&2, Wit>:
  match single self_edge:
    case True{} True{}:
      Wit{[n, n], all_closed([n], all)} <> wits
    case True{} False{}:
      wits
    case False{} _:
      Wit{walk_from(first_other(succ(ways, n, members), n), ways, members, n), all_closed(members, all)} <> wits

# S4.187 (spec twin) a node's component: itself and the nodes of its reach that reach it back
def comp_of(+n: String, +ways: List<&2, Arc>, +within: List<&2, String>) -> List<&2, String>:
  n <> mutual(reach(ways, within, n), ways, within, n, Nil{})

# S4.187 (spec twin) one node: a node already placed is passed over; otherwise its component is found and reported
def comp_step(placed: Bool, +n: String, +ways: List<&2, Arc>, +within: List<&2, String>, +all: List<&2, Model.Issue>, c: Comps) -> Comps:
  match placed:
    case True{}:
      c
    case False{}:
      match c:
        case Comps{done, wits}:
          Comps{List.append(&2, String, comp_of(n, ways, within), done), comp_wits(Nat.is_eq(List.length(&2, String, comp_of(n, ways, within)), 1n), Blocked.among(reach(ways, within, n), n), n, comp_of(n, ways, within), ways, all, wits)}

# S4.187 (spec twin) is a node placed in a component already
def comps_done(c: Comps, +n: String) -> Bool:
  match c:
    case Comps{done, wits}:
      Blocked.among(done, n)

# S4.187 (spec twin) the components over the nodes in ascending order; the witnesses come out REVERSED
def comps_go(nodes: List<&2, String>, +ways: List<&2, Arc>, +within: List<&2, String>, +all: List<&2, Model.Issue>, +c: Comps) -> Comps:
  match nodes:
    case Nil{}:
      c
    case Con{+n, rest}:
      comps_go(rest, ways, within, all, comp_step(comps_done(c, n), n, ways, within, all, c))

# S5.48 (spec twin) ids as JSON strings joined by commas, REVERSED onto acc
def ids_json_go(ids: List<&2, String>, acc: List<&2, String>) -> List<&2, String>:
  match ids:
    case Nil{}:
      acc
    case Con{id, rest}:
      ids_json_go(rest, Failure.quoted(id) <> acc)

# S5.48 S5.182 (spec twin) a witness as a JSON array
def wit_json(ids: List<&2, String>) -> String:
  "[" ++ String.join(List.reverse(&2, String, ids_json_go(ids, Nil{})), ",") ++ "]"

# S5.48 (spec twin) the witnesses as one JSON array
def wits_json(ws: List<&2, Wit>, acc: List<&2, String>) -> String:
  match ws:
    case Nil{}:
      "[" ++ String.join(List.reverse(&2, String, acc), ",") ++ "]"
    case Con{Wit{ids, archived}, rest}:
      wits_json(rest, wit_json(ids) <> acc)

# S5.182 (spec twin) the numbered lines, `  {i}. {id -> id -> …}`
def wit_lines(ws: List<&2, Wit>, +i: U32, acc: String) -> String:
  match ws:
    case Nil{}:
      acc
    case Con{Wit{ids, archived}, rest}:
      wit_lines(rest, (i + 1 : U32), acc ++ "  " ++ U32.show(i) ++ ". " ++ String.join(ids, " -> ") ++ "\n")

# S4.188 (spec twin) keep a witness of the wanted kind
def kind_put(keep: Bool, w: Wit, acc: List<&2, Wit>) -> List<&2, Wit>:
  match keep:
    case True{}:
      w <> acc
    case False{}:
      acc

# S4.188 (spec twin) the witnesses of one kind, REVERSED onto acc
def kind_go(ws: List<&2, Wit>, +archived: Bool, acc: List<&2, Wit>) -> List<&2, Wit>:
  match ws:
    case Nil{}:
      acc
    case Con{Wit{ids, +a}, rest}:
      kind_go(rest, archived, kind_put(((a && archived) || (Bool.not(a) && Bool.not(archived))), Wit{ids, a}, acc))

# S4.188 (spec twin) the witnesses of one kind, in order
def wits_kind(ws: List<&2, Wit>, +archived: Bool) -> List<&2, Wit>:
  List.reverse(&2, Wit, kind_go(ws, archived, Nil{}))

# S5.48 (spec twin) an extra member, emitted only when its list is not empty
def wits_member(+key: String, ws: List<&2, Wit>) -> String:
  match ws:
    case Nil{}:
      ""
    case Con{w, rest}:
      ",\"" ++ key ++ "\":" ++ wits_json(w <> rest, Nil{})

# S5.48 S4.188 (spec twin) the JSON object: the shown cycles, the four counts, both flags, the scope, and under
# `--include-closed` the two kind lists when not empty (never without it)
def cycles_json(+shown: List<&2, Wit>, +active: List<&2, Wit>, +archived: List<&2, Wit>, blocking_only: Bool, +include_closed: Bool) -> String:
  String.concat(["{\"cycles\":", wits_json(shown, Nil{}), ",\"count\":", Nat.show(List.length(&2, Wit, shown)), ",\"active_count\":", Nat.show(List.length(&2, Wit, active)), ",\"archived_closed_count\":", Nat.show(List.length(&2, Wit, archived)), ",\"total_count\":", Nat.show(Nat.add(List.length(&2, Wit, active), List.length(&2, Wit, archived))), ",\"blocking_only\":", Failure.bool_text(blocking_only), ",\"include_closed\":", Failure.bool_text(include_closed), ",\"scope\":", Bool.pick(String, include_closed, "\"active_and_archived\"", "\"active\""), Bool.pick(String, include_closed, wits_member("active_cycles", active) ++ wits_member("archived_closed_cycles", archived), ""), "}\n"])

# S5.181 S5.182 (spec twin) the text: the numbered lines with the `Warning:` count on stderr; with nothing shown, the
# line for hidden archived cycles or the plain "no cycles" line (`blocking dependency` under `--blocking-only`)
def cycles_text(+shown: List<&2, Wit>, +hidden: Nat, +noun: String) -> View:
  match shown:
    case Nil{}:
      ViewOk{Bool.pick(String, Nat.is_gt(hidden, 0n), "✓ No active " ++ noun ++ " cycles detected. " ++ Nat.show(hidden) ++ " archived closed-only cycle(s) hidden; rerun with --include-closed to inspect them.\n", "✓ No " ++ noun ++ " cycles detected.\n")}
    case Con{w, rest}:
      ViewCode{wit_lines(w <> rest, 1, ""), "Warning: Found " ++ Nat.show(List.length(&2, Wit, w <> rest)) ++ " " ++ noun ++ " cycle(s):\n", 0}

# S4.188 (spec twin) an active cycle sets exit code 5 after the output; archived-only cycles never do
def with_code(v: View, active: Bool) -> View:
  match v active:
    case ViewOk{out} True{}:
      ViewCode{out, "", 5}
    case ViewCode{out, err, code} True{}:
      ViewCode{out, err, 5}
    case other _:
      other

# S4.187 S4.188 S5.48 S5.181 S5.182 (spec twin) the report over the witnesses in ascending order
def cycles_view(+ws: List<&2, Wit>, +blocking_only: Bool, +include_closed: Bool, json: Bool) -> View:
  match json:
    case True{}:
      with_code(ViewOk{cycles_json(Bool.pick(List<&2, Wit>, include_closed, ws, wits_kind(ws, False{})), wits_kind(ws, False{}), wits_kind(ws, True{}), blocking_only, include_closed)}, Nat.is_gt(List.length(&2, Wit, wits_kind(ws, False{})), 0n))
    case False{}:
      with_code(cycles_text(Bool.pick(List<&2, Wit>, include_closed, ws, wits_kind(ws, False{})), Bool.pick(Nat, include_closed, 0n, List.length(&2, Wit, wits_kind(ws, True{}))), Bool.pick(String, blocking_only, "blocking dependency", "dependency")), Nat.is_gt(List.length(&2, Wit, wits_kind(ws, False{})), 0n))

# ---------------------------------------------------------------- labels (S5.50, S5.185–S5.188)

# S5.185 (spec twin) one label per line, two spaces before each
def label_lines(labels: List<&2, String>) -> List<&2, String>:
  match labels:
    case Nil{}:
      Nil{}
    case Con{l, rest}:
      ("  " ++ Render.inline(l) ++ "\n") <> label_lines(rest)

# S5.50 S5.185 S5.186 (spec twin) `label list <id>`: the issue's labels in the model's sorted order
def label_list(h: Hit, json: Bool) -> View:
  match h json:
    case HitBad{f} _:
      ViewBad{f}
    case HitOk{i} True{}:
      ViewOk{"[" ++ Model.strings_text(Model.labels_of(i)) ++ "]\n"}
    case HitOk{+i} False{}:
      ViewOk{Bool.pick(String, List.is_empty(&2, String, Model.labels_of(i)), "No labels for " ++ Render.inline(Model.id_of(i)) ++ ".\n", "Labels for " ++ Render.inline(Model.id_of(i)) ++ ":\n" ++ String.concat(label_lines(Model.labels_of(i))))}

# S5.187 (spec twin) every label of every issue, counted; the tally keeps ascending byte order
def label_tally(issues: List<&2, Model.Issue>, groups: List<&2, Query.Group>) -> List<&2, Query.Group>:
  match issues:
    case Nil{}:
      groups
    case Con{i, rest}:
      label_tally(rest, Query.tally_keys(Model.labels_of(i), groups))

# S5.187 (spec twin) `  {label} ({n} issue)` at one, `issues` otherwise
def label_count_lines(groups: List<&2, Query.Group>) -> List<&2, String>:
  match groups:
    case Nil{}:
      Nil{}
    case Con{Query.Group{key, +count}, rest}:
      String.concat(["  ", Render.inline(key), " (", U32.show(count), Bool.pick(String, U32.is_eq(count, 1), " issue)\n", " issues)\n")]) <> label_count_lines(rest)

# S5.50 (spec twin) the label counts as JSON objects `{"label":…,"count":…}`
def label_count_objects(groups: List<&2, Query.Group>, first: Bool) -> List<&2, String>:
  match groups first:
    case Nil{} _:
      Nil{}
    case Con{Query.Group{key, count}, rest} lead:
      String.concat([Bool.pick(String, lead, "", ","), "{\"label\":", Failure.quoted(key), ",\"count\":", U32.show(count), "}"]) <> label_count_objects(rest, False{})

# S5.50 S5.187 S5.188 (spec twin) `label list-all`, and `label list` without an id
def label_counts(+groups: List<&2, Query.Group>, json: Bool) -> View:
  match json:
    case True{}:
      ViewOk{"[" ++ String.concat(label_count_objects(groups, True{})) ++ "]\n"}
    case False{}:
      ViewOk{Bool.pick(String, List.is_empty(&2, Query.Group, groups), "No labels in project.\n", "Labels (" ++ Nat.show(List.length(&2, Query.Group, groups)) ++ " total):\n" ++ String.concat(label_count_lines(groups)))}

# S5.187 (spec twin) `label list-all`
def label_list_all(all: List<&2, Model.Issue>, json: Bool) -> View:
  label_counts(label_tally(all, Nil{}), json)

# S5.185 (data) the two renderings of the names
type Names is Data:
  Names{lines: List<&2, String>, strs: List<&2, String>}

# S5.185 (spec twin) the label names of a tally, as text lines (two spaces before each) and as JSON strings, REVERSED
def name_lines(groups: List<&2, Query.Group>, lines: List<&2, String>, strs: List<&2, String>) -> Names:
  match groups:
    case Nil{}:
      Names{lines, strs}
    case Con{Query.Group{+key, count}, rest}:
      name_lines(rest, ("  " ++ Render.inline(key) ++ "\n") <> lines, Failure.quoted(key) <> strs)

# S5.185 (spec twin) the names rendered in the mode asked for, in ascending byte order
def names_view(n: Names, +count: Nat, json: Bool) -> View:
  match n json:
    case Names{lines, strs} True{}:
      ViewOk{"[" ++ String.join(List.reverse(&2, String, strs), ",") ++ "]\n"}
    case Names{lines, strs} False{}:
      ViewOk{Bool.pick(String, Nat.is_eq(count, 0n), "No labels in project.\n", "Labels (" ++ Nat.show(count) ++ " total):\n" ++ String.concat(List.reverse(&2, String, lines)))}

# S5.185 (spec twin) the tally's names, counted
def names_of(+groups: List<&2, Query.Group>, json: Bool) -> View:
  names_view(name_lines(groups, Nil{}, Nil{}), List.length(&2, Query.Group, groups), json)

# S5.185 (spec twin) `label list` without an issue: every label of the project, names only (round 15:
# `Labels (3 total):` then `  auth`; JSON `["auth","backend","db"]`; an empty store `No labels in project.` / `[]`)
def label_names(all: List<&2, Model.Issue>, json: Bool) -> View:
  names_of(label_tally(all, Nil{}), json)

# ---------------------------------------------------------------- comments (S5.51, S5.192–S5.194)

# S5.113 S5.193 (spec twin) a comment's instant as `%Y-%m-%d %H:%M UTC`
def minute_of(+full: String) -> String:
  String.take(full, 10n) ++ " " ++ String.take(String.drop(full, 11n), 5n) ++ " UTC"

# S5.193 (spec twin) a reversed text without its leading line feeds: a body's TRAILING newlines are stripped and nothing
# else (a trailing space or tab stays: `hello ` prints `hello `; the port's earlier trim of all white space was wrong)
def no_lead_lf(s: String) -> String:
  match s:
    case SCon{Chr{10}, rest}:
      no_lead_lf(rest)
    case other:
      other

# S5.193 (spec twin) each comment is three lines: `[{author}] at {when}`, the body without trailing newlines, a blank line
def comment_blocks(items: List<&2, Model.Comment>) -> List<&2, String>:
  match items:
    case Nil{}:
      Nil{}
    case Con{Model.Comment{id, issue_id, author, text, created_at}, rest}:
      String.concat(["[", Render.inline(author), "] at ", minute_of(Time.print(created_at, "Z")), "\n", String.reverse(no_lead_lf(String.reverse(text))), "\n\n"]) <> comment_blocks(rest)

# S5.51 S5.192–S5.194 (spec twin) `comments list <id>`
def comments_list(h: Hit, json: Bool) -> View:
  match h json:
    case HitBad{f} _:
      ViewBad{f}
    case HitOk{i} True{}:
      ViewOk{"[" ++ Model.comments_text(Model.comments_of(i)) ++ "]\n"}
    case HitOk{+i} False{}:
      ViewOk{Bool.pick(String, List.is_empty(&2, Model.Comment, Model.comments_of(i)), "No comments for " ++ Render.inline(Model.id_of(i)) ++ ".\n", "Comments for " ++ Render.inline(Model.id_of(i)) ++ ":\n" ++ String.concat(comment_blocks(Model.comments_of(i))))}

# ---------------------------------------------------------------- epic status (S4.189–S4.192, S5.55, S5.196–S5.199)

# S4.189 (spec twin) is an issue a listed epic: type `epic`, neither closed nor tombstoned, not a template
def is_open_epic(+i: Model.Issue) -> Bool:
  (String.eq(Model.type_of(i), "epic") && Bool.not(Blocked.terminal(Model.status_of(i))) && Bool.not(Model.is_template(i)))

# S4.189 (spec twin) keep a listed epic
def epic_put(i: Model.Issue, keep: Bool, rest: List<&2, Model.Issue>) -> List<&2, Model.Issue>:
  match keep:
    case True{}:
      i <> rest
    case False{}:
      rest

# S4.189 S4.192 (spec twin) the listed epics, and under `--eligible-only` only the eligible ones
def epics_of(issues: List<&2, Model.Issue>, +idx: Work.ChildIndex, +eligible_only: Bool) -> List<&2, Model.Issue>:
  match issues:
    case Nil{}:
      Nil{}
    case Con{+i, rest}:
      epic_put(i, (is_open_epic(i) && (Bool.not(eligible_only) || Work.eligible_live(is_open_epic(i), idx, Model.id_of(i)))), epics_of(rest, idx, eligible_only))

# S4.191 S5.198 (spec twin) the percentage: closed * 100 / total in whole numbers, 0 without children
def percent(+done: U32, +total: U32) -> U32:
  Bool.pick(U32, U32.is_eq(total, 0), 0, ((U32.min(done, total) * 100 : U32) / U32.max(total, 1) : U32))

# S5.196–S5.199 (spec twin) one epic in plain text: the glyph is `✓` when it may close and `○` otherwise, whatever its status
def epic_block(+i: Model.Issue, c: Work.Children) -> String:
  match c:
    case Work.Children{+total, +done}:
      String.concat([Bool.pick(String, Work.eligible(Work.Children{total, done}), "✓ ", "○ "), Render.inline(Model.id_of(i)), " ", Render.inline(Model.title_of(i)), "\n   Progress: ", U32.show(done), "/", U32.show(total), " children closed (", U32.show(percent(done, total)), "%)\n", Bool.pick(String, Work.eligible(Work.Children{total, done}), "   Eligible for closure\n", ""), "\n"])

# S5.55 (spec twin) one epic as JSON: the full issue object, then the three counts
def epic_object(+i: Model.Issue, c: Work.Children) -> String:
  match c:
    case Work.Children{+total, +done}:
      String.concat(["{\"epic\":", Model.line(i), ",\"total_children\":", U32.show(total), ",\"closed_children\":", U32.show(done), ",\"eligible_for_close\":", Failure.bool_text(Work.eligible(Work.Children{total, done})), "}"])

# S5.55 S5.196 (spec twin) one listed epic rendered, its children looked up once
def epic_item(+i: Model.Issue, +c: Work.Children, json: Bool, first: Bool) -> String:
  match json:
    case True{}:
      Bool.pick(String, first, "", ",") ++ epic_object(i, c)
    case False{}:
      epic_block(i, c)

# S5.55 S5.196 (spec twin) every listed epic rendered, JSON objects separated by `,`
def epic_items(epics: List<&2, Model.Issue>, +idx: Work.ChildIndex, +json: Bool, first: Bool) -> List<&2, String>:
  match epics:
    case Nil{}:
      Nil{}
    case Con{+i, rest}:
      epic_item(i, Work.children_in(idx, Model.id_of(i)), json, first) <> epic_items(rest, idx, json, False{})

# S5.55 S5.199 (spec twin) the listed epics as one text
def epic_view(epics: List<&2, Model.Issue>, idx: Work.ChildIndex, +json: Bool) -> View:
  match epics:
    case Nil{}:
      ViewOk{Bool.pick(String, json, "[]\n", "No open epics found\n")}
    case Con{e, rest}:
      ViewOk{Bool.pick(String, json, "[", "") ++ String.concat(epic_items(e <> rest, idx, json, True{})) ++ Bool.pick(String, json, "]\n", "")}

# S4.189 (spec twin) `epic status` once its children index is built
def epic_indexed(+all: List<&2, Model.Issue>, eligible_only: Bool, +json: Bool, +idx: Work.ChildIndex) -> View:
  epic_view(Query.ordered(epics_of(all, idx, eligible_only), 0, False{}), idx, json)

# S4.189 S5.55 S5.199 (spec twin) `epic status`: the epics in the default order of `list`; none prints `No open epics
# found`, `[]` as JSON. `spec` selects the per-epic scan of the store over the one-pass table (BEADS_RUST_SPEC)
def epic_status(+all: List<&2, Model.Issue>, eligible_only: Bool, +json: Bool, spec: Bool) -> View:
  epic_indexed(all, eligible_only, json, Work.child_index(spec, all))

# ---------------------------------------------------------------- where (S5.56, S5.200)

# S2.15 S5.56 (spec twin) the `prefix` member of `where --json`, absent when there is no prefix to report (`where_empty_json`)
def prefix_member(prefix: Maybe<&2, String>) -> String:
  match prefix:
    case None{}:
      ""
    case Some{p}:
      ",\"prefix\":" ++ Failure.quoted(p)

# S2.15 S5.200 (spec twin) the `  prefix:` line of plain `where`, absent when there is no prefix to report (`where_empty`)
def prefix_line(prefix: Maybe<&2, String>) -> String:
  match prefix:
    case None{}:
      ""
    case Some{p}:
      "  prefix: " ++ p ++ "\n"

# S5.56 S5.200 (spec twin) `where`: the `.beads` directory, the prefix, the path `beads.db` would have (printed even
# though `--no-db` never creates it), and the store
def whereabouts(+dir: String, prefix: Maybe<&2, String>, json: Bool) -> View:
  match json:
    case True{}:
      ViewOk{String.concat(["{\"path\":", Failure.quoted(dir), prefix_member(prefix), ",\"database_path\":", Failure.quoted(dir ++ "/beads.db"), ",\"jsonl_path\":", Failure.quoted(dir ++ "/issues.jsonl"), "}\n"])}
    case False{}:
      ViewOk{String.concat([dir, "\n", prefix_line(prefix), "  database: ", dir, "/beads.db\n  jsonl: ", dir, "/issues.jsonl\n"])}

# S4.187 (spec twin) the witnesses of a finished search, back in ascending order
def wits_of(c: Comps) -> List<&2, Wit>:
  match c:
    case Comps{done, wits}:
      List.reverse(&2, Wit, wits)

# S4.186–S4.188 (spec twin) the witnesses of the store's cycles, in ascending order. The components are searched
# only among the nodes the pruning keeps (a node on a cycle, or leading into one), so a store without cycles costs the
# pruning alone
def cycle_wits(+ways: List<&2, Arc>, +all: List<&2, Model.Issue>) -> List<&2, Wit>:
  wits_of(comps_go(Model.dedup(List.sort(~String, ~String.is_le, cyclic_core(Nat.add(List.length(&2, Arc, ways), 1n), sources(ways), ways))), ways, Model.dedup(List.sort(~String, ~String.is_le, cyclic_core(Nat.add(List.length(&2, Arc, ways), 1n), sources(ways), ways))), all, Comps{Nil{}, Nil{}}))

# S4.186–S4.188 S5.48 S5.181 S5.182 (spec twin) `dep cycles` (OQ-129 resolved by a hand-written cycle fixture)
def dep_cycles(+all: List<&2, Model.Issue>, blocking_only: Bool, include_closed: Bool, json: Bool) -> View:
  cycles_view(cycle_wits(arcs(all), all), blocking_only, include_closed, json)

