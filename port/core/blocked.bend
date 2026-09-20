# core/blocked — the BLOCKED relation (S4.157–S4.166).
# Which issue is blocked, and by what: a map from an issue id to its blocker
# refs `<id>:<why>`. Three steps whose ORDER is observable (S4.161): direct
# blockers; propagation from a blocked parent down its parent-child edges, to
# a fixed point; epics blocked by their open children. Then the external
# overlay, then every list sorted and de-duplicated. The propagation is a
# worklist bounded by fuel (each id is processed once; every push is a new
# ref, of which there are at most one per parent-child edge).
# Nothing here consults the original.
import Base
import ./model.bend as Model

# S4.157 (data) one issue of the relation and its blocker refs (REVERSED until `normalized`)
type Entry is Data:
  Entry{id: String, refs: List<&2, String>}

# S4.159 (data) a parent-child edge as the propagation reads it: the child (source) and the parent (target)
type Link is Data:
  Link{child: String, parent: String}

# S4.159 (data) the relation after adding one ref, and whether the ref was new
type Added is Data:
  Added{entries: List<&2, Entry>, fresh: Bool}

# S4.157 (spec twin) is this word in the list
def among(xs: List<&2, String>, +x: String) -> Bool:
  match xs:
    case Nil{}:
      False{}
    case Con{y, rest}:
      (String.eq(y, x) || among(rest, x))

# S4.157 (spec twin) the record with this id
def lookup(issues: List<&2, Model.Issue>, +id: String) -> Maybe<&2, Model.Issue>:
  match issues:
    case Nil{}:
      None{}
    case Con{+i, rest}:
      Bool.pick(Maybe<&2, Model.Issue>, String.eq(Model.id_of(i), id), Some{i}, lookup(rest, id))

# S4.157 S4.160 (spec twin) is a status terminal: `closed` or `tombstone`
def terminal(+status: String) -> Bool:
  (String.eq(status, "closed") || String.eq(status, "tombstone"))

# S4.157 (spec twin) the three edge types that block
def blocking(+kind: String) -> Bool:
  (String.eq(kind, "blocks") || String.eq(kind, "conditional-blocks") || String.eq(kind, "waits-for"))

# S4.158 (spec twin) does an id name another project
def external(id: String) -> Bool:
  String.starts_with(id, "external:")

# S4.157 S4.159 (spec twin) route one entry of the relation while adding a ref to `id`
def add_here(+id: String, +refs: List<&2, String>, +ref: String, known: Bool) -> Added:
  match known:
    case True{}:
      Added{Entry{id, refs} <> Nil{}, False{}}
    case False{}:
      Added{Entry{id, ref <> refs} <> Nil{}, True{}}

# S4.157 (spec twin) put an entry in front of the entries of an Added
def add_front(e: Entry, a: Added) -> Added:
  match a:
    case Added{entries, fresh}:
      Added{e <> entries, fresh}

# S4.157 (spec twin) the rest of the relation behind an entry that was just changed
def add_rest(a: Added, rest: List<&2, Entry>) -> Added:
  match a:
    case Added{entries, fresh}:
      Added{List.append(&2, Entry, entries, rest), fresh}

# S4.157 S4.159 (spec twin) add a blocker ref to an issue: a ref already there changes nothing; an issue not yet
# in the relation enters at its end
def add(entries: List<&2, Entry>, +id: String, +ref: String) -> Added:
  match entries:
    case Nil{}:
      Added{Entry{id, ref <> Nil{}} <> Nil{}, True{}}
    case Con{Entry{+eid, +refs}, +rest}:
      Bool.pick(Added, String.eq(eid, id), add_rest(add_here(eid, refs, ref, among(refs, ref)), rest), add_front(Entry{eid, refs}, add(rest, id, ref)))

# S4.157 (spec twin) the entries of an Added
def entries_of(a: Added) -> List<&2, Entry>:
  match a:
    case Added{entries, fresh}:
      entries

# S4.157 (spec twin) the blocker ref of a direct edge's target: `<target>:<its status>`, `<target>:unknown` when it is
# not stored; "" when the target does not block (terminal, or a template)
def direct_ref(target: String, found: Maybe<&2, Model.Issue>) -> String:
  match found:
    case None{}:
      target ++ ":unknown"
    case Some{+t}:
      Bool.pick(String, (terminal(Model.status_of(t)) || Model.is_template(t)), "", target ++ ":" ++ Model.status_of(t))

# S4.157 (spec twin) add a ref unless it is empty
def add_some(entries: List<&2, Entry>, id: String, ref: String) -> List<&2, Entry>:
  match ref:
    case SNil{}:
      entries
    case SCon{h, t}:
      entries_of(add(entries, id, SCon{h, t}))

