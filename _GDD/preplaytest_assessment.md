# KatanaKitsune: pre-playtest dry-run assessment

- **Snapshot:** `2b996a94` ("Slim dragon radar frame and enlarge map"). The tree is clean apart from an untracked `AGENTS.md`.
- **Engine:** Godot 4.7.stable.official.5b4e0cb0f, GL Compatibility renderer.
- **Rules followed:** this was a report-only pass. No code, asset or git state was changed. Every headless run used a disposable copy of the project.

## 1. What was run

| Check | Result |
|---|---|
| Headless `--import` of the whole project | Exit 0. Only warning: 2 ObjectDB instances leaked at exit. |
| Load every `.tscn`, `.gd` and `.tres` file (649 files) | 0 load failures. Two expected editor-only errors (see L4 and L5). |
| `validate_day_night.tscn` | 306 checks, 0 failures |
| `validate_breakable_environment.tscn` | 1367 checks, 0 failures |
| `validate_japanese_environment.gd` / `validate_japanese_props.gd` | All OK |
| `check-connections.sh` (142 scenes, 18 signal connections) | 0 problems |
| `validate_progression.py`, `validate_radar_hud.py`, `generate_title_power_variants_test.py` | All pass (6 + 5 + 4 tests) |
| Missing `res://` references, enemy clip coverage for the 9 roster monsters | None missing; every requested directional clip exists |

The engine-level health is good. Nothing is broken at load time. The remaining risks are about shipping and runtime edge cases.

---

## 2. Blockers (fix before export)

### B1. Export templates are not installed
`~/.local/share/godot/export_templates/` is empty, and there is no `4.7.stable` folder. Exporting will fail until you install them (Editor → Manage Export Templates → Download).

### B2. The cheat menu ships in release builds
- **Where:** `scripts/system/PauseMenu.gd:98-128` (`_on_cheats_pressed`, `_on_immortality_toggled`) and `CheatManager.set_immortality`.
- **Problem:** the CHEATS → IMMORTALITY toggle is always visible. There is no `OS.is_debug_build()` or feature-tag guard.
- **Fix:** hide the Cheats button unless `OS.is_debug_build()` is true, or unless a custom feature such as `cheats` is set.
- **Repro:** start a run → pause → CHEATS → IMMORTALITY ON.

### B3. The export preset would ship the whole project
- **Where:** `export_presets.cfg`, which sets `export_filter="all_resources"` with empty include and exclude filters.
- **Problem:** this ships `tools/` (validator scenes and scripts), `archive/`, `art/`, `_GDD/`, `pictures/`, `script_templates/` and the `.md` and `.txt` notes (`log.txt`, `handover-duellists.txt`). It also ships Dialogic's `_test/timeline.dtl`.
- **Fix:** add an exclude filter such as `tools/*, archive/*, art/*, _GDD/*, pictures/*, script_templates/*, *.md, *.txt, *.py`. Alternatively, switch to "Export selected scenes" with the main scene plus the scenes it loads dynamically.

---

## 3. High

### H1. The Web build is very large
- **Size:** `assets/` is about 340 MB, made up of 3,686 PNGs. The imported cache is about 218 MB.
- **Impact:** that is a long first load and can hit browser memory limits, especially in Safari and on lower-RAM machines.
- **Compression setting:** `vram_texture_compression/for_desktop=true`. Pixel art usually looks better with lossless import. Check that the sprites don't pick up compression artefacts.
- **Other Web caveats:**
  - Gamepad support depends on the browser. Pads only appear after a button press, and mappings vary.
  - Four-player local co-op on the web is fragile.
  - `user://` maps to IndexedDB, so data clears with the browser storage.
  - If you turn on thread support, the host must send COOP/COEP headers.
- **Suggestion:** if a desktop release (Linux/Windows) is an option, add that preset as well. Desktop is the more natural target for local co-op with pads.

