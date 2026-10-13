# tools

Dev-only scripts. Nothing here ships in the game.

## validate_ai_companions.gd

Headless-only, memory-conscious AI checks in small synthetic physics worlds.
It does not build the maze or render the game. It covers mixed/four-human
rosters, device replacement, bot upgrades and scoring, follow distance,
wall-corner pathfinding, retracted trap avoidance, bounded searches,
pause/loading/reset/death, the actual party setup and upgrade menus, and
real player-state-machine slash damage from all eight approach directions.
The combat fixture also checks safe retreat from a heavy-attack telegraph.

```bash
godot --headless --path . res://tools/validate_ai_companions.tscn --max-fps 120
```

Exits nonzero on a failed check. The combat check loads one player scene;
the movement fixtures use lightweight bodies without sprite sheets.
Pass `-- --combat-only` to skip the follow/pathfinding fixtures while working
on combat or menus.

## validate_ai_modes.gd

Headless checks for AI teammate behaviour modes: the Roster mode store, the
damage memory on players and monsters, `BotTactics` target rules for every
mode, the pause-menu switcher, and the real player scene as a bot fighting
(or declining to fight) a dummy under each mode, including Stealth's sneak
and `flair` strike.

```bash
godot --headless --path . --scene res://tools/validate_ai_modes.tscn
```

Exits nonzero on a failed check.

## validate_networking.gd

Headless check that the dedicated-server WebSocket transport and the
Roster<->peer plumbing (`NetworkManager`) work over a real loopback
connection — a server and a client can't share one process's MultiplayerAPI,
so it runs as two headless processes rather than one. See `NETWORKING.md`
for what this does and does not cover yet.

```bash
tools/validate_networking.sh
```

Exits nonzero on a failed check or a timed-out wait. Memory-heavy (two Godot
processes at once); skip it on a machine already under memory pressure.

## generate_title_power_variants.py

Rebuild the eleven alternate title covers from the original
`/mnt/K-DRIVE/Pictures/PixAI/KatanaKitsune/CoverTitle.png`, using Pillow and NumPy:

```bash
python3 tools/generate_title_power_variants.py
python3 tools/generate_title_power_variants_test.py
```

Writes the existing `titleCover_1677x938.png`, `titleCover_768x432.png`
and `_preview_titleVariants.png` assets under `assets/sprites/ui/title_power_states/`.
The mask follows garment boundaries, including the burgundy jacket tails,
but excludes the gate, stone floor and foreground wrist/hand. Pixels outside
the mask remain identical at master resolution. Smaller covers use Lanczos
downsampling, so edge pixels blend naturally.

Pass `--diagnostics-dir /absolute/scratch/directory` to save a mask overlay
outside shipping assets. These commands do not launch Godot.

## validate_day_night.gd

Run exact-factor, attack-state, scroll, sight, projectile, pause and
four-player/floor-lifecycle checks against the real maze:

```bash
godot --headless --path . res://tools/validate_day_night.tscn
```

For rendered day/night indoor/outdoor captures, use the Compatibility renderer
instead of `--headless`, and pass an existing output directory:

```bash
godot --path . --rendering-method gl_compatibility \
  res://tools/validate_day_night.tscn -- --capture-dir=/absolute/output/directory
```

Exits nonzero on a failed check. Captures are optional and not saved into the
repository automatically.

## validate_radar_hud.py

Checks the day/night orbit expression, kill-counter/reset wiring, four-player
HUD spacing and the dragon frame's transparent map opening without launching
Godot:

```bash
python3 tools/validate_radar_hud.py
```

The slim gold ouroboros frame was generated with PixelLab Pixen
(`5e27cde4-84f4-4799-960e-6a85fa3d85f1`, seed `73125`). Its ring was thinned
with nearest-neighbour radial resampling, and the inward tail curl was removed
to leave a transparent map opening. The 192x192 asset retains the existing
232-pixel frame rectangle and overall HUD footprint. The map radius is now
88 rather than 66 pixels, with a darker backing for contrast; its world range
remains 1400. Sun and crescent-moon icons are drawn by `Radar.gd`.
Transparency checks derive the map footprint from the actual texture dimensions
and radar constants, including clearance from both map pixels and orbit icons.
These are static checks, not a substitute for runtime rendering/type checks.

## validate_breakable_environment.gd

Checks every prop scene against the protected-object list, real blade/slash/
hostile-projectile/enemy-melee hits, no added scenery loot, movement collision,
light/shadow cleanup, canopy fading, trap shutdown, the three-second chair
sitting threshold, pause and floor rebuilds. Includes Sakura Gardens, Desert
Ruins and Frozen Pass generated scenery. Existing stairs scenes stay protected;
current maze floors advance by clearing their enemy wave.

```bash
godot --headless --path . --scene res://tools/validate_breakable_environment.tscn
```

For intact/broken screenshots of the three biome floors, pass an existing
output directory and use the Compatibility renderer:

```bash
godot --path . --rendering-method gl_compatibility --rendering-driver opengl3 \
  --scene res://tools/validate_breakable_environment.tscn \
  -- --capture-dir=/absolute/output/directory
```

Exits nonzero on a failed check. Does not save captures into the repository.

## validate_progression.py

Checks species experience values, rolled-tier bonuses, the level curve, stat caps,
floor-clear wiring and non-compounding upgrades without launching Godot:

```bash
python3 tools/validate_progression.py
```

## check_scene_connections.gd

Finds signal connections that have gone stale.

```bash
# every scene under scenes/
tools/check-connections.sh

# or just the ones you touched
tools/check-connections.sh scenes/title_screen.tscn
```

Exits non-zero if anything is broken, so it works as a pre-commit gate.

The wrapper locates Godot itself — `godot` is usually not on PATH, since the
engine ships as a bare versioned binary. It checks `$GODOT`, then PATH, then
searches your home directory for `Godot_v4*_linux.x86_64`. Point it somewhere
specific with:

```bash
GODOT=/path/to/godot tools/check-connections.sh
```

To invoke the engine directly instead:

```bash
~/Godot/Godot_v4.7.2-stable_linux.x86_64 --headless \
  --script res://tools/check_scene_connections.gd
```

### Why

A `.tscn` wires signals by **full node path**:

```
[connection signal="pressed" from="UI/SafeArea/VBox/ButtonBox/NewGame" to="." method="_on_new_game_pressed"]
```

Reparent, rename or re-wrap that button — add a `PanelContainer`, rename
`ButtonBox`, move it under a new `HBoxContainer` — and the path stops
resolving.

**Godot says nothing.** No error, no warning, no log line. The scene renders
perfectly, the button still highlights on hover, and clicking it does nothing.
It reads as a game-logic bug rather than a wiring one, which is what makes it
expensive.

Run this after any change to a scene's node tree.

### What it reports

- a `from=` or `to=` path that is not a node in that scene
- a `method=` the root's script does not define
- a `Button` with no live handler on `pressed`, `toggled`, `button_up` or
  `button_down` — caught by instancing the scene, so it also sees breakage
  inherited from a base scene

Toggle controls (`CheckButton`, `CheckBox`) report through `toggled` rather
than `pressed` and are not flagged for lacking a `pressed` handler.

### Known limits

- Only checks handlers on the **root's own script**. A connection whose `to=`
  is some other node is verified to exist as a node, but its method is not
  checked.
- Scenes that cannot be instantiated standalone are still text-checked; the
  button pass is skipped for them rather than reported as broken.
