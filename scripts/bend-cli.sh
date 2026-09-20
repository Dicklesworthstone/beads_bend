#!/usr/bin/env bash
# bend-cli.sh: the pinned Bend CLI for this port's harness (PLAN §2b).
#
# Bend 2.0.17 replaced `bend --version` with `bend version`; the harness was
# written against 2.0.16 and still asks `--version`. This wrapper translates
# that one spelling and passes every other argument through unchanged, so
# the scripts run unmodified. Point BEND_CLI at it:
#
#   export BEND_CLI=/data/projects/beads_bend/scripts/bend-cli.sh
#
# BEND_BIN overrides the binary (default: the official installer's layout).
# exit: the wrapped command's; 127 when no bend binary is found.
set -eu
BIN="${BEND_BIN:-$HOME/.bend/bin/bend}"
[[ -x "$BIN" ]] || { echo "bend-cli: no bend at $BIN (install the pinned release: docs/PLAN_TO_PORT_BEADS_RUST_TO_BEND2.md §2b; download the installer, read it, verify its sha256, then run it)" >&2; exit 127; }
export BEND_NO_TELEMETRY="${BEND_NO_TELEMETRY:-1}"
if [[ $# -eq 1 && "$1" == "--version" ]]; then exec "$BIN" version; fi
exec "$BIN" "$@"
