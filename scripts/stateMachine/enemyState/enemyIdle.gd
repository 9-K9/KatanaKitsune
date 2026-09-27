extends EnemyState

## Standing still, waiting for something to walk past.


func on_enter() -> void:
	enemy.stop()


func on_physics_process(_delta: float) -> void:
	enemy.stop()
	enemy.play_loop("idle")
	if enemy.distance_to_player() <= enemy.effective_detection():
		change_state("walk")
