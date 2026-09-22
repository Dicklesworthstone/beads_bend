# BEADS_RUST — the laws. HUMAN-OWNED: an agent may add a law, never weaken or
# delete one. Every law names the spec clause it encodes. Kinds:
#   fast == spec   binds every fast twin to its spec twin (the perf campaign
#                  may only change a fast twin; the law keeps it honest)
#   round trip     decode(encode(x)) == x for every codec the spec names
#   conservation   a quantity the spec says is preserved (totals, counts)
#   closed golden  a small original input whose expected output is pasted
#                  from goldens/ — the checker computes both sides
#   refutation     an impossible case is impossible ({a != b})
# What does NOT belong here: anything the checker must normalize through
# a large Peano Nat (U32.to_nat of a big word, Nat.read of long digit
# strings, whole-report renders); those stay in goldens/ and conform.sh.
import Base
import ./core/scaffold.bend as L
import ./core/bytes.bend as Bytes
import ./core/sha256.bend as Sha
import ./core/id.bend as Id
import ./core/time.bend as Time
import ./core/model.bend as Model
import ./core/store.bend as Store
import ./core/cli.bend as Cli
import ./core/query.bend as Query
import ./core/render.bend as Render
import ./core/resolve.bend as Resolve
import ./core/work.bend as Work
import ./core/run.bend as Run
import ./fixtures.bend as Fixtures

# S0.1 the fast twin equals the spec twin, for every input. One `for` per
# line, the goal last; `+x` when the proof needs x more than once.
law fast_is_spec:
  for x: Nat
  {L.core_fast(x) == L.core_spec(x) : Nat}

# S4.4 closed golden: SHA-256 of the empty message (FIPS 180-4 / NIST vector)
law sha_empty:
  {Sha.hex(Sha.digest(Bytes.utf8(""))) == "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855" : String}

# S4.4 closed golden: SHA-256 of "abc" (FIPS 180-4 appendix B.1)
law sha_abc:
  {Sha.hex(Sha.digest(Bytes.utf8("abc"))) == "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad" : String}

# S4.4 closed golden: the 56-byte message of FIPS 180-4 appendix B.2, which pads to TWO blocks
law sha_two_blocks:
  {Sha.hex(Sha.digest(Bytes.utf8("abcdbcdecdefdefgefghfghighijhijkijkljklmklmnlmnomnopnopq"))) == "248d6a61d20638b8e5c026930c3e6039a33ce45964ff2167f6ecedd419db06c1" : String}

# S4.1–S4.6 closed golden: goldens/create_min (`create "First issue"`, creator tester, 2026-01-02T03:04:05Z, nonce 0, length 3) is proj-fyw
law id_fyw:
  {Id.hash36(Id.seed("First issue", "", "tester", "1767323045000000000", 0n), 3n) == "fyw" : String}

# S4.1–S4.6 closed golden: the first create of goldens/scenarios/build_basic.scn (with a description) is proj-mta
law id_mta:
  {Id.hash36(Id.seed("Set up database schema", "Create the initial tables.", "tester", "1767261600000000000", 0n), 3n) == "mta" : String}

# S4.1–S4.6 closed golden: the second create of build_basic.scn is proj-170 (a hash part that is all digits)
law id_170:
  {Id.hash36(Id.seed("Implement user auth", "", "tester", "1767261601000000000", 0n), 3n) == "170" : String}

# S4.16 closed golden: goldens/q_basic. `q` seeds with an EMPTY creator even though the actor is tester: proj-asw
law id_q_asw:
  {Id.hash36(Id.seed("Quick one", "", "", "1767323045000000000", 0n), 3n) == "asw" : String}

# S4.11 closed golden: goldens/scn_dup_title, nonce 0 is proj-86w
law id_ladder_0:
  {Id.hash36(Id.seed("Same title", "", "tester", "1770109200000000000", 0n), 3n) == "86w" : String}

# S4.11 closed golden: goldens/scn_dup_title, the colliding second create takes nonce 1: proj-e1f
law id_ladder_1:
  {Id.hash36(Id.seed("Same title", "", "tester", "1770109200000000000", 1n), 3n) == "e1f" : String}

# S4.11 closed golden: goldens/scn_dup_title, the third create takes nonce 2: proj-fa9
law id_ladder_2:
  {Id.hash36(Id.seed("Same title", "", "tester", "1770109200000000000", 2n), 3n) == "fa9" : String}

# S4.54 S4.55 closed golden: fixture `precision` holds `2026-01-01T10:00:05Z`; goldens/edge_precision_rewrite shows the original writing back `2026-01-01T10:00:05Z`
law time_whole_second:
  {Time.reprint(Time.parse("2026-01-01T10:00:05Z"), "Z") == "2026-01-01T10:00:05Z" : String}

# S4.54 S4.55 closed golden: fixture `precision` holds `2026-01-01T10:00:05.100Z`; goldens/edge_precision_rewrite shows the original writing back `2026-01-01T10:00:05.100Z`
law time_millis:
  {Time.reprint(Time.parse("2026-01-01T10:00:05.100Z"), "Z") == "2026-01-01T10:00:05.100Z" : String}

# S4.54 S4.55 closed golden: fixture `precision` holds `2026-01-01T10:00:05.000000001Z`; goldens/edge_precision_rewrite shows the original writing back `2026-01-01T10:00:05.000000001Z`
law time_nanos:
  {Time.reprint(Time.parse("2026-01-01T10:00:05.000000001Z"), "Z") == "2026-01-01T10:00:05.000000001Z" : String}

# S4.54 S4.55 closed golden: fixture `precision` holds `2026-01-01T10:00:05.1Z`; goldens/edge_precision_rewrite shows the original writing back `2026-01-01T10:00:05.100Z`
law time_tenth_widens:
  {Time.reprint(Time.parse("2026-01-01T10:00:05.1Z"), "Z") == "2026-01-01T10:00:05.100Z" : String}

# S4.54 S4.55 closed golden: fixture `precision` holds `2026-01-01T12:00:04+02:00`; goldens/edge_precision_rewrite shows the original writing back `2026-01-01T10:00:04Z`
law time_offset_to_utc:
  {Time.reprint(Time.parse("2026-01-01T12:00:04+02:00"), "Z") == "2026-01-01T10:00:04Z" : String}

# S4.55 S4.57 closed fact of the proleptic Gregorian calendar (expected value from python3 datetime): `2026-03-01T00:30:00+02:00`
law time_borrow_across_month:
  {Time.reprint(Time.parse("2026-03-01T00:30:00+02:00"), "Z") == "2026-02-28T22:30:00Z" : String}