### H2. Level-up screen can block the game
- **Where:** `MazeDemo.gd:1801-1817` (`_offer_upgrades`) and `LevelUpScreen.gd` (`_all_ready`, `_build_column`).
- **Columns:** every `Roster.count()` slot gets a column. A player who has points must confirm READY, even if they are downed. Only players with 0 points start ready.
- **Disconnects:** if a pad disconnects while the screen is open, nobody else can finish it for that slot. The game waits until the pad returns.
- **Fix:** let player 1 (or any connected pad) confirm on behalf of a disconnected slot, or auto-ready slots with no device.
- **Repro:** 2P → finish a floor where P2 levelled up → unplug P2's pad on the upgrade screen.

### H3. Reconnecting a controller can unpause the game under the pause menu or game-over screen
- **Where:** `MazeDemo.gd:1824-1829`.
- **Problem:** `_on_device_regained` sets `get_tree().paused = _upgrading`. If the pause menu or the game-over overlay was open, reconnecting the pad unpauses the world behind it.
- **Fix:** only clear the pause if this script set it. One approach is to track a `_paused_for_reconnect` flag. Another is to check `PauseMenu.visible` or game-over state first.
- **Repro:** pause → unplug a pad → plug it back in → the enemies start moving behind the menu.

### H4. `play_once` doesn't check that the animation exists
- **Where:** `EnemyStateClass.gd:666-670`.
- **Problem:** unlike `play_chase`, it calls `animated_sprite.play(clip)` without `sprite_frames.has_animation(clip)`. A missing one-shot clip leaves the state waiting on `animation_finished`, which never fires, so the enemy freezes.
- **Current risk:** none, because all 9 roster monsters have every clip. Note that adding any 5-clip or 8-clip monster later will trigger this, which matches the roster warning in AGENTS.md.
- **Fix:** guard the call and fall back to an idle or attack clip, or emit finished immediately.

---

## 4. Medium

### M1. Coroutines resume on freed nodes
These are `await`s that resume without checking `is_instance_valid(self)` or `is_inside_tree()`:
- `AnimatedCharacterClass._start_invincibility` (`~562-570`). It awaits a scene-tree timer, then writes `is_invincible`. If the body is freed between floors or on quit-to-title, Godot logs errors.
- The fade tween in `EnemyStateClass.finish_death` (`~1080-1085`).
- The break-animation coroutine in `Breakable.gd` (`~144-162`).
- `SceneLoader._release_unless_held` (`~238-244`). This is a race if a hold arrives during the await.

**Impact:** usually just error spam in the log. In the worst case, a crash when you quit to the title mid-effect.

### M2. Downed players carry into the next floor
- **Where:** `descend()` (`MazeDemo.gd:358+`).
- **What happens:** it keeps every valid body, so a downed but un-freed co-op player arrives on the next floor still downed. The only revive path is a partner (`player_main._try_revive`).
- **To check:** whether this is intended, and whether the level-up screen or `apply_progression` touches a downed player's health. Verify during the playtest.

### M3. ObjectDB leak at exit
Headless runs report 1–2 leaked instances at exit. This is harmless, but it is worth finding with `--verbose` before shipping.

### M4. `project.godot` metadata
- No `application/config/version`.
- `config/tags` still contains "template".
- Boot splash is the default, and fullscreen or window mode is not set for release.
- Two editor plugins are enabled (Dialogic, finite_state_machine). This is fine, but Dialogic's timeline list also references `_test/timeline.dtl` and timelines for mummyKitsune and undeadRonin, which are not in the roster.

---

## 5. Low

- **L1.** `MazeDemo.gd:1673` has a leftover `print("MazeDemo: removed %d chair(s)…")`. It is the only stray `print` in `scripts/`.
- **L2.** `.gitattributes` lines 14–16 still have `filter=lfs` rules for `*.wav`, `*.ogg` and `*.mp3`. Your project notes say this is a leftover that should be removed.
- **L3.** Orphan assets ship with the build: `mummyKitsune` sprites with no scene, and three stray `abomination` PNGs. Exclude them or delete them later.
- **L4.** `script_templates/StateMachineState/state_machine_state.gd` fails to parse because of its `_BASE_` placeholder. It is an editor template, so exclude it from export (see B3).
- **L5.** Dialogic's `syntax_highlighter.gd:35` calls the editor-only `EditorInterface` API. That is harmless at runtime but adds a log error when every file is loaded. It won't appear in normal play.
- **L6.** The `recolor_kitsune*_test.py` scripts produce no unittest output. They look like ad-hoc scripts rather than real tests, so they were not verified.

