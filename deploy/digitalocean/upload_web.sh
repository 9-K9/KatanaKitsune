#!/usr/bin/env bash
# Upload the existing Godot Web export to the Droplet's static web root.
set -euo pipefail

DROPLET_IP="${1:?usage: upload_web.sh <droplet-ip>}"
PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
WEB_BUILD="$PROJECT_DIR/build/web"

for required in index.html index.js index.wasm index.pck; do
	if [[ ! -f "$WEB_BUILD/$required" ]]; then
		echo "missing $WEB_BUILD/$required; export the Godot Web preset first" >&2
		exit 1
	fi
done

echo "==> Uploading the web build to root@${DROPLET_IP}"
ssh "root@${DROPLET_IP}" 'rm -rf /var/www/katanakitsune.new && mkdir -p /var/www/katanakitsune.new'
scp "$WEB_BUILD"/* "root@${DROPLET_IP}:/var/www/katanakitsune.new/"

echo "==> Publishing the uploaded build"
ssh "root@${DROPLET_IP}" bash -s <<'EOF'
set -e
chown -R caddy:caddy /var/www/katanakitsune.new
if [[ -d /var/www/katanakitsune ]]; then
	backup="/var/www/katanakitsune.previous-$(date -u +%Y%m%dT%H%M%SZ)"
	mv /var/www/katanakitsune "$backup"
fi
mv /var/www/katanakitsune.new /var/www/katanakitsune
EOF
