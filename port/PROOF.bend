# BEADS_RUST — the proofs. The agent's file: imports the code and the laws and
# fills every law with `def Laws.<name>(params)`. Lemmas go above their
# first use. Gate:  bend PROOF.bend  →  "All terms check." (state the
# unsafe count from the same output beside every parity claim).
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
import ./core/run.bend as Run
import ./LAWS.bend as Laws

# S0.1 both twins are the identity; the checker sees it by computation
def Laws.fast_is_spec(x):
  {==}

# S4.4 the checker computes the digest of the empty message
def Laws.sha_empty():
  {==}

# S4.4 the checker computes the digest of "abc"
def Laws.sha_abc():
  {==}

# S4.4 the checker computes a two-block digest
def Laws.sha_two_blocks():
  {==}

# S4.1–S4.6 the checker computes the id
def Laws.id_fyw():
  {==}

# S4.1–S4.6 the checker computes the id
def Laws.id_mta():
  {==}

# S4.1–S4.6 the checker computes the id
def Laws.id_170():
  {==}

# S4.16 the checker computes the id
def Laws.id_q_asw():
  {==}

# S4.11 the checker computes the id
def Laws.id_ladder_0():
  {==}

# S4.11 the checker computes the id
def Laws.id_ladder_1():
  {==}

# S4.11 the checker computes the id
def Laws.id_ladder_2():
  {==}

# the checker parses, normalizes and prints the instant
def Laws.time_whole_second():
  {==}

# the checker parses, normalizes and prints the instant
def Laws.time_millis():
  {==}

# the checker parses, normalizes and prints the instant
def Laws.time_nanos():
  {==}

# the checker parses, normalizes and prints the instant
def Laws.time_tenth_widens():
  {==}

# the checker parses, normalizes and prints the instant
def Laws.time_offset_to_utc():
  {==}

# the checker parses, normalizes and prints the instant
def Laws.time_borrow_across_month():
  {==}

# the checker parses, normalizes and prints the instant
def Laws.time_borrow_into_leap_day():
  {==}

# the checker parses, normalizes and prints the instant
def Laws.time_carry_across_year():
  {==}

# the checker parses, normalizes and prints the instant
def Laws.time_micros():
  {==}

# the checker parses, normalizes and prints the instant
def Laws.time_lowercase_t_z():
  {==}

# the checker parses, normalizes and prints the instant
def Laws.time_refuses_feb_30():
  {==}

# the checker parses, normalizes and prints the instant
def Laws.time_refuses_words():
  {==}

# the checker parses, normalizes and prints the instant
def Laws.time_refuses_hour_24():
  {==}

# the checker parses, normalizes and prints the instant
def Laws.time_refuses_no_zone():
  {==}

# S4.64 the suffix is a formatter argument
def Laws.time_offset_suffix():
  {==}

# S5.2 S5.4 S5.5 S5.6 the checker renders the record and compares it with the captured line
def Laws.store_line_create_min():
  {==}

# S2.24 S2.27 the checker splits, lexes and decodes the fixture and renders the refusal
def Laws.store_refuses_malformed():
  {==}

# S4.9 the checker evaluates the table at each edge
def Laws.id_length_table():
  {==}


# S1.21 the checker parses the argv and compares the refusal with the captured bytes
def Laws.cli_limit_bad():
  {==}

# S1.22 the checker reads the digits, compares magnitudes and renders the range message
def Laws.cli_u8_range():
  {==}

# S1.81 the checker scores every long name of `list` against `jsno` and keeps the best
def Laws.cli_similar_flag():
  {==}

# S1.82 the checker scores all 52 top-level words against `lst` and sorts the close ones
def Laws.cli_similar_subcommand():
  {==}

# S1.74 the checker finds the first excluded pair in first-seen order
def Laws.cli_conflict_title():
  {==}

# S1.14 S1.69 the checker parses three accepted command lines
def Laws.cli_commands():
  {==}

# S1.25 S1.29 S1.89 the checker follows the help forms
def Laws.cli_help_forms():
  {==}

# S1.79 the checker scores the five listed values against `statu`
def Laws.cli_similar_value():
  {==}

# S4.107 the checker reads five priority words
def Laws.query_priority_words():
  {==}

# S5.112 the checker sanitizes eight code points
def Laws.render_inline_controls():
  {==}

# S4.102 S4.115 S5.116 the checker runs the whole pure program on a two-record store
def Laws.run_list_two():
  {==}

# S4.144 S4.149 S5.162 the checker runs `count --by-status` on the same store
def Laws.run_count_two():
  {==}

# S4.107 the checker cuts six tokens and spans their ranges
def Laws.query_priority_ranges():
  {==}
