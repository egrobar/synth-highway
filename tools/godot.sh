#!/usr/bin/env bash
# Runs Godot on the game project, one invocation at a time.
#
# Several people or agents may build regions at once, and two Godot processes
# importing the same project at the same time can corrupt its import cache. This
# waits for a lock directory, runs Godot, and always releases the lock.
# Usage: tools/godot.sh [godot args...]          (--path game is added for you)
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
export PATH="/opt/homebrew/bin:$PATH"
LOCK="${TMPDIR:-/tmp}/synth-highway-godot.lock"
until mkdir "$LOCK" 2>/dev/null; do sleep 1; done
trap 'rmdir "$LOCK"' EXIT
godot --path "$ROOT/game" "$@"