# S4.55 S4.57 closed fact of the proleptic Gregorian calendar (expected value from python3 datetime): `2024-03-01T00:00:00+01:00`
law time_borrow_into_leap_day:
  {Time.reprint(Time.parse("2024-03-01T00:00:00+01:00"), "Z") == "2024-02-29T23:00:00Z" : String}

# S4.55 S4.57 closed fact of the proleptic Gregorian calendar (expected value from python3 datetime): `2026-12-31T23:30:00-01:00`
law time_carry_across_year:
  {Time.reprint(Time.parse("2026-12-31T23:30:00-01:00"), "Z") == "2027-01-01T00:30:00Z" : String}

# S4.55 S4.57 closed fact of the proleptic Gregorian calendar (expected value from python3 datetime): `2026-06-15T08:09:10.000250Z`
law time_micros:
  {Time.reprint(Time.parse("2026-06-15T08:09:10.000250Z"), "Z") == "2026-06-15T08:09:10.000250Z" : String}

# S4.55 S4.57 closed fact of the proleptic Gregorian calendar (expected value from python3 datetime): `2026-01-02t03:04:05z`
law time_lowercase_t_z:
  {Time.reprint(Time.parse("2026-01-02t03:04:05z"), "Z") == "2026-01-02T03:04:05Z" : String}

# S4.57 a malformed spelling is a verdict (reprint answers the empty string), never a default instant: `2026-02-30T00:00:00Z`
law time_refuses_feb_30:
  {Time.reprint(Time.parse("2026-02-30T00:00:00Z"), "Z") == "" : String}

# S4.57 a malformed spelling is a verdict (reprint answers the empty string), never a default instant: `not-a-date`
law time_refuses_words:
  {Time.reprint(Time.parse("not-a-date"), "Z") == "" : String}

# S4.57 a malformed spelling is a verdict (reprint answers the empty string), never a default instant: `2026-01-01T24:00:00Z`
law time_refuses_hour_24:
  {Time.reprint(Time.parse("2026-01-01T24:00:00Z"), "Z") == "" : String}

# S4.57 a malformed spelling is a verdict (reprint answers the empty string), never a default instant: `2026-01-01T10:00:05`
law time_refuses_no_zone:
  {Time.reprint(Time.parse("2026-01-01T10:00:05"), "Z") == "" : String}

# S4.64 the same instant with the offset spelling the `defer` and `close` payloads use
law time_offset_suffix:
  {Time.reprint(Time.parse("2027-06-01T09:00:00Z"), "+00:00") == "2027-06-01T09:00:00+00:00" : String}

# S5.2 S5.4 S5.5 S5.6 closed golden: the store line goldens/create_min.out shows after `create "First issue"`
# (the pinned instant 2026-01-02T03:04:05Z is day 739923 from 0000-03-01, second 11045 of the day)
law store_line_create_min:
  {Model.line(Model.fresh("proj-fyw", "First issue", "tester", Time.Instant{739923, 11045, 0}, "proj", "/mnt/proj")) == "{\"id\":\"proj-fyw\",\"title\":\"First issue\",\"status\":\"open\",\"priority\":2,\"issue_type\":\"task\",\"created_at\":\"2026-01-02T03:04:05Z\",\"created_by\":\"tester\",\"updated_at\":\"2026-01-02T03:04:05Z\",\"source_repo\":\"proj\",\"source_repo_path\":\"/mnt/proj\",\"compaction_level\":0,\"original_size\":0}" : String}

# S2.24 S2.27 closed golden: the bytes of goldens/fixtures/malformed.jsonl load to the refusal that
# goldens/error_malformed_jsonl.err holds: the FIRST line is a good record and is not reported, the
# second is refused with its 1-based line number and serde_json's message and byte column
law store_refuses_malformed:
  {Store.refusal(Store.load(Time.codes("{\"id\":\"proj-aaa\",\"title\":\"before the conflict\",\"status\":\"open\",\"priority\":2,\"issue_type\":\"task\",\"created_at\":\"2026-01-01T10:00:05Z\",\"updated_at\":\"2026-01-01T10:00:05Z\"}\n{\"id\":\"proj-aab\",\"title\":\"truncated line\n"), "/mnt/proj/.beads/issues.jsonl")) == "Error: Configuration error: Invalid JSON at line 2: EOF while parsing a string at line 1 column 40\n" : String}

# S4.9 closed facts: the adaptive-length table at every band edge. The empty store and the `basic`
# fixture (8 records) are the captured cases (ids of length 3); the edges past 163/164 are S4.9's
# computed values, [inference] until OQ-006 captures them
law id_length_table:
  {[Id.length_for(0), Id.length_for(8), Id.length_for(163), Id.length_for(164), Id.length_for(983), Id.length_for(984), Id.length_for(5898), Id.length_for(5899), Id.length_for(35389), Id.length_for(35390), Id.length_for(212339), Id.length_for(212340)] == [3n, 3n, 3n, 4n, 4n, 5n, 5n, 6n, 6n, 7n, 7n, 8n] : List<&2, Nat>}

# S1.21 closed golden: goldens/usage_limit_bad.err — the parser's own refusal of a value, held and then fired at the end of argv
law cli_limit_bad:
  {Cli.parse(["list", "--limit", "x"]) == Cli.Refused{"error: invalid value 'x' for '--limit <LIMIT>': invalid digit found in string\n\nFor more information, try '--help'.\n"} : Cli.Parsed}

# S1.22 closed golden: goldens/usage_u8_range.err — read as a signed 64-bit integer, then held to 0..=255
law cli_u8_range:
  {Cli.parse(["list", "--priority-min", "300"]) == Cli.Refused{"error: invalid value '300' for '--priority-min <PRIORITY_MIN>': 300 is not in 0..=255\n\nFor more information, try '--help'.\n"} : Cli.Parsed}

# S1.81 closed golden: goldens/usage_similar_flag_in_cmd.err — the most similar long name is suggested and named on the usage line
law cli_similar_flag:
  {Cli.parse(["list", "--jsno"]) == Cli.Refused{"error: unexpected argument '--jsno' found\n\n  tip: a similar argument exists: '--json'\n\nUsage: br list --json\n\nFor more information, try '--help'.\n"} : Cli.Parsed}

# S1.82 closed golden: goldens/usage_similar_subcommand.err — every similar subcommand, in ascending similarity
law cli_similar_subcommand:
  {Cli.parse(["lst"]) == Cli.Refused{"error: unrecognized subcommand 'lst'\n\n  tip: some similar subcommands exist: 'lint', 'list'\n\nUsage: br [OPTIONS] <COMMAND>\n\nFor more information, try '--help'.\n"} : Cli.Parsed}

