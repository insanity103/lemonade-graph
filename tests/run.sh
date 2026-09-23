#!/usr/bin/env bash
# tests/run.sh | Run the headless test suite (no Roblox, no Studio).
#
#   tests/run.sh                 # everything, full sample sizes (what CI runs)
#   tests/run.sh --quick         # sample sizes x0.1, for iterating locally
#   tests/run.sh spin_pools      # only tests whose "spec > name" contains this text
#   tests/run.sh --strict        # known issues (confirmed game defects) fail the run too
#   tests/run.sh --seed 42       # a different RNG seed (default is fixed, so runs repeat exactly)
#
# Needs Lune: tools/install_lune.sh installs the pinned version to ~/.local/bin. Set LUNE=/path/to/lune
# to use another binary. Exit status is non-zero when any test fails.
set -euo pipefail
cd "$(dirname "$0")/.."

PINNED="$(sed -n 's/^LUNE_VERSION="\(.*\)"$/\1/p' tools/install_lune.sh)"
LUNE="${LUNE:-}"
if [ -z "$LUNE" ]; then
	if command -v lune >/dev/null 2>&1; then
		LUNE="$(command -v lune)"
	elif [ -x "$HOME/.local/bin/lune" ]; then
		LUNE="$HOME/.local/bin/lune"
	else
		echo "tests/run.sh: lune not found. Install the pinned version with: tools/install_lune.sh" >&2
		exit 127
	fi
fi
have="$("$LUNE" --version 2>/dev/null | awk '{print $2}')"
if [ -n "$PINNED" ] && [ "$have" != "$PINNED" ]; then
	echo "tests/run.sh: warning: $LUNE is lune $have, the suite is pinned to $PINNED (tools/install_lune.sh)" >&2
fi
exec "$LUNE" run tests/run.luau "$@"
