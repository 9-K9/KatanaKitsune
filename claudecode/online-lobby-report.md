# KatanaKitsune Online Home + Lobby — Status Report

Date: 2026-10-13
Built with: Lovable (workspace "Emanzi's Lovable")
Project: **KatanaKitsune Hub**
- Editor: https://lovable.dev/projects/14ce2ccf-d596-46c2-8e70-a16643075a1c
- Live preview: https://id-preview--14ce2ccf-d596-46c2-8e70-a16643075a1c.lovable.app
- Not yet published to a custom/public domain — currently workspace-only preview access.

---

## 1. Why this exists / ground truth established first

Before building anything, I inspected this Godot repo directly (not assumptions) to avoid
overclaiming. Findings that shaped the whole build:

- `export_presets.cfg` has a Web preset configured but **never built** — no `.html/.wasm/.pck`
  files exist anywhere in the repo or on disk.
- `scripts/system/NetworkManager.gd` already implements a real dedicated-server networking
  foundation using Godot's `WebSocketMultiplayerPeer` (so `wss://` is the correct transport for
  browser compatibility). It handles input transport and roster/peer management, but
  **host-authoritative simulation is not wired yet** — characters still run full logic on every
  peer, so player state wouldn't actually be consistent across clients today.
- Zero Supabase/backend code existed anywhere in the game repo prior to this work.
- The 2026-10-13 handoff log (`log.txt`, commit `40451020`) explicitly records that a no-code
  tool like Lovable **cannot** export Godot to WASM, write GDScript netcode, or run the
  stateful authoritative game server — only a peripheral lobby website.

This is why the Lovable build treats the Godot game server as an **external dependency reached
through a documented contract**, not something it fakes or claims to host.

---

## 2. What is DONE and verified