# S1.74 closed golden: goldens/usage_conflict_title.err — the first present argument that a present partner excludes
law cli_conflict_title:
  {Cli.parse(["create", "A", "--title", "B"]) == Cli.Refused{"error: the argument '[TITLE]' cannot be used with '--title <TITLE_FLAG>'\n\nUsage: br create <TITLE>\n\nFor more information, try '--help'.\n"} : Cli.Parsed}

# S1.14 S1.69 closed facts: a short cluster whose last letter takes the next word; `--` ends option parsing;
# a global before the command is an occurrence of the command
law cli_commands:
  {[Cli.parse(["list", "-rs", "open"]), Cli.parse(["show", "--", "--json"]), Cli.parse(["--json", "list", "-p1"])] == [Cli.Command{"list", [Cli.Occ{"reverse", ""}, Cli.Occ{"status", "open"}], []}, Cli.Command{"show", [], ["--json"]}, Cli.Command{"list", [Cli.Occ{"json", ""}, Cli.Occ{"priority", "1"}], []}] : List<&2, Cli.Parsed>}

# S1.25 S1.29 S1.89 closed facts (goldens usage_help_subcommand_list, usage_help_before_bad, usage_help_short_list,
# usage_dep_alone): `help list` asks for `list`'s long help; a help option stops the parse where it stands; `-h` is
# the short form; a bare group asks for its own long help
law cli_help_forms:
  {[Cli.parse(["help", "list"]), Cli.parse(["list", "--help", "--zzqq"]), Cli.parse(["list", "-h"]), Cli.parse(["dep"])] == [Cli.Helped{"list", True{}}, Cli.Helped{"list", True{}}, Cli.Helped{"list", False{}}, Cli.GroupHelp{"dep"}] : List<&2, Cli.Parsed>}

# S1.79 closed golden: goldens/usage_enum_similar_value.err — a refused word similar to a listed value earns a tip
law cli_similar_value:
  {Cli.parse(["count", "--by", "statu"]) == Cli.Refused{"error: invalid value 'statu' for '--by <BY>'\n  [possible values: status, priority, type, assignee, label]\n\n  tip: a similar value exists: 'status'\n\nFor more information, try '--help'.\n"} : Cli.Parsed}

# S4.107 closed facts: a priority word is an optional `P` and one digit 0..4, judged in upper case; 9 is "not a priority"
law query_priority_words:
  {[Query.priority_word(Query.shouted("p0")), Query.priority_word("4"), Query.priority_word(Query.shouted("nine")), Query.priority_word("P5"), Query.priority_word("")] == [0, 4, 9, 9, 9] : List<&2, U32>}

# S5.112 closed fact: the inline sanitizer writes tab, line feed and carriage return in their short forms, any other
# control character in hexadecimal without a leading zero, and leaves everything else alone
law render_inline_controls:
  {Render.inline(SCon{Chr{97}, SCon{Chr{9}, SCon{Chr{10}, SCon{Chr{13}, SCon{Chr{27}, SCon{Chr{7}, SCon{Chr{155}, SCon{Chr{233}, SNil{}}}}}}}}}) == "a\\t\\n\\r\\u{1b}\\u{7}\\u{9b}é" : String}

# S4.102 S4.115 S5.116 S5.120 closed golden: `list` over two records of fixture `basic` prints the two lines that
# goldens/list_plain.out shows for them, the P2 epic before the deferred P4 chore, which `list` does not hide
law run_list_two:
  {Run.outcome(Run.Inputs{["list"], True{}, "/mnt/proj", Bytes.utf8("{\"id\":\"proj-7vm\",\"title\":\"Refactor config loader\",\"status\":\"deferred\",\"priority\":4,\"issue_type\":\"chore\",\"created_at\":\"2026-01-01T10:00:05Z\",\"created_by\":\"tester\",\"updated_at\":\"2026-01-01T14:00:00Z\",\"defer_until\":\"2027-06-01T09:00:00Z\",\"source_repo\":\"proj\",\"source_repo_path\":\"/mnt/proj\",\"compaction_level\":0,\"original_size\":0}\n{\"id\":\"proj-uly\",\"title\":\"Auth epic\",\"status\":\"open\",\"priority\":2,\"issue_type\":\"epic\",\"created_at\":\"2026-01-01T10:00:04Z\",\"created_by\":\"tester\",\"updated_at\":\"2026-01-01T10:00:04Z\",\"source_repo\":\"proj\",\"source_repo_path\":\"/mnt/proj\",\"compaction_level\":0,\"original_size\":0}\n"), [], []}) == Run.Outcome{"○ proj-uly [● P2] [epic] - Auth epic\n❄ proj-7vm [● P4] [chore] - Refactor config loader\n", "", 0, []} : Run.Outcome}

# S4.144 S4.149 S5.162 closed fact: over the same two records `count --by-status` leaves the deferred one out
law run_count_two:
  {Run.outcome(Run.Inputs{["count", "--by-status"], True{}, "/mnt/proj", Bytes.utf8("{\"id\":\"proj-7vm\",\"title\":\"Refactor config loader\",\"status\":\"deferred\",\"priority\":4,\"issue_type\":\"chore\",\"created_at\":\"2026-01-01T10:00:05Z\",\"created_by\":\"tester\",\"updated_at\":\"2026-01-01T14:00:00Z\",\"defer_until\":\"2027-06-01T09:00:00Z\",\"source_repo\":\"proj\",\"source_repo_path\":\"/mnt/proj\",\"compaction_level\":0,\"original_size\":0}\n{\"id\":\"proj-uly\",\"title\":\"Auth epic\",\"status\":\"open\",\"priority\":2,\"issue_type\":\"epic\",\"created_at\":\"2026-01-01T10:00:04Z\",\"created_by\":\"tester\",\"updated_at\":\"2026-01-01T10:00:04Z\",\"source_repo\":\"proj\",\"source_repo_path\":\"/mnt/proj\",\"compaction_level\":0,\"original_size\":0}\n"), [], []}) == Run.Outcome{"Total: 1\nopen: 1\n", "", 0, []} : Run.Outcome}