# S4.157 S4.158 (spec twin) step 1 over one issue's edges: a blocking edge to a local target that still blocks
def direct_edges(edges: List<&2, Model.Dependency>, +source: String, +all: List<&2, Model.Issue>, entries: List<&2, Entry>) -> List<&2, Entry>:
  match edges:
    case Nil{}:
      entries
    case Con{+e, rest}:
      direct_edges(rest, source, all, add_some(entries, source, Bool.pick(String, (blocking(Model.dep_type_of(e)) && Bool.not(external(Model.target_of(e)))), direct_ref(Model.target_of(e), lookup(all, Model.target_of(e))), "")))

# S4.157 (spec twin) step 1 over every issue, in store order
def direct(issues: List<&2, Model.Issue>, +all: List<&2, Model.Issue>, entries: List<&2, Entry>) -> List<&2, Entry>:
  match issues:
    case Nil{}:
      entries
    case Con{+i, rest}:
      direct(rest, all, direct_edges(Model.deps_of(i), Model.id_of(i), all, entries))

# S4.159 (spec twin) keep a link
def link_put(l: Link, keep: Bool, later: List<&2, Link>) -> List<&2, Link>:
  match keep:
    case True{}:
      l <> later
    case False{}:
      later

# S4.158 S4.159 (spec twin) the parent-child edges of one issue whose endpoints are both local
def links_of(edges: List<&2, Model.Dependency>, +source: String) -> List<&2, Link>:
  match edges:
    case Nil{}:
      Nil{}
    case Con{+e, rest}:
      link_put(Link{source, Model.target_of(e)}, (String.eq(Model.dep_type_of(e), "parent-child") && Bool.not(external(Model.target_of(e))) && Bool.not(external(source))), links_of(rest, source))

# S4.159 (spec twin) every local parent-child edge of the store, in store order
def links(issues: List<&2, Model.Issue>) -> List<&2, Link>:
  match issues:
    case Nil{}:
      Nil{}
    case Con{+i, rest}:
      List.append(&2, Link, links_of(Model.deps_of(i), Model.id_of(i)), links(rest))

# S4.159 (data) the propagation's state: the relation, and the ids still to process
type Wave is Data:
  Wave{entries: List<&2, Entry>, frontier: List<&2, String>}

# S4.159 (spec twin) a child that gained the ref joins the frontier
def wave_put(a: Added, child: String, frontier: List<&2, String>) -> Wave:
  match a:
    case Added{entries, True{}}:
      Wave{entries, List.append(&2, String, frontier, child <> Nil{})}
    case Added{entries, False{}}:
      Wave{entries, frontier}

# S4.159 (spec twin) a link whose parent is the blocked id adds the ref to its child
def wave_pick(hit: Bool, w: Wave, +child: String, id: String) -> Wave:
  match hit w:
    case False{} other:
      other
    case True{} Wave{entries, frontier}:
      wave_put(add(entries, child, id ++ ":parent-blocked"), child, frontier)

# S4.159 (spec twin) one link against the blocked id being processed: its child gains `<parent>:parent-blocked`
def wave_link(w: Wave, l: Link, +id: String) -> Wave:
  match l:
    case Link{child, parent}:
      wave_pick(String.eq(parent, id), w, child, id)

# S4.159 (spec twin) every link against the blocked id being processed
def wave_links(ls: List<&2, Link>, +id: String, w: Wave) -> Wave:
  match ls:
    case Nil{}:
      w
    case Con{l, rest}:
      wave_links(rest, id, wave_link(w, l, id))

# S4.157 (spec twin) the ids of the relation, in its order
def keys(entries: List<&2, Entry>) -> List<&2, String>:
  match entries:
    case Nil{}:
      Nil{}
    case Con{Entry{id, refs}, rest}:
      id <> keys(rest)

# S4.159 (spec twin) process the first id of the frontier once: an id already processed is passed over
def wave_step(w: Wave, +id: String, +ls: List<&2, Link>, seen: Bool) -> Wave:
  match seen:
    case True{}:
      w
    case False{}:
      wave_links(ls, id, w)

# S4.159 (spec twin) step 2: from the keys of step 1, a blocked parent blocks its children, to a fixed point. `fuel`
# bounds the worklist: one unit per processed id
def propagate(fuel: Nat, w: Wave, +ls: List<&2, Link>, +done: List<&2, String>) -> List<&2, Entry>:
  match fuel w:
    case 0n Wave{entries, frontier}:
      entries
    case 1n+g Wave{entries, Nil{}}:
      entries
    case 1n+g Wave{entries, Con{+id, rest}}:
      propagate(g, wave_step(Wave{entries, rest}, id, ls, among(done, id)), ls, id <> done)

