#!/usr/bin/env bash
# ws-run: run ONE conformance case of a workspace-stateful CLI inside a
# hermetic sandbox, identically for the original and for every port lane.
#
# `br` is stateful (a `.beads/` directory), writes the absolute workspace path
# into records, and derives ids and timestamps from the wall clock. A case is
# therefore only reproducible when every run sees: a fresh workspace at one
# fixed path (/mnt/proj, a bubblewrap tmpfs that vanishes with the process, so
# nothing is ever deleted), a named fixture, a cleared environment, and one
# pinned instant. The original gets the instant through libfaketime; the port
# through its BEADS_BEND_NOW seam (DISC, class test-seam).
#
# usage: ws-run.sh [--oracle] <inner command…> :: <case args…>
#   --oracle   the inner command is the original: preload libfaketime
#   case args  [@fx=<fixture>] [@time=<YYYY-MM-DD hh:mm:ss[.fraction]>] <argv of the CLI…>
#              or  @scn=<scenario>  (goldens/scenarios/<scenario>.scn, multi-step)
#              @store=<absolute path> instead of @fx: an external store (the real-store sweep, never a golden)
#              @fx=nostore: a `.beads/` directory with nothing in it; a fixture's `<name>.redirect` sidecar is
#              copied as `.beads/redirect`
#              @env=NAME=VALUE (repeatable): one more environment variable for the step, both sides alike
#              @cwd=<relative dir>: run the step from that directory below /mnt/proj (created)
#              @ls: after the step, `--- ls .beads ---` and every path under `.beads/` (a file with its size)
# Capture:  scripts/golden-capture.sh goldens/cases.tsv goldens -- scripts/ws-run.sh --oracle br --no-db ::
# Lanes:    LANE_WRAP=scripts/ws-run.sh scripts/lanes.sh goldens/cases.tsv goldens "$PWD/port/main.bend"
# exit: the CLI's exit code (single step) or 0 (scenario; each step prints its
#       own `[exit N]`); 125 sandbox or usage failure (INCONCLUSIVE in conform).
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/.." && pwd)"
if [[ "${1:-}" == --help || "${1:-}" == -h ]]; then sed -n '2,/^set -/p' "$0" | sed '$d; s/^# \{0,1\}//'; exit 0; fi
command -v bwrap >/dev/null 2>&1 || { echo 'ws-run: bwrap (bubblewrap) is required' >&2; exit 125; }
BEND_BIN="${BEND_BIN:-$HOME/.bend/bin/bend}"
# The filesystem is read-only inside the sandbox except the tmpfs workspace
# and the temp directories: lanes.sh builds its binaries under TMPDIR and its
# interpreter lane appends the compiler's pre-run note to a file there.
TMPBIND=()
if [[ -n "${TMPDIR:-}" && -d "$TMPDIR" && "${TMPDIR%/}" != /tmp ]]; then TMPBIND=(--bind "$TMPDIR" "$TMPDIR"); fi
exec bwrap --die-with-parent --ro-bind / / --bind /tmp /tmp "${TMPBIND[@]}" --dev /dev --proc /proc \
  --tmpfs /mnt --chdir /mnt --clearenv \
  --setenv PATH "$PATH" --setenv HOME /mnt/home --setenv USER tester --setenv TZ UTC \
  --setenv NO_COLOR 1 --setenv RUST_LOG error --setenv BEND_NO_TELEMETRY 1 \
  --setenv BEND_BIN "$BEND_BIN" --setenv WS_ROOT "$ROOT" \
  python3 -B "$HERE/ws_inner.py" "$@"