# S4.157 S4.160 S4.161 S4.169 S5.137–S5.141 closed golden: over the three records of fixture `basic` that the
# BLOCKED relation involves (the feature, the task that blocks it, the epic it is a child of), `blocked` prints
# exactly goldens/blocked_plain.out: the feature by its direct blocker, the epic by its open child, in that order
law run_blocked_three:
  {Run.outcome(Run.Inputs{["blocked"], True{}, "/mnt/proj", Bytes.utf8("{\"id\":\"proj-170\",\"title\":\"Implement user auth\",\"status\":\"open\",\"priority\":1,\"issue_type\":\"feature\",\"assignee\":\"alice\",\"created_at\":\"2026-01-01T10:00:01Z\",\"created_by\":\"tester\",\"updated_at\":\"2026-01-01T11:00:00Z\",\"source_repo\":\"proj\",\"source_repo_path\":\"/mnt/proj\",\"compaction_level\":0,\"original_size\":0,\"labels\":[\"auth\",\"backend\"],\"dependencies\":[{\"issue_id\":\"proj-170\",\"depends_on_id\":\"proj-mta\",\"type\":\"blocks\",\"created_at\":\"2026-01-01T11:00:00Z\",\"created_by\":\"tester\",\"metadata\":\"{}\",\"thread_id\":\"\"},{\"issue_id\":\"proj-170\",\"depends_on_id\":\"proj-uly\",\"type\":\"parent-child\",\"created_at\":\"2026-01-01T11:00:00Z\",\"created_by\":\"tester\",\"metadata\":\"{}\",\"thread_id\":\"\"}]}\n{\"id\":\"proj-mta\",\"title\":\"Set up database schema\",\"description\":\"Create the initial tables.\",\"status\":\"open\",\"priority\":1,\"issue_type\":\"task\",\"created_at\":\"2026-01-01T10:00:00Z\",\"created_by\":\"tester\",\"updated_at\":\"2026-01-01T10:00:00Z\",\"source_repo\":\"proj\",\"source_repo_path\":\"/mnt/proj\",\"compaction_level\":0,\"original_size\":0,\"labels\":[\"backend\",\"db\"]}\n{\"id\":\"proj-uly\",\"title\":\"Auth epic\",\"status\":\"open\",\"priority\":2,\"issue_type\":\"epic\",\"created_at\":\"2026-01-01T10:00:04Z\",\"created_by\":\"tester\",\"updated_at\":\"2026-01-01T10:00:04Z\",\"source_repo\":\"proj\",\"source_repo_path\":\"/mnt/proj\",\"compaction_level\":0,\"original_size\":0}\n"), [], []}) == Run.Outcome{"\n🚫 Blocked issues (2):\n\n[● P1] proj-170: Implement user auth\n  Blocked by 1 open dependencies: [proj-mta]\n[● P2] proj-uly: Auth epic\n  Blocked by 1 open dependencies: [proj-170]\n", "", 0, []} : Run.Outcome}

# S4.7–S4.11 S4.200 S4.220 S5.2 S5.17 S5.203 closed golden: goldens/create_min — `create "First issue"` on an empty
# store, as the actor `tester`, at the pinned instant 1767323045 (2026-01-02T03:04:05Z), prints the `✓ Created` line,
# writes the one-line store the golden dumps and then the sidecar; the id comes out of the seed and the ladder
law run_create_min:
  {Run.outcome(Run.Inputs{["create", "First issue"], True{}, "/mnt/proj", [], [], [Run.Var{"USER", "tester"}, Run.Var{"BEADS_BEND_NOW", "1767323045"}]}) == Run.Outcome{"✓ Created proj-fyw: First issue\n", "", 0, [Run.Write{".beads/issues.jsonl", Some{"{\"id\":\"proj-fyw\",\"title\":\"First issue\",\"status\":\"open\",\"priority\":2,\"issue_type\":\"task\",\"created_at\":\"2026-01-02T03:04:05Z\",\"created_by\":\"tester\",\"updated_at\":\"2026-01-02T03:04:05Z\",\"source_repo\":\"proj\",\"source_repo_path\":\"/mnt/proj\",\"compaction_level\":0,\"original_size\":0}\n"}}, Run.Write{".beads/last-touched", Some{"proj-fyw\n"}}]} : Run.Outcome}

# S5.1–S5.6 S5.12–S5.15 closed golden (fixpoint): fixture `basic` is the original's own write-back, so loading it,
# repairing it and writing it back reproduces it byte for byte: the member order, the always-present members,
# the timestamps, the sorted labels, the edges with their three trailing members, the comments, the id order
law store_text_fixpoint_basic:
  {Store.rewritten(Store.load(Time.codes(Fixtures.basic()), "/mnt/proj/.beads/issues.jsonl")) == Fixtures.basic() : String}

# S4.41–S4.47 closed goldens and facts over the eight ids of fixture `basic`: the exact id in any case (step 1); a
# trimmed word without `-` behind the default prefix (step 2, golden show_partial_hash); a substring of the hash part
# (step 3); several candidates in ascending byte order (goldens/show_partial_ambiguous.err); nothing found
# (goldens/error_show_missing.err); a required prefix that no candidate has
law resolve_steps:
  {[Resolve.report(Resolve.resolve(["proj-170", "proj-5u2", "proj-7vm", "proj-b75", "proj-mkh", "proj-mta", "proj-ptp", "proj-uly"], "PROJ-MTA", "proj")), Resolve.report(Resolve.resolve(["proj-170", "proj-5u2", "proj-7vm", "proj-b75", "proj-mkh", "proj-mta", "proj-ptp", "proj-uly"], " mta ", "proj")), Resolve.report(Resolve.resolve(["proj-170", "proj-5u2", "proj-7vm", "proj-b75", "proj-mkh", "proj-mta", "proj-ptp", "proj-uly"], "7v", "proj")), Resolve.report(Resolve.resolve(["proj-170", "proj-5u2", "proj-7vm", "proj-b75", "proj-mkh", "proj-mta", "proj-ptp", "proj-uly"], "m", "proj")), Resolve.report(Resolve.resolve(["proj-170", "proj-5u2", "proj-7vm", "proj-b75", "proj-mkh", "proj-mta", "proj-ptp", "proj-uly"], "proj-zzz", "proj")), Resolve.report(Resolve.resolve(["proj-170", "proj-5u2", "proj-7vm", "proj-b75", "proj-mkh", "proj-mta", "proj-ptp", "proj-uly"], "other-mta", "proj"))] == ["proj-mta\n", "proj-mta\n", "proj-7vm\n", "Error: Ambiguous ID 'm': matches [\"proj-7vm\", \"proj-mkh\", \"proj-mta\"]\nHint: Provide more characters of the ID\n", "Error: Issue not found: proj-zzz\nHint: Run 'br list' to see available issues.\n", "Error: Issue not found: other-mta\nHint: Run 'br list' to see available issues.\n"] : List<&2, String>}

# S4.107 closed facts: a token with a `-` and text on both sides is a closed range, low to high inclusive; a reversed
# range, an end that is not a priority, and a missing end select nothing, which refuses the token
law query_priority_ranges:
  {[Query.picks_of(Query.cut_at_dash("0-2", [])), Query.picks_of(Query.cut_at_dash("P1-P3", [])), Query.picks_of(Query.cut_at_dash("2", [])), Query.picks_of(Query.cut_at_dash("3-1", [])), Query.picks_of(Query.cut_at_dash("1-9", [])), Query.picks_of(Query.cut_at_dash("1-", []))] == [[0, 1, 2], [1, 2, 3], [2], [], [], []] : List<&2, List<&2, U32>>}

