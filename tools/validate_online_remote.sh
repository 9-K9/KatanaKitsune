#!/usr/bin/env bash
# Plays a two-client match against a *live* dedicated server (the Droplet, by
# default) using validate_online_match.gd in its --remote mode: one headless
# process takes the leader seat and holds the lobby, a second joins, the leader
# starts, both verify the floor and hang up. Nothing runs server-side here.
#
#   tools/validate_online_remote.sh [host:port] [solo]
#
# Pass "solo" to run just the leader. Each Godot process is capped at 2 GB via
# systemd-run so a runaway client is killed alone rather than swapping the
# machine; set NO_CAP=1 to skip that on systems without systemd.
set -u

ROOM="${1:-209-97-138-84.sslip.io:443}"
MODE="${2:-duo}"
ROOM="${ROOM#wss://}"
ROOM="${ROOM#ws://}"
AUTHORITY="${ROOM%%/*}"
PATH_PART=""
[[ "$ROOM" == */* ]] && PATH_PART="/${ROOM#*/}"
if [[ "$AUTHORITY" == *:* && "${AUTHORITY##*:}" =~ ^[0-9]+$ ]]; then
	HOST="${AUTHORITY%:*}${PATH_PART}"
	PORT="${AUTHORITY##*:}"
else
	HOST="${AUTHORITY}${PATH_PART}"
	PORT=443
fi
GODOT_BIN="${GODOT:-godot}"
PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PCK="${PCK:-}"
LOG_DIR="${LOG_DIR:-/tmp/kk_online_remote}"
TIMEOUT_SECONDS=240
LEADER_PID=""

cleanup() {
	if [[ -n "$LEADER_PID" ]] && kill -0 "$LEADER_PID" 2>/dev/null; then
		kill "$LEADER_PID" 2>/dev/null || true
		wait "$LEADER_PID" 2>/dev/null || true
	fi
}
trap cleanup EXIT

mkdir -p "$LOG_DIR"
LEADER_LOG="$LOG_DIR/leader.log"
SECOND_LOG="$LOG_DIR/client2.log"

if ! command -v "$GODOT_BIN" >/dev/null 2>&1; then
	echo "validate_online_remote: Godot executable not found: $GODOT_BIN" >&2
	exit 127
fi

cap=()
if [[ "${NO_CAP:-0}" != "1" ]] && command -v systemd-run >/dev/null 2>&1; then
	cap=(systemd-run --user --scope -q -p MemoryMax=${MEM_CAP:-3G} -p MemorySwapMax=0)
fi

cd "$PROJECT_DIR" || exit 1

if [[ -n "$PCK" ]]; then
	[[ "$PCK" = /* ]] || PCK="$PROJECT_DIR/$PCK"
	if [[ ! -f "$PCK" ]]; then
		echo "validate_online_remote: PCK not found: $PCK" >&2
		exit 2
	fi
	common=("$GODOT_BIN" --headless --main-pack "$PCK" \
		res://tools/validate_online_match.tscn --max-fps 60 --)
else
	common=("$GODOT_BIN" --headless --path . \
		res://tools/validate_online_match.tscn --max-fps 60 --)
fi
command -v stdbuf >/dev/null 2>&1 && cap=(stdbuf -o0 -e0 "${cap[@]}")

if [[ "$MODE" == "solo" ]]; then
	timeout "${TIMEOUT_SECONDS}s" "${cap[@]}" "${common[@]}" \
		--role=client --host="$HOST" --port="$PORT" --remote=1 > "$LEADER_LOG" 2>&1
	LEADER_STATUS=$?
	echo "--- leader ---"
	cat "$LEADER_LOG"
	if [[ "$LEADER_STATUS" -ne 0 ]]; then
		echo "validate_online_remote: FAILED (leader=$LEADER_STATUS)"
		exit 1
	fi
	echo "validate_online_remote: PASSED (solo)"
	exit 0
fi

timeout "${TIMEOUT_SECONDS}s" "${cap[@]}" "${common[@]}" \
	--role=client --host="$HOST" --port="$PORT" --remote=1 --wait-for=2 > "$LEADER_LOG" 2>&1 &
LEADER_PID=$!

# Let the leader take slot 0 before the second peer dials in.
sleep 6

timeout "${TIMEOUT_SECONDS}s" "${cap[@]}" "${common[@]}" \
	--role=client2 --host="$HOST" --port="$PORT" > "$SECOND_LOG" 2>&1
SECOND_STATUS=$?

wait "$LEADER_PID"
LEADER_STATUS=$?

echo "--- leader ---"
cat "$LEADER_LOG"
echo "--- client2 ---"
cat "$SECOND_LOG"

if ! diff <(grep '^SEED:' "$LEADER_LOG") <(grep '^SEED:' "$SECOND_LOG") >/dev/null; then
	echo "validate_online_remote: FAILED (the two clients built different floors)"
	exit 1
fi
echo "PASS: both clients' floors share the seed"

if [[ "$LEADER_STATUS" -ne 0 || "$SECOND_STATUS" -ne 0 ]]; then
	echo "validate_online_remote: FAILED (leader=$LEADER_STATUS client2=$SECOND_STATUS)"
	exit 1
fi
echo "validate_online_remote: PASSED"
