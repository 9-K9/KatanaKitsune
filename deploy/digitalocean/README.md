# Hosting the game server on DigitalOcean

Plain-English version: online co-op needs one computer that is always on
("the server"). Everyone's game connects to it, and it keeps the players in
sync. These files turn a $6/month DigitalOcean Droplet into that computer.

## One-time setup (about 10 minutes)

1. Create a Droplet at <https://cloud.digitalocean.com/droplets/new>:
   Ubuntu 24.04, Basic / Regular / **$6 (1 GB RAM)**, Password login.
   Note the IP address it gives you (e.g. `164.92.10.20`).
2. Copy this folder to the Droplet and run the setup script. From a terminal
   on your own computer (replace the IP):

   ```bash
   scp -r deploy/digitalocean root@164.92.10.20:/root/
   ssh root@164.92.10.20 bash /root/digitalocean/setup_droplet.sh
   ```

   Type the Droplet password when asked. The script installs Godot, the game
   service, a firewall and Caddy (which gives players an encrypted
   `wss://` connection with a free certificate — required by the web build).
3. Upload the game itself:

   ```bash
   deploy/digitalocean/upload_server.sh 164.92.10.20
   ```

4. Upload the browser build:

   ```bash
   deploy/digitalocean/upload_web.sh 164.92.10.20
   ```

   The default browser URL is `https://play.<ip-with-dashes>.sslip.io/`. For
   the official URL, add an A record for `play.9-k9.io` pointing at the
   Droplet, set `WEB_HOST=play.9-k9.io` in Caddy's systemd override, and reload
   Caddy.

   This exports the "Linux Server" preset from `export_presets.cfg` (a
   `.pck` with no graphics window — the server never draws anything) and
   restarts the server with it. Run it again whenever the game changes.

The setup script prints the **room code** players type in at the end:
`<ip-with-dashes>.sslip.io:443` (encrypted, works for web and desktop) or
`<ip>:8910` (desktop only). If you own a domain, pass it as an argument to
`setup_droplet.sh` and the room code becomes `yourdomain:443`.

## Checking on it

```bash
ssh root@<ip> systemctl status katanakitsune-server   # is it running?
ssh root@<ip> journalctl -u katanakitsune-server -f    # live log
ssh root@<ip> systemctl restart katanakitsune-server   # restart
```

## Files

| File | Purpose |
|------|---------|
| `setup_droplet.sh` | Installs everything on a fresh Droplet. |
| `upload_server.sh` | Exports the pack, uploads it, restarts the service. |
| `upload_web.sh` | Uploads `build/web/*` and atomically publishes the browser build. |
| `katanakitsune-server.service` | systemd unit: runs `godot --headless --main-pack ... --server=8910`, restarts on crash. |
| `Caddyfile` | HTTPS/WebSocket front door on :443 → game server on :8910. |

## Cost / limits

$6/month flat. One Droplet runs one room of up to 4 players (one
`NetworkManager` session). Multiple simultaneous rooms would need either more
service instances on different ports or a lobby server — see `NETWORKING.md`.