# S4.353 S4.358 S4.362 closed fact (goldens/dep_add_duplicate): over the three records the BLOCKED relation of
# fixture `basic` involves, `dep add proj-170 proj-mta` finds the edge already there: the U+2192 line on stdout,
# exit 0, the store NOT rewritten, and `.beads/last-touched` naming the dependent all the same
law run_dep_add_duplicate:
  {Run.outcome(Run.Inputs{["dep", "add", "proj-170", "proj-mta"], True{}, "/mnt/proj", Bytes.utf8("{\"id\":\"proj-170\",\"title\":\"Implement user auth\",\"status\":\"open\",\"priority\":1,\"issue_type\":\"feature\",\"assignee\":\"alice\",\"created_at\":\"2026-01-01T10:00:01Z\",\"created_by\":\"tester\",\"updated_at\":\"2026-01-01T11:00:00Z\",\"source_repo\":\"proj\",\"source_repo_path\":\"/mnt/proj\",\"compaction_level\":0,\"original_size\":0,\"labels\":[\"auth\",\"backend\"],\"dependencies\":[{\"issue_id\":\"proj-170\",\"depends_on_id\":\"proj-mta\",\"type\":\"blocks\",\"created_at\":\"2026-01-01T11:00:00Z\",\"created_by\":\"tester\",\"metadata\":\"{}\",\"thread_id\":\"\"},{\"issue_id\":\"proj-170\",\"depends_on_id\":\"proj-uly\",\"type\":\"parent-child\",\"created_at\":\"2026-01-01T11:00:00Z\",\"created_by\":\"tester\",\"metadata\":\"{}\",\"thread_id\":\"\"}]}\n{\"id\":\"proj-mta\",\"title\":\"Set up database schema\",\"description\":\"Create the initial tables.\",\"status\":\"open\",\"priority\":1,\"issue_type\":\"task\",\"created_at\":\"2026-01-01T10:00:00Z\",\"created_by\":\"tester\",\"updated_at\":\"2026-01-01T10:00:00Z\",\"source_repo\":\"proj\",\"source_repo_path\":\"/mnt/proj\",\"compaction_level\":0,\"original_size\":0,\"labels\":[\"backend\",\"db\"]}\n{\"id\":\"proj-uly\",\"title\":\"Auth epic\",\"status\":\"open\",\"priority\":2,\"issue_type\":\"epic\",\"created_at\":\"2026-01-01T10:00:04Z\",\"created_by\":\"tester\",\"updated_at\":\"2026-01-01T10:00:04Z\",\"source_repo\":\"proj\",\"source_repo_path\":\"/mnt/proj\",\"compaction_level\":0,\"original_size\":0}\n"), [], [Run.Var{"USER", "tester"}, Run.Var{"BEADS_BEND_NOW", "1767323045"}]}) == Run.Outcome{"Dependency already exists: proj-170 → proj-mta\n", "", 0, [Run.Write{".beads/last-touched", Some{"proj-170\n"}}]} : Run.Outcome}

# S4.332 S4.333 closed golden (goldens/delete_with_dependents): over those same three records `delete proj-mta` is
# a PREVIEW: `proj-170` depends on it through a `blocks` edge, `proj-uly` is reached transitively because
# `proj-170` is its child, nothing is written and the exit code is 0
law run_delete_preview:
  {Run.outcome(Run.Inputs{["delete", "proj-mta"], True{}, "/mnt/proj", Bytes.utf8("{\"id\":\"proj-170\",\"title\":\"Implement user auth\",\"status\":\"open\",\"priority\":1,\"issue_type\":\"feature\",\"assignee\":\"alice\",\"created_at\":\"2026-01-01T10:00:01Z\",\"created_by\":\"tester\",\"updated_at\":\"2026-01-01T11:00:00Z\",\"source_repo\":\"proj\",\"source_repo_path\":\"/mnt/proj\",\"compaction_level\":0,\"original_size\":0,\"labels\":[\"auth\",\"backend\"],\"dependencies\":[{\"issue_id\":\"proj-170\",\"depends_on_id\":\"proj-mta\",\"type\":\"blocks\",\"created_at\":\"2026-01-01T11:00:00Z\",\"created_by\":\"tester\",\"metadata\":\"{}\",\"thread_id\":\"\"},{\"issue_id\":\"proj-170\",\"depends_on_id\":\"proj-uly\",\"type\":\"parent-child\",\"created_at\":\"2026-01-01T11:00:00Z\",\"created_by\":\"tester\",\"metadata\":\"{}\",\"thread_id\":\"\"}]}\n{\"id\":\"proj-mta\",\"title\":\"Set up database schema\",\"description\":\"Create the initial tables.\",\"status\":\"open\",\"priority\":1,\"issue_type\":\"task\",\"created_at\":\"2026-01-01T10:00:00Z\",\"created_by\":\"tester\",\"updated_at\":\"2026-01-01T10:00:00Z\",\"source_repo\":\"proj\",\"source_repo_path\":\"/mnt/proj\",\"compaction_level\":0,\"original_size\":0,\"labels\":[\"backend\",\"db\"]}\n{\"id\":\"proj-uly\",\"title\":\"Auth epic\",\"status\":\"open\",\"priority\":2,\"issue_type\":\"epic\",\"created_at\":\"2026-01-01T10:00:04Z\",\"created_by\":\"tester\",\"updated_at\":\"2026-01-01T10:00:04Z\",\"source_repo\":\"proj\",\"source_repo_path\":\"/mnt/proj\",\"compaction_level\":0,\"original_size\":0}\n"), [], [Run.Var{"USER", "tester"}, Run.Var{"BEADS_BEND_NOW", "1767323045"}]}) == Run.Outcome{"The following issues depend on issues being deleted:\n  - proj-170\n\n1 additional issue(s) would be transitively affected by --cascade:\n  - proj-uly\n\nUse --force to orphan these dependents, or --cascade to delete them recursively.\n--cascade would delete 2 total dependent(s).\nNo changes made (preview mode).\n", "", 0, []} : Run.Outcome}

# S4.154 S5.170 closed fact (goldens/scn_lifecycle, its last step): the four whole-hour lead times 2, 743, 743 and
# 744 average to 558 hours, which is 23.25 days; binary64 holds `.25` exactly and Rust's `{:.1}` rounds a tie to
# the even tenth, so the figure prints `23.2`. 22320 tenths over 24·4 hours is that division
law lead_tenths_quarter:
  {Work.tenths(22320, 96) == Some{232} : Maybe<&2, U32>}

