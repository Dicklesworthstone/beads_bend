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

# S4.157 (data) how the relation finds a record by id: the scan of the store (the spec twin; `BEADS_RUST_SPEC=1`), or
# a table built once (the fast twin: a crit-bit trie, so a store whose ids share a long prefix is not compared
# character by character against every record)
type Index is Data:
  ByList{all: List<&2, Model.Issue>}
  ByMap{table: Map<&2, Maybe<&2, Model.Issue>>}

# S4.157 (fast twin) the table of the records by id, filled from the store REVERSED so that the first record of an id
# wins, as in `lookup`
def table_go(rev: List<&2, Model.Issue>, m: Map<&2, Maybe<&2, Model.Issue>>) -> Map<&2, Maybe<&2, Model.Issue>>:
  match rev:
    case Nil{}:
      m
    case Con{+i, rest}:
      table_go(rest, Map.set(&2, Maybe<&2, Model.Issue>, m, Model.id_of(i), Some{i}))

# S4.157 (spec twin) the index a command uses: the scan when the spec switch is on, the table otherwise
def index(spec: Bool, +all: List<&2, Model.Issue>) -> Index:
  match spec:
    case True{}:
      ByList{all}
    case False{}:
      ByMap{table_go(List.reverse(&2, Model.Issue, all), Map.new(&2, Maybe<&2, Model.Issue>))}

# S4.157 (fast twin) the value half of a table lookup
def found_value(mv: Map<&2, Maybe<&2, Model.Issue>> & Maybe<&2, Model.Issue>) -> Maybe<&2, Model.Issue>:
  (m, v) = mv
  v

# S4.157 (spec twin) the record with this id, through the index
def find(+idx: Index, +id: String) -> Maybe<&2, Model.Issue>:
  match idx:
    case ByList{all}:
      lookup(all, id)
    case ByMap{table}:
      found_value(Map.get(Maybe<&2, Model.Issue>, None{}, table, id))

# S4.157 (data) a set of ids asked "is this one of them" once per record: the list scanned (spec twin), or a set
# built once (fast twin)
type Keys is Data:
  KeyList{ids: List<&2, String>}
  KeySet{set: Map<&2, Bool>}

# S4.157 (fast twin) the set of a list of ids
def set_go(ids: List<&2, String>, m: Map<&2, Bool>) -> Map<&2, Bool>:
  match ids:
    case Nil{}:
      m
    case Con{+id, rest}:
      set_go(rest, Map.set(&2, Bool, m, id, True{}))

# S4.157 (spec twin) the ids as the command asks them: the list when the spec switch is on, the set otherwise
def keyed(spec: Bool, +ids: List<&2, String>) -> Keys:
  match spec:
    case True{}:
      KeyList{ids}
    case False{}:
      KeySet{set_go(ids, Map.new(&2, Bool))}

# S4.157 (fast twin) the answer half of a set lookup
def set_answer(mb: Map<&2, Bool> & Bool) -> Bool:
  (m, b) = mb
  b

# S4.157 (spec twin) is this id one of the keys
def is_key(+ks: Keys, +id: String) -> Bool:
  match ks:
    case KeyList{ids}:
      among(ids, id)
    case KeySet{set}:
      set_answer(Map.has(&2, Bool, set, id))

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
def direct_edges(edges: List<&2, Model.Dependency>, +source: String, +idx: Index, entries: List<&2, Entry>) -> List<&2, Entry>:
  match edges:
    case Nil{}:
      entries
    case Con{+e, rest}:
      direct_edges(rest, source, idx, add_some(entries, source, Bool.pick(String, (blocking(Model.dep_type_of(e)) && Bool.not(external(Model.target_of(e)))), direct_ref(Model.target_of(e), find(idx, Model.target_of(e))), "")))

