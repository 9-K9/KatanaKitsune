# Online multiplayer

KatanaKitsune supports one dedicated-server room with up to four players.
The public WebSocket room is `209-97-138-84.sslip.io:443`; the browser build
is at <https://play.9-k9.io>.

## Implemented

- The title screen's **ONLINE CO-OP** flow joins the room, assigns seats,
  chooses distinct aspects, lets the room leader choose an area, and starts.
- The server owns player movement, enemies, damage, world-object state, floor
  changes, and session reset. Clients send bounded input and render snapshots.
- Every peer regenerates the same procedural floor from the server's seed.
- Browser and desktop clients use secure WebSockets through Caddy.
- Disconnects clear held input. When the room empties, the server cancels any
  in-progress floor build and returns to its small idle scene.
- The Linux server export strips visual resources. A live idle server uses
  roughly 80 MB; a tested two-player floor peaked around 160 MB.

This is currently one room, not matchmaking. Multiple simultaneous rooms
would require a room directory and multiple server instances/ports.

## Live validation

`tools/validate_online_remote.sh` runs two stripped, headless clients against
the public server. It proves seat/aspect synchronization, a shared seed and
area, two bodies, enemy snapshots, server-authoritative player movement, and
clean hang-up. Each client is memory-capped; override paths/caps with `GODOT`,
`PCK`, and `MEM_CAP`.

```bash
godot --headless --path . --export-release "Test Client (stripped)" \
  build/test/katanakitsune_testclient.pck
PCK=build/test/katanakitsune_testclient.pck MEM_CAP=1G \
  tools/validate_online_remote.sh 209-97-138-84.sslip.io:443 duo
```

The validator also has a disconnect-during-build mode used to guard the
server's cancellation path. See `tools/validate_online_match.gd`.

## Operations

The DigitalOcean service is `katanakitsune-server` on `209.97.138.84`.

```bash
ssh root@209.97.138.84 systemctl status katanakitsune-server
ssh root@209.97.138.84 journalctl -u katanakitsune-server -f
deploy/digitalocean/upload_server.sh 209.97.138.84
deploy/digitalocean/upload_web.sh 209.97.138.84
```

The server listens on `127.0.0.1:8910`; Caddy terminates TLS on port 443.
Direct port 8910 is not the browser room address.
