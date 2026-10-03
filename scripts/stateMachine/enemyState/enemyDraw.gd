extends EnemyState

## A duellist unsheathes once, on first engagement, before joining the chase.

@export var maximum_seconds: float = 2.5
var _elapsed: float = 0.0


func on_enter() -> void:
	_elapsed = 0.0
	enemy.stop()
	enemy.face(enemy.direction_to_player())
	enemy.play_once("draw")


func on_physics_process(delta: float) -> void:
	_elapsed += delta
	enemy.stop()
	enemy.face(enemy.direction_to_player())
	if enemy.animation_finished() or _elapsed >= maximum_seconds:
		enemy.blade_drawn = true
		change_state("walk")


func on_exit() -> void:
	_elapsed = 0.0
