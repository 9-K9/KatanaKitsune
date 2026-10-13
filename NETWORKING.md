# Online Multiplayer — Status & Plan

Dedicated-server, up to 4 players, room-code join (no accounts, no lobby
website) — see the original feasibility plan for the full rationale. This
file tracks what's actually implemented versus what's still ahead, so nobody
has to re-derive it from the commit log.

## Done (this pass)

- **`scripts/system/NetworkManager.gd`** (new autoload, registered in
  `project.godot`): wraps `WebSocketMultiplayerPeer`. `host(port)` starts a
  listener; `join(address, port)` / `join_room_code("host[:port]")` connects
  as a client. A room code is literally just the host's address — there is no
  matchmaking server. `--server` / `--server=PORT` on the command line boots
  straight into a headless dedicated server (for running this as the VPS/PaaS
  process), bypassing the title screen entirely.
- **`scripts/system/PlayerInput.gd`**: added a third device sentinel,
  `NETWORK`, alongside the existing `KEYBOARD`/`BOT`, so a roster slot can be
  "filled by a remote peer" without disturbing the existing local-hardware or
  AI-teammate code paths.
- **`scripts/system/NetworkInput.gd`** (new): a `PlayerInput` for a
  network-controlled slot, shaped exactly like `BotInput` — never reads
  `Input.*` locally. The client now sends a bounded input snapshot each
  physics tick, and `NetworkManager` applies it only to the `NetworkInput`
  belonging to that peer's roster slot. Disconnect clears held input.
- **`scripts/system/Roster.gd`**: `join_network(peer_id)` seats a connecting
  peer, reusing a slot already held open for a dropped network player instead
  of always growing the roster (a `WebSocketMultiplayerPeer` hands out a new
  peer id on every connection, so "the same peer reconnecting" is matched by
  slot, not id). `drop_peer(peer_id)` marks that slot `lost`, reusing the
  exact signal (`device_lost`/`device_regained`) and pause behaviour already
  built for a yanked controller — a dropped network player already halts the
  party and waits, for free. `input_for()` now returns `NetworkInput` for a
  network slot.
- **`tools/validate_networking.gd`/`.tscn`/`.sh`**: a real two-process
  headless check (a server and a client can't share one process's
  `MultiplayerAPI`) that hosts on loopback, connects, confirms the peer gets a
  roster slot and its input reaches the server-side `NetworkInput`, then
  confirms disconnect marks the slot lost and clears held input. Run with
  `tools/validate_networking.sh` (see `tools/README.md`).

## Why this scope and not more

The full plan has many more buckets (host-authoritative floor/enemy/damage
simulation, replicated pickups/traps, client-side prediction, web export
tuning). Wiring those into the actual gameplay/combat/state-machine code is a
much larger, higher-risk change — dozens of files, and this environment
cannot interactively playtest to catch a subtle regression in single-player
or local co-op. This pass intentionally stayed inside pure-addition, zero
gameplay-code-touched territory: every file above is either brand new or an
isolated, additive change (`NETWORK` device, `is_network`/`join_network` on
Roster) that cannot change behaviour for an existing keyboard/pad/bot slot.
Both existing AI-teammate validator suites (82 + 63 checks) still pass
unchanged after these edits.

## Not done yet (next phases)

1. **Host-authoritative simulation.** Input snapshots now reach the server-side
   `NetworkInput`, but characters and enemies are not yet assigned network
   authority or replicated. The simplest correct model for a
   dedicated server (no client-side prediction yet) is: only the server ever
   runs real movement/AI/damage logic; clients only render replicated state.
   Concretely, gate the "decide and simulate" side of `AnimatedCharacterClass`
   / `EnemyStateClass` behind `is_multiplayer_authority()` (true everywhere in
   offline play by default, so this is a no-op until a multiplayer peer is
   actually active), and add a `MultiplayerSynchronizer` to the player and
   enemy scenes replicating position/velocity/animation state/health.
2. **Floor generation already has the right shape for this**: `MazeDemo.gd`
   seeds every random decision from `maze_seed` (`_rng.seed = maze_seed`), so
   the server only needs to send clients the seed, not every tile/prop/enemy
   spawn — each client can regenerate an identical floor locally. Only
   *gameplay* state (who's alive, who's where, what's been picked up) needs
   real replication.
3. **Disconnect/reconnect for the *human playing on this machine* losing the
   server** (vs. the server losing a remote peer, which is done) — i.e. what
   a client should do if `server_lost` fires mid-run.
4. **In-game host/join UI.** No title-screen button or room-code entry field
   exists yet — `NetworkManager.host()`/`join_room_code()` must be called from
   script or the CLI flags today. Deliberately deferred until replicated
   gameplay makes a network session visible, so the UI doesn't promise more
   than the game currently does.
5. **Client-side prediction/interpolation**, **web export bundle-size
   tuning**, and **NAT/firewall testing** — unchanged from the original plan,
   all still ahead.

## Running the dedicated server for real

```bash
# On the machine that will host:
godot --headless --path . --server=8910
# or, from an exported build:
./KatanaKitsune.x86_64 --server=8910
```

Friends join by typing that machine's reachable address (LAN IP, VPN IP, or a
forwarded public port) as the room code, e.g. `203.0.113.10:8910`, once an
in-game join screen exists (see item 5 above).
