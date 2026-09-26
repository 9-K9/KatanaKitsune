#!/usr/bin/env bash
# Runs the scene connection checker without needing godot on PATH.
#
#   tools/check-connections.sh                          # every scene
#   tools/check-connections.sh scenes/title_screen.tscn # just one
#
# Override the engine with:  GODOT=/path/to/godot tools/check-connections.sh
set -euo pipefail

find_godot() {
	if [[ -n "${GODOT:-}" ]]; then
		printf '%s' "$GODOT"; return 0
	fi
	for candidate in godot godot4 Godot; do
		if command -v "$candidate" >/dev/null 2>&1; then
			printf '%s' "$candidate"; return 0
		fi
	done
	# Loose install, newest first. Godot ships as a bare versioned binary and
	# people rarely put it on PATH.
	local found
	found=$(find "$HOME" -maxdepth 3 -type f -name 'Godot_v4*_linux.x86_64' 2>/dev/null | sort -V | tail -1)
	if [[ -n "$found" ]]; then
		printf '%s' "$found"; return 0
	fi
	return 1
}

if ! GODOT_BIN=$(find_godot); then
	echo "Could not find a Godot 4 binary." >&2
	echo "Set one explicitly:  GODOT=/path/to/godot $0" >&2
	exit 127
fi

cd "$(dirname "$0")/.."
exec "$GODOT_BIN" --headless --script res://tools/check_scene_connections.gd -- "$@"
