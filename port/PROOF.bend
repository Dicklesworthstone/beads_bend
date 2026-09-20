# BEADS_RUST — the proofs. The agent's file: imports the code and the laws and
# fills every law with `def Laws.<name>(params)`. Lemmas go above their
# first use. Gate:  bend PROOF.bend  →  "All terms check." (state the
# unsafe count from the same output beside every parity claim).
import Base
import ./main.bend as L
import ./core/bytes.bend as Bytes
import ./core/sha256.bend as Sha
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