# S4.157 (spec twin) step 1 over every issue, in store order
def direct(issues: List<&2, Model.Issue>, +idx: Index, entries: List<&2, Entry>) -> List<&2, Entry>:
  match issues:
    case Nil{}:
      entries
    case Con{+i, rest}:
      direct(rest, idx, direct_edges(Model.deps_of(i), Model.id_of(i), idx, entries))

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
def epics(ls: List<&2, Link>, +idx: Index, entries: List<&2, Entry>) -> List<&2, Entry>:
  match ls:
    case Nil{}:
      entries
    case Con{Link{+child, +parent}, rest}:
      epics(rest, idx, add_some(entries, parent, Bool.pick(String, rolls_up(find(idx, child), find(idx, parent)), child ++ ":child-open", "")))

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
def relation_in(+all: List<&2, Model.Issue>, +idx: Index) -> List<&2, Entry>:
  normalized(overlay(all, epics(links(all), idx, propagate(Nat.add(Nat.add(List.length(&2, Model.Issue, all), List.length(&2, Link, links(all))), 1n), Wave{direct(all, idx, Nil{}), keys(direct(all, idx, Nil{}))}, links(all), Nil{}))))

# S4.157–S4.166 (spec twin) the relation with the store scanned for every lookup
def relation(+all: List<&2, Model.Issue>) -> List<&2, Entry>:
  relation_in(all, ByList{all})

# ---------------------------------------------------------------- the fast twin of the relation
# The same three steps, overlay and normalization over a table instead of the entry list: the refs of each id in a
# Map (so `add` is one lookup, not a scan of every entry) and the ids in order of entry beside it (the order is
# observable, S4.161). The propagation reads the children of a parent from a Map built once, keeps its frontier as
# a queue of two lists and its processed ids as a set. Nothing else changes: every step adds the same refs in the
# same order as the spec twin.

# S4.157 (data) the relation as a table: refs per id (REVERSED, as in `Entry`) and the ids in order of entry (REVERSED)
type Table is Data:
  Table{refs: Map<&2, List<&2, String>>, order: List<&2, String>}

# S4.157 (data) a table after adding one ref, and whether the ref was new
type TAdded is Data:
  TAdded{table: Table, fresh: Bool}

# S4.157 (fast twin) the ref routed once the id's refs are known to be there
def t_known(known: Bool, +rs: List<&2, String>, m: Map<&2, List<&2, String>>, order: List<&2, String>, +id: String, +ref: String) -> TAdded:
  match known:
    case True{}:
      TAdded{Table{m, order}, False{}}
    case False{}:
      TAdded{Table{Map.set(&2, List<&2, String>, m, id, ref <> rs), order}, True{}}

# S4.157 (fast twin) the ref routed by the id's refs: none (a new id, entered at the end) or some
def t_pick(present: Bool, +rs: List<&2, String>, m: Map<&2, List<&2, String>>, order: List<&2, String>, +id: String, +ref: String) -> TAdded:
  match present:
    case False{}:
      TAdded{Table{Map.set(&2, List<&2, String>, m, id, ref <> Nil{}), id <> order}, True{}}
    case True{}:
      t_known(among(rs, ref), rs, m, order, id, ref)

# S4.157 (fast twin) an id is present exactly when its refs are not empty (every entry is made with one ref)
def t_have(m: Map<&2, List<&2, String>>, +rs: List<&2, String>, order: List<&2, String>, +id: String, +ref: String) -> TAdded:
  t_pick(Bool.not(List.is_empty(&2, String, rs)), rs, m, order, id, ref)

# S4.157 (fast twin) the lookup's pair taken apart
def t_got(mv: Map<&2, List<&2, String>> & List<&2, String>, order: List<&2, String>, +id: String, +ref: String) -> TAdded:
  (m, rs) = mv
  t_have(m, rs, order, id, ref)

# S4.157 S4.159 (fast twin) `add` over the table
def t_add(t: Table, +id: String, +ref: String) -> TAdded:
  match t:
    case Table{refs, order}:
      t_got(Map.get(List<&2, String>, Nil{}, refs, id), order, id, ref)

# S4.157 (fast twin) the table of a TAdded
def t_table(a: TAdded) -> Table:
  match a:
    case TAdded{table, fresh}:
      table

# S4.157 (fast twin) `add_some` over the table
def t_add_some(t: Table, id: String, ref: String) -> Table:
  match ref:
    case SNil{}:
      t
    case SCon{h, t2}:
      t_table(t_add(t, id, SCon{h, t2}))

