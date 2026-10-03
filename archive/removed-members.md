# removed members

Functions and fields deleted out of files that are still live, so there is no
file to move into `archive/`. Each is reproduced here verbatim with where it
came from, so putting one back is copy-and-paste rather than archaeology.

---

## scripts/stateMachine/class/NavAIClass.gd  (`AI_Class`)

Removed 2026-10-03. `AI_Class` is extended only by `EnemyStateClass`
(`EnemyBase`), and none of the following had a single use anywhere in the enemy
tree — not in `EnemyStateClass.gd`, not in any state under
`scripts/stateMachine/enemyState/`, and not through `enemy.<member>` from
outside.

They are the remains of the pre-FSM monster, which drove its own animation from
a `self_state` string. The states under `enemyState/` took that over: facing is
now `facing_dir` plus `play_loop()`/`play_once()` on `EnemyBase`.

```gdscript
@onready var gameManager = get_node_or_null("/root/Main")
@onready var direction : Vector2 = Vector2.ZERO
@onready var self_state: String = "idle"
@onready var animation_state = "%s_%s"%[self_state,facing_dir]


func animationState(fps):
	animation_state = "%s_%s"%[self_state,facing_dir]
	animated_sprite.play(animation_state,fps)
```

Notes if restoring:

- `gameManager` resolved `/root/Main`, which no longer exists — the scene tree
  root is the maze now, and `GameManager.gd` itself was deleted in `c88eb7c0`.
  It would resolve to `null` today.
- `animationState(fps)` passes `fps` to `AnimatedSprite2D.play()`, whose second
  parameter is `custom_scale`, not a frame rate. Calling it with 8 or 12 would
  have played the clip eight or twelve times too fast. It was almost certainly
  never working as its name suggests.
- `direction` was never read; `EnemyBase` computes movement through
  `chase_direction()` and `direction_to_player()` instead.

---

## Already removed by the Desktop

Recorded for completeness — these were on the dead list in `log.txt` and were
removed in the Desktop's own sweep, not here. They are recoverable from git
history at `c88eb7c0^` and the commits around it.

`navigationControler()`, `taunt_done()`, `current_target()`, `spend_stamina()`,
`round_to_dec()`, `any_pressed()`, `_focus_icons()`, `_player_body()`,
`closed_sides()`, `getPlayerPosition()`, `get_box_inertia()`, and the fields
`lose_interest_range`, `floors_per_theme`, `HIT_FLASH`, `FIRST_MAP`,
`contact_damage`, `FACING_NAMES`, `FEET_BELOW_ORIGIN`.

---

## Checked and kept

**`_every_action()`** (`scripts/system/PlayerInput.gd:143`) was on the dead
list because its only documented caller, `any_pressed()`, was removed. It is
live: `PlayerInput.gd:90` calls it. Left alone.
