# BEADS_RUST — the proofs. The agent's file: imports the code and the laws and
# fills every law with `def Laws.<name>(params)`. Lemmas go above their
# first use. Gate:  bend PROOF.bend  →  "All terms check." (state the
# unsafe count from the same output beside every parity claim).
import Base
import ./main.bend as L
import ./LAWS.bend as Laws

# S0.1 both twins are the identity; the checker sees it by computation
def Laws.fast_is_spec(x):
  {==}