# S4.157 S4.158 (fast twin) step 1 over one issue's edges
def t_direct_edges(edges: List<&2, Model.Dependency>, +source: String, +idx: Index, t: Table) -> Table:
  match edges:
    case Nil{}:
      t
    case Con{+e, rest}:
      t_direct_edges(rest, source, idx, t_add_some(t, source, Bool.pick(String, (blocking(Model.dep_type_of(e)) && Bool.not(external(Model.target_of(e)))), direct_ref(Model.target_of(e), find(idx, Model.target_of(e))), "")))

# S4.157 (fast twin) step 1 over every issue, in store order
def t_direct(issues: List<&2, Model.Issue>, +idx: Index, t: Table) -> Table:
  match issues:
    case Nil{}:
      t
    case Con{+i, rest}:
      t_direct(rest, idx, t_direct_edges(Model.deps_of(i), Model.id_of(i), idx, t))

# S4.159 (fast twin) one child put in front of its parent's children
def kid_put(mv: Map<&2, List<&2, String>> & List<&2, String>, +parent: String, child: String) -> Map<&2, List<&2, String>>:
  (m, cs) = mv
  Map.set(&2, List<&2, String>, m, parent, child <> cs)

# S4.159 (fast twin) the children of every parent, each list in link order (the links are read REVERSED)
def kids_go(rev: List<&2, Link>, m: Map<&2, List<&2, String>>) -> Map<&2, List<&2, String>>:
  match rev:
    case Nil{}:
      m
    case Con{Link{child, +parent}, rest}:
      kids_go(rest, kid_put(Map.get(List<&2, String>, Nil{}, m, parent), parent, child))

# S4.159 (fast twin) the value half of a children lookup
def kids_value(mv: Map<&2, List<&2, String>> & List<&2, String>) -> List<&2, String>:
  (m, cs) = mv
  cs

# S4.159 (data) the propagation's state: the table, and the frontier as a queue (front in order, back REVERSED;
# the front is empty only when the queue is)
type TWave is Data:
  TWave{table: Table, front: List<&2, String>, back: List<&2, String>}

# S4.159 (fast twin) the queue's back turned into its front when the front runs out
def t_level(t: Table, front: List<&2, String>, back: List<&2, String>) -> TWave:
  match front:
    case Nil{}:
      TWave{t, List.reverse(&2, String, back), Nil{}}
    case Con{f, rest}:
      TWave{t, Con{f, rest}, back}

# S4.159 (fast twin) a child that gained the ref joins the back of the queue
def t_push(a: TAdded, front: List<&2, String>, back: List<&2, String>, child: String) -> TWave:
  match a:
    case TAdded{t, True{}}:
      TWave{t, front, child <> back}
    case TAdded{t, False{}}:
      TWave{t, front, back}

# S4.159 (fast twin) every child of the id being processed gains `<id>:parent-blocked`, in link order
def t_children(cs: List<&2, String>, +id: String, w: TWave) -> TWave:
  match cs w:
    case Nil{} other:
      other
    case Con{+child, rest} TWave{t, front, back}:
      t_children(rest, id, t_push(t_add(t, child, id ++ ":parent-blocked"), front, back, child))

# S4.159 (fast twin) process one popped id once: an id already processed is passed over
def t_step(seen: Bool, w: TWave, +id: String, +kids: Map<&2, List<&2, String>>) -> TWave:
  match seen:
    case True{}:
      w
    case False{}:
      t_children(kids_value(Map.get(List<&2, String>, Nil{}, kids, id)), id, w)

# S4.159 (fast twin) the wave with its queue levelled
def t_levelled(w: TWave) -> TWave:
  match w:
    case TWave{t, front, back}:
      t_level(t, front, back)

