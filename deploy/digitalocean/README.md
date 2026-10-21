# Hosting the game server on DigitalOcean

Plain-English version: online co-op needs one computer that is always on
("the server"). Everyone's game connects to it, and it keeps the players in
sync. The live deployment uses the 4 vCPU / 8 GB Basic Droplet.

## One-time setup (about 10 minutes)

1. Create a Droplet at <https://cloud.digitalocean.com/droplets/new>:
   Ubuntu 24.04, Basic. The game runtime is small, but use at least 4 GB if
   the Droplet will also build exports; the live machine has 8 GB.
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
| `upload_web.sh` | Atomically publishes an existing Web export. |
| `katanakitsune-server.service` | systemd unit: runs `godot --headless --main-pack ... --server=8910`, restarts on crash. |
| `Caddyfile` | HTTPS/WebSocket front door on :443 → game server on :8910. |

## Live addresses and limits

- Browser game: <https://play.9-k9.io>
- Room address: `209-97-138-84.sslip.io:443`
- One service currently runs one room of up to four players. Multiple rooms
  need more service instances or a lobby service; see `NETWORKING.md`.
