# BEADS_RUST — the proofs. The agent's file: imports the code and the laws and
# fills every law with `def Laws.<name>(params)`. Lemmas go above their
# first use. Gate:  bend PROOF.bend  →  "All terms check." (state the
# unsafe count from the same output beside every parity claim).
import Base
import ./main.bend as L
import ./core/bytes.bend as Bytes
import ./core/sha256.bend as Sha
import ./core/id.bend as Id
import ./core/time.bend as Time
import ./core/model.bend as Model
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