# S5.170 OQ-078 refutation: a tie that binary64 does NOT hold exactly (here 3.5 tenths, the value `0.35`) is the
# one the port refuses instead of guessing which side the original's rounding of the double landed on
law lead_tenths_odd_tie_refused:
  {Work.tenths(7, 2) == None{} : Maybe<&2, U32>}

# S4.182–S4.185 S5.179 closed golden: goldens/dep_tree_repeat — `dep tree proj-6ja` over fixture `hierarchy`.
# The one case that reaches three branches at once: the sibling order falls to the STATUS RANK (both branches
# are priority 2, so `open` proj-0i4 precedes `in_progress` proj-t11 although the titles order the other way);
# proj-in9 is reached under both branches and HAS a child, so its second occurrence carries `repeat` and its
# subtree is not repeated; and that same occurrence also carries `truncated`, which wins the plain prefix
law run_dep_tree_repeat:
  {Run.outcome(Run.Inputs{["dep", "tree", "proj-6ja"], True{}, "/mnt/proj", Bytes.utf8("{\"id\":\"proj-0i4\",\"title\":\"Zeta open branch\",\"status\":\"open\",\"priority\":2,\"issue_type\":\"task\",\"created_at\":\"2026-06-01T09:00:01Z\",\"created_by\":\"tester\",\"updated_at\":\"2026-06-01T10:00:00Z\",\"source_repo\":\"proj\",\"source_repo_path\":\"/mnt/proj\",\"compaction_level\":0,\"original_size\":0,\"dependencies\":[{\"issue_id\":\"proj-0i4\",\"depends_on_id\":\"proj-in9\",\"type\":\"blocks\",\"created_at\":\"2026-06-01T10:00:00Z\",\"created_by\":\"tester\",\"metadata\":\"{}\",\"thread_id\":\"\"}]}\n{\"id\":\"proj-6ja\",\"title\":\"Hierarchy root\",\"status\":\"open\",\"priority\":1,\"issue_type\":\"feature\",\"created_at\":\"2026-06-01T09:00:00Z\",\"created_by\":\"tester\",\"updated_at\":\"2026-06-01T10:00:00Z\",\"source_repo\":\"proj\",\"source_repo_path\":\"/mnt/proj\",\"compaction_level\":0,\"original_size\":0,\"dependencies\":[{\"issue_id\":\"proj-6ja\",\"depends_on_id\":\"proj-0i4\",\"type\":\"blocks\",\"created_at\":\"2026-06-01T10:00:00Z\",\"created_by\":\"tester\",\"metadata\":\"{}\",\"thread_id\":\"\"},{\"issue_id\":\"proj-6ja\",\"depends_on_id\":\"proj-t11\",\"type\":\"blocks\",\"created_at\":\"2026-06-01T10:00:00Z\",\"created_by\":\"tester\",\"metadata\":\"{}\",\"thread_id\":\"\"}]}\n{\"id\":\"proj-ig8\",\"title\":\"Deep leaf\",\"status\":\"open\",\"priority\":4,\"issue_type\":\"task\",\"created_at\":\"2026-06-01T09:00:04Z\",\"created_by\":\"tester\",\"updated_at\":\"2026-06-01T09:00:04Z\",\"source_repo\":\"proj\",\"source_repo_path\":\"/mnt/proj\",\"compaction_level\":0,\"original_size\":0}\n{\"id\":\"proj-in9\",\"title\":\"Shared node with a child\",\"status\":\"open\",\"priority\":3,\"issue_type\":\"task\",\"created_at\":\"2026-06-01T09:00:03Z\",\"created_by\":\"tester\",\"updated_at\":\"2026-06-01T10:00:00Z\",\"source_repo\":\"proj\",\"source_repo_path\":\"/mnt/proj\",\"compaction_level\":0,\"original_size\":0,\"dependencies\":[{\"issue_id\":\"proj-in9\",\"depends_on_id\":\"proj-ig8\",\"type\":\"blocks\",\"created_at\":\"2026-06-01T10:00:00Z\",\"created_by\":\"tester\",\"metadata\":\"{}\",\"thread_id\":\"\"}]}\n{\"id\":\"proj-t11\",\"title\":\"Alpha busy branch\",\"status\":\"in_progress\",\"priority\":2,\"issue_type\":\"task\",\"created_at\":\"2026-06-01T09:00:02Z\",\"created_by\":\"tester\",\"updated_at\":\"2026-06-01T10:00:00Z\",\"source_repo\":\"proj\",\"source_repo_path\":\"/mnt/proj\",\"compaction_level\":0,\"original_size\":0,\"dependencies\":[{\"issue_id\":\"proj-t11\",\"depends_on_id\":\"proj-in9\",\"type\":\"blocks\",\"created_at\":\"2026-06-01T10:00:00Z\",\"created_by\":\"tester\",\"metadata\":\"{}\",\"thread_id\":\"\"}]}\n"), [], []}) == Run.Outcome{"proj-6ja: Hierarchy root [P1] [open]\n  ├── proj-0i4: Zeta open branch [P2] [open]\n    ├── proj-in9: Shared node with a child [P3] [open]\n      ├── proj-ig8: Deep leaf [P4] [open]\n  ├── proj-t11: Alpha busy branch [P2] [in_progress]\n    ├── (truncated) proj-in9: Shared node with a child [P3] [open]\n", "", 0, []} : Run.Outcome}

