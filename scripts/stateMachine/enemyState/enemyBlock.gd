extends EnemyState

## A duellist's guard. Raised when the player is close and swinging, dropped to
## answer with a strike of its own.
##
## Only tiers that guard ever enter this — see EnemyTier. A shambler has no
## business parrying, and the state is simply never reached for it.
##
## The clip holds on its last frame rather than looping, the same way her own
## block does, so a raised guard reads as held rather than as a twitch.

## How long it will stand behind the guard before answering. A monster that
## blocked indefinitely would be a wall rather than an opponent.
@export var hold_seconds: float = 1.1
## While guarding it gives ground rather than standing rooted, which keeps a
## duel moving instead of becoming a shoving match.
@export var give_ground: float = 0.35

var _held: float = 0.0


func on_enter() -> void:
	_held = 0.0
	enemy.guarding = true
	enemy.face(enemy.direction_to_player())
	enemy.play_once("block")


func on_physics_process(delta: float) -> void:
	_held += delta
	## Keeps facing the threat: what a guard is worth depends on which way it
	## faces, so letting the player walk around it would make the block
	## meaningless rather than merely weak.
	var toward: Vector2 = enemy.direction_to_player()
	enemy.face(toward)
	## Backs away slowly while the guard is up.
	enemy.move_towards(-toward, enemy.move_speed * give_ground)
	## Held on the final frame — play_once leaves it there — so the pose stays
	## up for as long as the guard does.
	if _held >= hold_seconds:
		change_state("attack" if enemy.in_attack_range() else "walk")


func on_exit() -> void:
	enemy.guarding = false
