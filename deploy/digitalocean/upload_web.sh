#!/usr/bin/env bash
# Upload an existing Godot Web export and switch it live atomically.
set -euo pipefail

DROPLET_IP="${1:?usage: upload_web.sh <droplet-ip>}"
PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
WEB_BUILD="$PROJECT_DIR/build/web"
STAMP="$(date -u +%Y%m%dT%H%M%SZ)"
REMOTE_NEW="/var/www/katanakitsune.new-$STAMP"
REMOTE_BACKUP="/var/www/katanakitsune.previous-$STAMP"

for required in index.html index.js index.wasm index.pck; do
	if [[ ! -f "$WEB_BUILD/$required" ]]; then
		echo "missing $WEB_BUILD/$required; export the Web preset first" >&2
		exit 1
	fi
done

ssh "root@${DROPLET_IP}" "mkdir '$REMOTE_NEW'"
scp "$WEB_BUILD"/* "root@${DROPLET_IP}:${REMOTE_NEW}/"
ssh "root@${DROPLET_IP}" bash -s -- "$REMOTE_NEW" "$REMOTE_BACKUP" <<'EOF'
set -euo pipefail
incoming="$1"
backup="$2"
chown -R caddy:caddy "$incoming"
if [[ -d /var/www/katanakitsune ]]; then
	mv /var/www/katanakitsune "$backup"
fi
mv "$incoming" /var/www/katanakitsune
EOF

echo "Published https://play.9-k9.io (previous build: $REMOTE_BACKUP)"
