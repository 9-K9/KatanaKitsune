# tools

Dev-only scripts. Nothing here ships in the game.

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
