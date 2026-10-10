extends EnemyState

## Stagger after taking a hit. Brief enough that the monster cannot be pinned
## in place forever, long enough to read as a reaction.


## Hard ceiling on the stagger, so a clip that never reports finished cannot
## leave the monster stuck here.
const MAX_STAGGER: float = 1.5

var _elapsed: float = 0.0


func on_enter() -> void:
	_elapsed = 0.0
	enemy.stop()
	enemy.face(enemy.direction_to_player())
	enemy.play_once("hurt")


func on_physics_process(delta: float) -> void:
	## Rides out the real knockback from the hit instead of standing still, so
	## the stagger is an actual position change that sticks once it ends.
	enemy.consume_knockback(delta)
	_elapsed += delta
	if _elapsed < enemy.hurt_lock:
		return
	if enemy.animation_finished() or _elapsed >= MAX_STAGGER:
		change_state("walk")
