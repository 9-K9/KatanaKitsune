#!/usr/bin/env bash
# Exports the "Linux Server" pack and uploads it to the Droplet, then restarts
# the game server there. Run from your own computer:
#   deploy/digitalocean/upload_server.sh <droplet-ip>
# Re-run any time the game changes to push a new version live.
set -euo pipefail

DROPLET_IP="${1:?usage: upload_server.sh <droplet-ip>}"
GODOT_BIN="${GODOT:-godot}"
PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
PCK="$PROJECT_DIR/build/server/katanakitsune_server.pck"

cd "$PROJECT_DIR"
mkdir -p build/server

if [[ "${SKIP_EXPORT:-0}" != "1" ]]; then
	echo "==> Exporting server pack (takes a few minutes)"
	"$GODOT_BIN" --headless --path . --export-pack "Linux Server" "$PCK" >/dev/null 2>&1 \
		|| { echo "export failed; run the command without redirection to see why" >&2; exit 1; }
fi

echo "==> Uploading $(du -h "$PCK" | cut -f1) to root@${DROPLET_IP}"
scp "$PCK" "root@${DROPLET_IP}:/opt/katanakitsune/katanakitsune_server.pck.new"

echo "==> Swapping in the new pack and restarting the server"
ssh "root@${DROPLET_IP}" bash -s <<'EOF'
set -e
mv /opt/katanakitsune/katanakitsune_server.pck.new /opt/katanakitsune/katanakitsune_server.pck
chown katana:katana /opt/katanakitsune/katanakitsune_server.pck
systemctl restart katanakitsune-server
systemctl try-restart 'katanakitsune-room@*.service' || true
sleep 3
systemctl --no-pager --lines=5 status katanakitsune-server
EOF