# S4.394 S5.253 closed golden: goldens/dep_tree_mermaid — `dep tree proj-6ja --format mermaid` over fixture
# `hierarchy`. The same walk as run_dep_tree_repeat, rendered as mermaid: the nodes in pre-order as n0…n5, the
# repeated proj-in9 a node of its own (n5) with no mark, and each edge drawn from the PLACE of its parent (n4 → n5,
# not from the first proj-in9), in the order of the nodes the edges lead into
law run_dep_tree_mermaid:
  {Run.outcome(Run.Inputs{["dep", "tree", "proj-6ja", "--format", "mermaid"], True{}, "/mnt/proj", Bytes.utf8("{\"id\":\"proj-0i4\",\"title\":\"Zeta open branch\",\"status\":\"open\",\"priority\":2,\"issue_type\":\"task\",\"created_at\":\"2026-06-01T09:00:01Z\",\"created_by\":\"tester\",\"updated_at\":\"2026-06-01T10:00:00Z\",\"source_repo\":\"proj\",\"source_repo_path\":\"/mnt/proj\",\"compaction_level\":0,\"original_size\":0,\"dependencies\":[{\"issue_id\":\"proj-0i4\",\"depends_on_id\":\"proj-in9\",\"type\":\"blocks\",\"created_at\":\"2026-06-01T10:00:00Z\",\"created_by\":\"tester\",\"metadata\":\"{}\",\"thread_id\":\"\"}]}\n{\"id\":\"proj-6ja\",\"title\":\"Hierarchy root\",\"status\":\"open\",\"priority\":1,\"issue_type\":\"feature\",\"created_at\":\"2026-06-01T09:00:00Z\",\"created_by\":\"tester\",\"updated_at\":\"2026-06-01T10:00:00Z\",\"source_repo\":\"proj\",\"source_repo_path\":\"/mnt/proj\",\"compaction_level\":0,\"original_size\":0,\"dependencies\":[{\"issue_id\":\"proj-6ja\",\"depends_on_id\":\"proj-0i4\",\"type\":\"blocks\",\"created_at\":\"2026-06-01T10:00:00Z\",\"created_by\":\"tester\",\"metadata\":\"{}\",\"thread_id\":\"\"},{\"issue_id\":\"proj-6ja\",\"depends_on_id\":\"proj-t11\",\"type\":\"blocks\",\"created_at\":\"2026-06-01T10:00:00Z\",\"created_by\":\"tester\",\"metadata\":\"{}\",\"thread_id\":\"\"}]}\n{\"id\":\"proj-ig8\",\"title\":\"Deep leaf\",\"status\":\"open\",\"priority\":4,\"issue_type\":\"task\",\"created_at\":\"2026-06-01T09:00:04Z\",\"created_by\":\"tester\",\"updated_at\":\"2026-06-01T09:00:04Z\",\"source_repo\":\"proj\",\"source_repo_path\":\"/mnt/proj\",\"compaction_level\":0,\"original_size\":0}\n{\"id\":\"proj-in9\",\"title\":\"Shared node with a child\",\"status\":\"open\",\"priority\":3,\"issue_type\":\"task\",\"created_at\":\"2026-06-01T09:00:03Z\",\"created_by\":\"tester\",\"updated_at\":\"2026-06-01T10:00:00Z\",\"source_repo\":\"proj\",\"source_repo_path\":\"/mnt/proj\",\"compaction_level\":0,\"original_size\":0,\"dependencies\":[{\"issue_id\":\"proj-in9\",\"depends_on_id\":\"proj-ig8\",\"type\":\"blocks\",\"created_at\":\"2026-06-01T10:00:00Z\",\"created_by\":\"tester\",\"metadata\":\"{}\",\"thread_id\":\"\"}]}\n{\"id\":\"proj-t11\",\"title\":\"Alpha busy branch\",\"status\":\"in_progress\",\"priority\":2,\"issue_type\":\"task\",\"created_at\":\"2026-06-01T09:00:02Z\",\"created_by\":\"tester\",\"updated_at\":\"2026-06-01T10:00:00Z\",\"source_repo\":\"proj\",\"source_repo_path\":\"/mnt/proj\",\"compaction_level\":0,\"original_size\":0,\"dependencies\":[{\"issue_id\":\"proj-t11\",\"depends_on_id\":\"proj-in9\",\"type\":\"blocks\",\"created_at\":\"2026-06-01T10:00:00Z\",\"created_by\":\"tester\",\"metadata\":\"{}\",\"thread_id\":\"\"}]}\n"), [], []}) == Run.Outcome{"graph TD\n    n0[\"proj-6ja: Hierarchy root [P1]\"]\n    n1[\"proj-0i4: Zeta open branch [P2]\"]\n    n2[\"proj-in9: Shared node with a child [P3]\"]\n    n3[\"proj-ig8: Deep leaf [P4]\"]\n    n4[\"proj-t11: Alpha busy branch [P2]\"]\n    n5[\"proj-in9: Shared node with a child [P3]\"]\n    n0 --> n1\n    n1 --> n2\n    n2 --> n3\n    n0 --> n4\n    n4 --> n5\n", "", 0, []} : Run.Outcome}