## 6. Dismissed (false positives from the automated scan)

- **"571 unmatched UIDs":** dismissed. The full load-all run raised no UID or missing-dependency warnings. The scan was most likely counting scene self-UIDs and `.import` UIDs.
- **"Lowercase clip names":** dismissed. This is the established naming scheme, not a bug.
- **No audio:** intentional and deferred by design.
- **Only 3 of 17 enemies wired into `enemy_scenes`:** a deliberate narrowing of the roster.

## 7. Performance notes

- `Radar.gd` calls `queue_redraw()` every frame. `HUD._process` redraws the rings every frame. That is cheap at this scale, but don't stack more of these.
- The weather particles (`outdoor_particles.tscn`, `OutdoorWeather.gd`) are the most likely GPU hotspot on Web and integrated graphics. Watch the frame rate during snow or desert storms.
- With 4 players on deep floors, the number of enemies scales up. Watch the frame time and draw calls with the Godot monitor in a debug export.

---

## 8. Manual playtest checklist

**Core loop**
- [ ] Title → character select (1–4 players) → floor 1 → clear → descend, through to the boss wave or yokai lord.
- [ ] Game over appears only when every player is down. Retry and quit to title both reset Score, Progression and Roster.

**Level-up system** (never played in-game)
- [ ] The screen appears only when someone levelled up. Players with 0 points start READY.
- [ ] Each stat applies:
  - **HP:** max and current health.
  - **Stamina.**
  - **Speed.**
  - **Stealth:** sneak meter capacity, drain and regen.
- [ ] Ranks cap at 5.
- [ ] Stats don't compound across floors.
- [ ] XP is right per species. Kasha should be worth about 4× kappa.
- [ ] 2–4 players spending at the same time, each pad driving only its own column.
- [ ] A downed player with points on the upgrade screen (M2).
- [ ] Unplug a pad during the upgrade screen (H2).

**Pause and input**
- [ ] Unplug or replug a pad mid-floor, in the pause menu and on game over (H3).
- [ ] The pause menu can't open over the upgrade screen.
- [ ] Keyboard-only play works.

**World**
- [ ] Every biome: weather starts and stops between floors, and indoor roofs hide.
- [ ] The day/night orbit icon swaps sun and moon at the horizon.
- [ ] The radar tracks every player.
- [ ] Per-player kill counts, plus the total "x/y" and remaining count, stay correct across floors.
- [ ] Breakables, chairs and props block or break correctly.

**Export**
- [ ] Install templates (B1), filter the export (B3), and remove the cheats (B2).
- [ ] Test the built web page in Chrome and Firefox, at least: load time, memory, gamepad detection, and fullscreen.
- [ ] If possible, also test a desktop export.

---

## 9. Fix status (follow-up pass)

**Fixed (uncommitted):**
- **B2:** the Cheats button is removed and immortality forced off when `OS.is_debug_build()` is false.
- **B3:** the Web preset's `exclude_filter` now covers `tools/`, `archive/`, `art/`, `_GDD/`, `pictures/`, `script_templates/`, `_tests` sprites, `*.md`, `*.txt`, `*.py`, `*.zip` and `*.pdf`.
- **H2:** the level-up screen treats disconnected slots as ready. Their unspent points stay banked.
- **H3:** `MazeDemo` tracks `_paused_for_reconnect` and only lifts its own pause.
- **H4:** `play_once` stops (reads as finished) and warns when a clip is missing.
- **M1:** the invincibility end and the Breakable break frames now use node-bound tweens instead of tree-timer awaits.
  - `finish_death` was already safe (a node-bound tween).
  - `SceneLoader` is an autoload, so it can't be freed; no change needed.
- **M4:** added `config/version="1.0"` and removed the "template" tag.
- **L1:** the chair log is now `print_verbose`.
- **L2:** deleted `.gitattributes` (LFS leftovers only).

**Verified:** headless load-all (652 files, 0 failures), all validators, and `check-connections` pass.

**Still yours:** B1 (install the export templates), H1 (choose platform and size), the real playtest, and testing in a browser.
