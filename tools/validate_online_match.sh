#!/usr/bin/env bash
# Runs validate_online_match.gd as a real server + client pair of headless
# processes and reports combined PASS/FAIL. See tools/README.md.
set -u

PORT="${1:-8960}"
GODOT_BIN="${GODOT:-godot}"
PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SERVER_LOG="$(mktemp)"
CLIENT_LOG="$(mktemp)"
TIMEOUT_SECONDS=150

cleanup() {
	rm -f "$SERVER_LOG" "$CLIENT_LOG"
}
trap cleanup EXIT

if ! command -v "$GODOT_BIN" >/dev/null 2>&1; then
	echo "validate_online_match: Godot executable not found: $GODOT_BIN" >&2
	exit 127
fi

cd "$PROJECT_DIR" || exit 1

timeout "${TIMEOUT_SECONDS}s" "$GODOT_BIN" --headless --path . \
	res://tools/validate_online_match.tscn --max-fps 120 \
	-- --role=server --port="$PORT" > "$SERVER_LOG" 2>&1 &
SERVER_PID=$!

# Give the server a moment to bind the port before the client dials in.
sleep 1.5

timeout "${TIMEOUT_SECONDS}s" "$GODOT_BIN" --headless --path . \
	res://tools/validate_online_match.tscn --max-fps 120 \
	-- --role=client --port="$PORT" > "$CLIENT_LOG" 2>&1
CLIENT_STATUS=$?

wait "$SERVER_PID"
SERVER_STATUS=$?

echo "--- server ---"
cat "$SERVER_LOG"
echo "--- client ---"
cat "$CLIENT_LOG"

# Both sides print "SEED: ..." once per floor; identical lines mean identical floors.
if ! diff <(grep '^SEED:' "$SERVER_LOG") <(grep '^SEED:' "$CLIENT_LOG") >/dev/null; then
	echo "validate_online_match: FAILED (server and client built different floors)"
	exit 1
fi
echo "PASS: server and client floors share seeds"

if [ "$SERVER_STATUS" -ne 0 ] || [ "$CLIENT_STATUS" -ne 0 ]; then
	echo "validate_online_match: FAILED (server=$SERVER_STATUS client=$CLIENT_STATUS)"
	exit 1
fi
echo "validate_online_match: PASSED"