# S4.189–S4.192 fast == spec, closed: `epic status --json` over fixture `parents` (an epic with three children, one of
# them with a child of its own, and a loose task) answers the same with the one-pass children table (the default)
# as with the per-epic scan of the store that `BEADS_RUST_SPEC=1` selects (Work.child_index). One value, not a
# quantified property: the corpus's epic cases run the table on every lane, and kill-switch parity is the second check
law run_epic_status_spec_switch:
  {Run.outcome(Run.Inputs{["epic", "status", "--json"], True{}, "/mnt/proj", Bytes.utf8("{\"id\":\"proj-3av\",\"title\":\"Loose task\",\"status\":\"open\",\"priority\":2,\"issue_type\":\"task\",\"created_at\":\"2026-04-05T06:07:08Z\",\"created_by\":\"tester\",\"updated_at\":\"2026-04-05T06:07:08Z\",\"source_repo\":\"proj\",\"source_repo_path\":\"/mnt/proj\",\"compaction_level\":0,\"original_size\":0}\n{\"id\":\"proj-9vo\",\"title\":\"Parent epic\",\"status\":\"open\",\"priority\":1,\"issue_type\":\"epic\",\"created_at\":\"2026-04-05T06:07:08Z\",\"created_by\":\"tester\",\"updated_at\":\"2026-04-05T06:07:08Z\",\"source_repo\":\"proj\",\"source_repo_path\":\"/mnt/proj\",\"compaction_level\":0,\"original_size\":0}\n{\"id\":\"proj-9vo.1\",\"title\":\"Child one\",\"status\":\"open\",\"priority\":2,\"issue_type\":\"task\",\"created_at\":\"2026-04-05T06:07:08Z\",\"created_by\":\"tester\",\"updated_at\":\"2026-04-05T06:07:08Z\",\"source_repo\":\"proj\",\"source_repo_path\":\"/mnt/proj\",\"compaction_level\":0,\"original_size\":0,\"dependencies\":[{\"issue_id\":\"proj-9vo.1\",\"depends_on_id\":\"proj-9vo\",\"type\":\"parent-child\",\"created_at\":\"2026-04-05T06:07:08Z\",\"created_by\":\"tester\",\"metadata\":\"{}\",\"thread_id\":\"\"}]}\n{\"id\":\"proj-9vo.1.1\",\"title\":\"Grandchild\",\"status\":\"open\",\"priority\":1,\"issue_type\":\"task\",\"created_at\":\"2026-04-05T06:07:08Z\",\"created_by\":\"tester\",\"updated_at\":\"2026-04-05T06:07:08Z\",\"source_repo\":\"proj\",\"source_repo_path\":\"/mnt/proj\",\"compaction_level\":0,\"original_size\":0,\"dependencies\":[{\"issue_id\":\"proj-9vo.1.1\",\"depends_on_id\":\"proj-9vo.1\",\"type\":\"parent-child\",\"created_at\":\"2026-04-05T06:07:08Z\",\"created_by\":\"tester\",\"metadata\":\"{}\",\"thread_id\":\"\"}]}\n{\"id\":\"proj-9vo.2\",\"title\":\"Child two\",\"status\":\"open\",\"priority\":3,\"issue_type\":\"task\",\"created_at\":\"2026-04-05T06:07:08Z\",\"created_by\":\"tester\",\"updated_at\":\"2026-04-05T06:07:08Z\",\"source_repo\":\"proj\",\"source_repo_path\":\"/mnt/proj\",\"compaction_level\":0,\"original_size\":0,\"dependencies\":[{\"issue_id\":\"proj-9vo.2\",\"depends_on_id\":\"proj-9vo\",\"type\":\"parent-child\",\"created_at\":\"2026-04-05T06:07:08Z\",\"created_by\":\"tester\",\"metadata\":\"{}\",\"thread_id\":\"\"}]}\n{\"id\":\"proj-9vo.3\",\"title\":\"Blocked child\",\"status\":\"open\",\"priority\":0,\"issue_type\":\"task\",\"created_at\":\"2026-04-05T06:07:08Z\",\"created_by\":\"tester\",\"updated_at\":\"2026-04-05T06:07:08Z\",\"source_repo\":\"proj\",\"source_repo_path\":\"/mnt/proj\",\"compaction_level\":0,\"original_size\":0,\"dependencies\":[{\"issue_id\":\"proj-9vo.3\",\"depends_on_id\":\"proj-3av\",\"type\":\"blocks\",\"created_at\":\"2026-04-05T06:07:08Z\",\"created_by\":\"tester\",\"metadata\":\"{}\",\"thread_id\":\"\"},{\"issue_id\":\"proj-9vo.3\",\"depends_on_id\":\"proj-9vo\",\"type\":\"parent-child\",\"created_at\":\"2026-04-05T06:07:08Z\",\"created_by\":\"tester\",\"metadata\":\"{}\",\"thread_id\":\"\"}]}\n"), [], []}) == Run.outcome(Run.Inputs{["epic", "status", "--json"], True{}, "/mnt/proj", Bytes.utf8("{\"id\":\"proj-3av\",\"title\":\"Loose task\",\"status\":\"open\",\"priority\":2,\"issue_type\":\"task\",\"created_at\":\"2026-04-05T06:07:08Z\",\"created_by\":\"tester\",\"updated_at\":\"2026-04-05T06:07:08Z\",\"source_repo\":\"proj\",\"source_repo_path\":\"/mnt/proj\",\"compaction_level\":0,\"original_size\":0}\n{\"id\":\"proj-9vo\",\"title\":\"Parent epic\",\"status\":\"open\",\"priority\":1,\"issue_type\":\"epic\",\"created_at\":\"2026-04-05T06:07:08Z\",\"created_by\":\"tester\",\"updated_at\":\"2026-04-05T06:07:08Z\",\"source_repo\":\"proj\",\"source_repo_path\":\"/mnt/proj\",\"compaction_level\":0,\"original_size\":0}\n{\"id\":\"proj-9vo.1\",\"title\":\"Child one\",\"status\":\"open\",\"priority\":2,\"issue_type\":\"task\",\"created_at\":\"2026-04-05T06:07:08Z\",\"created_by\":\"tester\",\"updated_at\":\"2026-04-05T06:07:08Z\",\"source_repo\":\"proj\",\"source_repo_path\":\"/mnt/proj\",\"compaction_level\":0,\"original_size\":0,\"dependencies\":[{\"issue_id\":\"proj-9vo.1\",\"depends_on_id\":\"proj-9vo\",\"type\":\"parent-child\",\"created_at\":\"2026-04-05T06:07:08Z\",\"created_by\":\"tester\",\"metadata\":\"{}\",\"thread_id\":\"\"}]}\n{\"id\":\"proj-9vo.1.1\",\"title\":\"Grandchild\",\"status\":\"open\",\"priority\":1,\"issue_type\":\"task\",\"created_at\":\"2026-04-05T06:07:08Z\",\"created_by\":\"tester\",\"updated_at\":\"2026-04-05T06:07:08Z\",\"source_repo\":\"proj\",\"source_repo_path\":\"/mnt/proj\",\"compaction_level\":0,\"original_size\":0,\"dependencies\":[{\"issue_id\":\"proj-9vo.1.1\",\"depends_on_id\":\"proj-9vo.1\",\"type\":\"parent-child\",\"created_at\":\"2026-04-05T06:07:08Z\",\"created_by\":\"tester\",\"metadata\":\"{}\",\"thread_id\":\"\"}]}\n{\"id\":\"proj-9vo.2\",\"title\":\"Child two\",\"status\":\"open\",\"priority\":3,\"issue_type\":\"task\",\"created_at\":\"2026-04-05T06:07:08Z\",\"created_by\":\"tester\",\"updated_at\":\"2026-04-05T06:07:08Z\",\"source_repo\":\"proj\",\"source_repo_path\":\"/mnt/proj\",\"compaction_level\":0,\"original_size\":0,\"dependencies\":[{\"issue_id\":\"proj-9vo.2\",\"depends_on_id\":\"proj-9vo\",\"type\":\"parent-child\",\"created_at\":\"2026-04-05T06:07:08Z\",\"created_by\":\"tester\",\"metadata\":\"{}\",\"thread_id\":\"\"}]}\n{\"id\":\"proj-9vo.3\",\"title\":\"Blocked child\",\"status\":\"open\",\"priority\":0,\"issue_type\":\"task\",\"created_at\":\"2026-04-05T06:07:08Z\",\"created_by\":\"tester\",\"updated_at\":\"2026-04-05T06:07:08Z\",\"source_repo\":\"proj\",\"source_repo_path\":\"/mnt/proj\",\"compaction_level\":0,\"original_size\":0,\"dependencies\":[{\"issue_id\":\"proj-9vo.3\",\"depends_on_id\":\"proj-3av\",\"type\":\"blocks\",\"created_at\":\"2026-04-05T06:07:08Z\",\"created_by\":\"tester\",\"metadata\":\"{}\",\"thread_id\":\"\"},{\"issue_id\":\"proj-9vo.3\",\"depends_on_id\":\"proj-9vo\",\"type\":\"parent-child\",\"created_at\":\"2026-04-05T06:07:08Z\",\"created_by\":\"tester\",\"metadata\":\"{}\",\"thread_id\":\"\"}]}\n"), [], [Run.Var{"BEADS_RUST_SPEC", "1"}]}) : Run.Outcome}