# S4.160 (spec twin) does this parent-child link roll up onto its parent: the parent is a stored epic, the child is
# stored, not terminal and not a template
def rolls_up(child: Maybe<&2, Model.Issue>, parent: Maybe<&2, Model.Issue>) -> Bool:
  match child parent:
    case Some{+c} Some{p}:
      (String.eq(Model.type_of(p), "epic") && Bool.not(terminal(Model.status_of(c))) && Bool.not(Model.is_template(c)))
    case _ _:
      False{}

# S4.160 (spec twin) step 3: an epic is blocked by each of its open children, `<child>:child-open`
def epics(ls: List<&2, Link>, +all: List<&2, Model.Issue>, entries: List<&2, Entry>) -> List<&2, Entry>:
  match ls:
    case Nil{}:
      entries
    case Con{Link{+child, +parent}, rest}:
      epics(rest, all, add_some(entries, parent, Bool.pick(String, rolls_up(lookup(all, child), lookup(all, parent)), child ++ ":child-open", "")))

# S4.166 (spec twin) the external overlay over one issue's edges: a blocking edge to `external:…` always blocks
# (no external project is configured, so no target is ever satisfied); a terminal issue is not added
def overlay_edges(edges: List<&2, Model.Dependency>, +source: String, +live: Bool, entries: List<&2, Entry>) -> List<&2, Entry>:
  match edges:
    case Nil{}:
      entries
    case Con{+e, rest}:
      overlay_edges(rest, source, live, add_some(entries, source, Bool.pick(String, (live && blocking(Model.dep_type_of(e)) && external(Model.target_of(e))), Model.target_of(e) ++ ":blocked", "")))

# S4.166 (spec twin) the external overlay over every issue
def overlay(issues: List<&2, Model.Issue>, entries: List<&2, Entry>) -> List<&2, Entry>:
  match issues:
    case Nil{}:
      entries
    case Con{+i, rest}:
      overlay(rest, overlay_edges(Model.deps_of(i), Model.id_of(i), Bool.not(terminal(Model.status_of(i))), entries))

# S4.162 (spec twin) keep a ref unless the next one equals it
def dedup_put(a: String, same: Bool, rest: List<&2, String>) -> List<&2, String>:
  match same:
    case True{}:
      rest
    case False{}:
      a <> rest

# S4.162 (spec twin) adjacent equal refs collapse
def dedup(xs: List<&2, String>) -> List<&2, String>:
  match xs:
    case Con{+a, Con{+b, rest}}:
      dedup_put(a, String.eq(a, b), dedup(b <> rest))
    case other:
      other

# S4.162 (spec twin) every blocker list in ascending byte order of the whole ref, each ref once; an issue whose list is empty leaves
def normalized(entries: List<&2, Entry>) -> List<&2, Entry>:
  match entries:
    case Nil{}:
      Nil{}
    case Con{Entry{id, Nil{}}, rest}:
      normalized(rest)
    case Con{Entry{id, Con{r, more}}, rest}:
      Entry{id, dedup(List.sort(~String, ~String.is_le, r <> more))} <> normalized(rest)

# S4.157–S4.166 (spec twin) the BLOCKED relation of a store: step 1, step 2 to its fixed point, step 3 (in THIS order,
# S4.161), the overlay, the normalization. The fuel is one unit per issue plus one per parent-child link, plus one
def relation(+all: List<&2, Model.Issue>) -> List<&2, Entry>:
  normalized(overlay(all, epics(links(all), all, propagate(Nat.add(Nat.add(List.length(&2, Model.Issue, all), List.length(&2, Link, links(all))), 1n), Wave{direct(all, all, Nil{}), keys(direct(all, all, Nil{}))}, links(all), Nil{}))))

# S4.163 (spec twin) what follows the first `:` of a REVERSED ref (every ref has one: `<id>:<why>`)
def ref_tail(rev: String) -> String:
  match rev:
    case SNil{}:
      ""
    case SCon{Chr{58}, rest}:
      rest
    case SCon{c, rest}:
      ref_tail(rest)

# S4.163 (spec twin) a blocker ref as the outputs show it: cut at its LAST `:`
def ref_id(ref: String) -> String:
  String.reverse(ref_tail(String.reverse(ref)))

# S4.157 (spec twin) the blocker refs of one issue; none when it is not blocked
def refs_of(entries: List<&2, Entry>, +id: String) -> List<&2, String>:
  match entries:
    case Nil{}:
      Nil{}
    case Con{Entry{eid, refs}, rest}:
      Bool.pick(List<&2, String>, String.eq(eid, id), refs, refs_of(rest, id))
