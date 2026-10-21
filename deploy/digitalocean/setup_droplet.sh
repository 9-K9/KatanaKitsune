#!/usr/bin/env bash
# One-shot setup for a fresh Ubuntu 24.04 DigitalOcean Droplet.
# Run as root ON THE DROPLET:
#   bash setup_droplet.sh [your.domain.example]
# With no argument it uses <ip>.sslip.io, a free hostname that needs no DNS
# setup, so the web build can connect over wss:// straight away.
#
# Installs: Godot headless runtime, the game server as a systemd service,
# Caddy (automatic HTTPS + WebSocket forwarding) and a firewall.
# Afterwards upload the .pck with deploy/digitalocean/upload_server.sh.
set -euo pipefail

GODOT_VERSION="${GODOT_VERSION:-4.7.2}"
INSTALL_DIR=/opt/katanakitsune
GAME_PORT=8910

if [[ $EUID -ne 0 ]]; then
	echo "Run as root (you are logged in as root on a new Droplet by default)." >&2
	exit 1
fi

PUBLIC_IP="$(curl -fsS -4 https://api.ipify.org || hostname -I | awk '{print $1}')"
SERVER_HOST="${1:-${PUBLIC_IP//./-}.sslip.io}"

echo "==> Installing packages"
export DEBIAN_FRONTEND=noninteractive
apt-get update -q
apt-get install -y -q unzip curl ufw iproute2 python3 debian-keyring debian-archive-keyring apt-transport-https

echo "==> Installing Caddy"
if ! command -v caddy >/dev/null; then
	curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/gpg.key' \
		| gpg --dearmor -o /usr/share/keyrings/caddy-stable-archive-keyring.gpg
	curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/debian.deb.txt' \
		> /etc/apt/sources.list.d/caddy-stable.list
	apt-get update -q
	apt-get install -y -q caddy
fi

echo "==> Creating service user and install dir"
id -u katana >/dev/null 2>&1 || useradd --system --home "$INSTALL_DIR" --shell /usr/sbin/nologin katana
mkdir -p "$INSTALL_DIR/data" "$INSTALL_DIR/rooms" \
	/opt/katanakitsune-lobby /var/lib/katanakitsune-lobby \
	/var/www/katanakitsune-lobby

echo "==> Downloading Godot ${GODOT_VERSION} (headless Linux runtime)"
if [[ ! -x "$INSTALL_DIR/godot" ]]; then
	tmp="$(mktemp -d)"
	url="https://github.com/godotengine/godot/releases/download/${GODOT_VERSION}-stable/Godot_v${GODOT_VERSION}-stable_linux.x86_64.zip"
	curl -fL "$url" -o "$tmp/godot.zip"
	unzip -q "$tmp/godot.zip" -d "$tmp"
	mv "$tmp"/Godot_v*_linux.x86_64 "$INSTALL_DIR/godot"
	chmod +x "$INSTALL_DIR/godot"
	rm -rf "$tmp"
fi
chown -R katana:katana "$INSTALL_DIR"

echo "==> Installing systemd service"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cp "$SCRIPT_DIR/katanakitsune-server.service" /etc/systemd/system/
cp "$SCRIPT_DIR/katanakitsune-room@.service" /etc/systemd/system/
cp "$SCRIPT_DIR/katanakitsune-lobby.service" /etc/systemd/system/
cp "$SCRIPT_DIR/lobby_service.py" /opt/katanakitsune-lobby/
cp -a "$SCRIPT_DIR/lobby/." /var/www/katanakitsune-lobby/
chown -R caddy:caddy /var/www/katanakitsune-lobby
systemctl daemon-reload
systemctl enable katanakitsune-server
systemctl enable --now katanakitsune-lobby

echo "==> Configuring Caddy for https://${SERVER_HOST}"
cp "$SCRIPT_DIR/Caddyfile" /etc/caddy/Caddyfile
mkdir -p /etc/systemd/system/caddy.service.d
cat > /etc/systemd/system/caddy.service.d/override.conf <<EOF
[Service]
Environment=SERVER_HOST=${SERVER_HOST}
EOF
systemctl daemon-reload
systemctl enable caddy
systemctl restart caddy

echo "==> Firewall: allow SSH, HTTP/HTTPS (Caddy) and the raw game port"
ufw allow OpenSSH
ufw allow 80/tcp
ufw allow 443/tcp
ufw allow "${GAME_PORT}/tcp"
ufw --force enable

cat <<EOF

Setup done. Next, from your own computer, upload the game pack:
    deploy/digitalocean/upload_server.sh ${PUBLIC_IP}

Players then join with room code:
    ${SERVER_HOST}:443          (desktop or web build, encrypted)
    ${PUBLIC_IP}:${GAME_PORT}   (desktop build only, unencrypted)
EOF