# S4.159 (fast twin) step 2 with the same fuel as `propagate`: one unit per popped id
def t_propagate(fuel: Nat, w: TWave, +kids: Map<&2, List<&2, String>>, +done: Map<&2, Bool>) -> Table:
  match fuel w:
    case 0n TWave{t, front, back}:
      t
    case 1n+g TWave{t, Nil{}, back}:
      t
    case 1n+g TWave{t, Con{+id, rest}, back}:
      t_propagate(g, t_levelled(t_step(set_answer(Map.has(&2, Bool, done, id)), TWave{t, rest, back}, id, kids)), kids, Map.set(&2, Bool, done, id, True{}))

# S4.160 (fast twin) step 3 over the table
def t_epics(ls: List<&2, Link>, +idx: Index, t: Table) -> Table:
  match ls:
    case Nil{}:
      t
    case Con{Link{+child, +parent}, rest}:
      t_epics(rest, idx, t_add_some(t, parent, Bool.pick(String, rolls_up(find(idx, child), find(idx, parent)), child ++ ":child-open", "")))

# S4.166 (fast twin) the external overlay over one issue's edges
def t_overlay_edges(edges: List<&2, Model.Dependency>, +source: String, +live: Bool, t: Table) -> Table:
  match edges:
    case Nil{}:
      t
    case Con{+e, rest}:
      t_overlay_edges(rest, source, live, t_add_some(t, source, Bool.pick(String, (live && blocking(Model.dep_type_of(e)) && external(Model.target_of(e))), Model.target_of(e) ++ ":blocked", "")))

# S4.166 (fast twin) the external overlay over every issue
def t_overlay(issues: List<&2, Model.Issue>, t: Table) -> Table:
  match issues:
    case Nil{}:
      t
    case Con{+i, rest}:
      t_overlay(rest, t_overlay_edges(Model.deps_of(i), Model.id_of(i), Bool.not(terminal(Model.status_of(i))), t))

# S4.157 (fast twin) the entries of the table in order of entry (`ids` in that order)
def t_entries_go(ids: List<&2, String>, +m: Map<&2, List<&2, String>>) -> List<&2, Entry>:
  match ids:
    case Nil{}:
      Nil{}
    case Con{+id, rest}:
      Entry{id, kids_value(Map.get(List<&2, String>, Nil{}, m, id))} <> t_entries_go(rest, m)

# S4.157 (fast twin) the table as the entry list the spec twin builds
def t_entries(t: Table) -> List<&2, Entry>:
  match t:
    case Table{refs, order}:
      t_entries_go(List.reverse(&2, String, order), refs)

# S4.159 (fast twin) the wave step 1 starts: its keys in order, as `keys(direct(…))`
def t_start(t: Table) -> TWave:
  match t:
    case Table{refs, +order}:
      t_level(Table{refs, order}, List.reverse(&2, String, order), Nil{})

# S4.157–S4.166 (fast twin) the relation over the table: the same steps, in the same order, with the same fuel
def relation_t(+all: List<&2, Model.Issue>, +idx: Index) -> List<&2, Entry>:
  normalized(t_entries(t_overlay(all, t_epics(links(all), idx, t_propagate(Nat.add(Nat.add(List.length(&2, Model.Issue, all), List.length(&2, Link, links(all))), 1n), t_start(t_direct(all, idx, Table{Map.new(&2, List<&2, String>), Nil{}})), kids_go(List.reverse(&2, Link, links(all)), Map.new(&2, List<&2, String>)), Map.new(&2, Bool))))))

# S4.157–S4.166 (spec twin) the relation a command uses: the spec twin over the scan when `spec` (BEADS_RUST_SPEC=1)
# is on, the table otherwise. Bound by the closed laws `work_blocked_rows_table`, `work_figures_table`,
# `work_ready_table` and `work_blocked_rows_hierarchy`
def relation_with(spec: Bool, +all: List<&2, Model.Issue>, +idx: Index) -> List<&2, Entry>:
  match spec:
    case True{}:
      relation_in(all, idx)
    case False{}:
      relation_t(all, idx)

# S4.157–S4.166 (spec twin) the relation with its index chosen by the spec switch
def relation_by(+spec: Bool, +all: List<&2, Model.Issue>) -> List<&2, Entry>:
  relation_with(spec, all, index(spec, all))

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
