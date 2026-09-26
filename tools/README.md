# tools

Dev-only scripts. Nothing here ships in the game.

## check_scene_connections.gd

Finds signal connections that have gone stale.

```bash
# every scene under scenes/
godot --headless --script res://tools/check_scene_connections.gd

# or just the ones you touched
godot --headless --script res://tools/check_scene_connections.gd -- scenes/title_screen.tscn
```

Exits non-zero if anything is broken, so it works as a pre-commit gate.

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
