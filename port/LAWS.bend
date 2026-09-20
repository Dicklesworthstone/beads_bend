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
