extends EnemyState

## Terminal state. The corpse leaves collision straight away so it neither
## blocks the player nor keeps soaking katana hits, holds its last frame for a
## beat, then fades out and frees itself.

var _finished: bool = false


func on_enter() -> void:
	_finished = false
	enemy.begin_death()
	enemy.stop()
	enemy.play_once("death")


func on_physics_process(_delta: float) -> void:
	if _finished:
		return
	if enemy.animation_finished():
		_finished = true
		enemy.finish_death()