### 2a. Website + lobby UI
- Responsive home page (hero, CTA into lobby, honest sub-line: *"Online play is in
  development — you can create and fill rooms today; matches start once the game server goes
  live."*).
- `/lobby` — create room / join by code.
- `/room/:code` — roster (up to 4), ready toggle, leader badge, leader-only Start button.
- `/join/:code` — shareable invite link entry point.
- `/play` — loads the Godot Web export from `public/godot-build/` once uploaded; shows an
  honest "Web export not yet uploaded" state until then (verified in code, not faked).
- Explicit UI states implemented: connecting, waiting, starting, started, disconnected
  (auto-retry with backoff + manual retry), server-unavailable (retry start), error.

### 2b. Supabase backend — verified live, not just written to files
Schema (`drizzle/migrations/0000_migration.sql`), confirmed **applied to the live database** by
querying it directly:
- Tables: `rooms`, `room_members`, `join_tokens`, `rate_limits`.
- Indexes on invite-code lookup and room-id foreign keys.
- `CHECK` constraint on invite-code format, unique-leader-per-room index, `max_players = 4`
  check.
- **Row Level Security is ON for all four tables** (`relrowsecurity = true`, confirmed live via
  `pg_class` query) with **zero policies granted to `anon`/`authenticated`** — i.e. default-deny.
  The browser can never read or write these tables directly, even with the publishable key.
- All real access goes through TanStack server functions
  (`src/lib/lobby.functions.ts`) using a service-role client that only exists server-side.
- Capacity (4 players) is enforced by a Postgres trigger (`kk_enforce_capacity`) AND a
  row-locked `kk_join_room` function — a backstop even if application code is bypassed.
- Leader-only start is enforced server-side in `startGame()` (`evaluateStart` in
  `src/lib/lobby-rules.ts`), not just hidden in the UI.
- Rate limiting: 5 room creations / 20 join attempts per IP per 10 minutes, via a Postgres
  fixed-window function (`kk_rate_limit`).
- Invite codes: 8 characters, unambiguous alphabet (no `0/O/1/I`), ~40 bits of entropy.
- Room expiry: 2 hours, checked at read time plus opportunistic cleanup
  (`kk_cleanup`) of expired rooms/tokens/rate-limit windows.
- Guests never hold DB credentials — membership is proven with a per-room random secret, only
  its SHA-256 hash is stored.

### 2c. Game-server handoff — documented and implemented up to the boundary
- `src/lib/join-token.server.ts` — issues short-lived (60s), single-use, HMAC-SHA256-signed
  join tokens.
- `src/lib/handoff.ts` — client-side shape/expiry check before handing the token to Godot
  (real signature verification is the external game server's job, as documented).
- `src/routes/play.tsx` — passes the token via query string (`/play?t=...`), then **immediately
  rewrites the URL to drop it** (`window.history.replaceState`) so it isn't preserved in
  history/bookmarks.
- `docs/GAME_SERVER_CONTRACT.md` — the full contract an external Godot server operator must
  implement: room provisioning API, join-token verification rules, `wss://` URL format, capacity
  enforcement, heartbeat/cleanup timings, WebSocket close codes (4001–4008).

### 2d. Secrets / security hygiene
- `.env` in the Lovable project contains **only** the Supabase publishable key — verified by
  reading the file directly.
- Service-role key is only ever used in `client.server.ts`, sourced from `process.env`, never
  bundled to the browser.
- `docs/DEPLOYMENT.md` documents the three required server-side secrets with placeholder names
  (`GAME_SERVER_API_URL`, `GAME_SERVER_API_KEY`, `GAME_SERVER_TOKEN_SECRET`) — no real values
  committed anywhere.

### 2e. Documentation deliverables — all present
- `docs/GAME_SERVER_CONTRACT.md`
- `docs/DEPLOYMENT.md` (Godot export steps + MIME types + secret config)
- `docs/TEST_CHECKLIST.md`
- `docs/STATUS.md` (implemented / placeholder / external — see below)

### 2f. Automated tests — passing
Had the Lovable agent run the suite as an independent check (not just trust its own claim):
`bunx vitest run src/lib/lobby-rules.test.ts src/test/app-routing.test.tsx`
→ **11 passed / 0 failed.**

---

## 3. What is PLACEHOLDER — intentional, not a bug
- `/play` shows "Web export not yet uploaded" because `public/godot-build/` is empty
  (`.gitkeep` only). This is correct until a real export is uploaded.
- Home page screenshots are placeholder imagery.

## 4. What is NOT finished / must happen outside Lovable
1. **Export the actual Godot Web build** (Project → Export → Web, threading OFF) and upload the
   output files to `public/godot-build/` in the Lovable project. I did **not** do this — the task
   explicitly said not to launch the Godot game during this work, and an export needs the Godot
   editor.
2. **Stand up the headless Godot game server** that implements `docs/GAME_SERVER_CONTRACT.md`,
   reachable over `wss://`. Nothing like this is hosted today. This requires:
   - Finishing host-authoritative simulation in `NetworkManager.gd` (characters currently run
     full logic on every peer — not deterministic/authoritative yet, per the 2026-10-13 handoff
     log).
   - A VPS or equivalent host, outside Lovable, that you provision and pay for yourself.
3. **Configure the three server secrets** (`GAME_SERVER_API_URL`, `GAME_SERVER_API_KEY`,
   `GAME_SERVER_TOKEN_SECRET`) once the server above exists. Until then, pressing "Start game"
   correctly shows "Game server isn't configured" and the room stays open — this was verified
   in the `startGame()` code path.
4. **Publish the Lovable site** to a public/custom domain if you want it reachable outside the
   workspace preview URL (currently workspace-only).
5. **Manually run `docs/TEST_CHECKLIST.md`** end-to-end in real separate browser
   contexts — you're doing this tomorrow. I was unable to do it myself in this session because
   the Claude-in-Chrome browser extension wasn't connecting (tried twice, not a one-off blip).
   What I verified instead: live DB schema/RLS inspection, full source-code read-through of every
   server function and the token/handoff code, and the automated test run above. That's strong
   evidence the logic is correct, but it isn't the same as watching two real browser sessions
   race for the last seat in a room — hence the manual pass.

## 5. Honesty check against the original brief
No claim is made anywhere in the build (home page, docs, or code) that the game is currently
online-playable, or that Lovable is hosting the game server. `docs/STATUS.md` says so in plain
language: *"The game is not online-playable today."* This matches the constraint in the original
task not to invent a working multiplayer backend.

## 6. Suggested next steps, in order
1. Run `docs/TEST_CHECKLIST.md` manually (tomorrow) using separate incognito windows per the
   walkthrough already given in chat. Report back anything that fails.
2. Decide on and provision a VPS (or similar) for the game server.
3. Finish host-authoritative simulation in `NetworkManager.gd` / related state-machine scripts
   (highest-risk remaining game-code work, per the handoff log — touches combat/movement logic).
4. Implement the server side of `docs/GAME_SERVER_CONTRACT.md` on that VPS.
5. Export the Godot Web build and upload it to `public/godot-build/`.
6. Set the three `GAME_SERVER_*` secrets in the Lovable project.
7. Re-run the test checklist's "game server unavailable" section in reverse — confirm a
   configured, reachable server now lets a room actually start and hand off to `/play`.
8. Publish the site to a real domain when ready.
