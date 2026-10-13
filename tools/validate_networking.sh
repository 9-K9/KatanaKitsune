#!/usr/bin/env bash
# Runs validate_networking.gd as a real server + client pair of headless
# processes and reports combined PASS/FAIL. See tools/README.md.
set -u

PORT="${1:-8955}"
PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SERVER_LOG="$(mktemp)"
CLIENT_LOG="$(mktemp)"

cd "$PROJECT_DIR" || exit 1

godot --headless --path . res://tools/validate_networking.tscn --max-fps 120 \
	-- --role=server --port="$PORT" > "$SERVER_LOG" 2>&1 &
SERVER_PID=$!

# Give the server a moment to bind the port before the client dials in.
sleep 1.5

godot --headless --path . res://tools/validate_networking.tscn --max-fps 120 \
	-- --role=client --port="$PORT" > "$CLIENT_LOG" 2>&1
CLIENT_STATUS=$?

wait "$SERVER_PID"
SERVER_STATUS=$?

echo "--- server ---"
cat "$SERVER_LOG"
echo "--- client ---"
cat "$CLIENT_LOG"
rm -f "$SERVER_LOG" "$CLIENT_LOG"

if [ "$SERVER_STATUS" -ne 0 ] || [ "$CLIENT_STATUS" -ne 0 ]; then
	echo "validate_networking: FAILED (server=$SERVER_STATUS client=$CLIENT_STATUS)"
	exit 1
fi
echo "validate_networking: PASSED"
