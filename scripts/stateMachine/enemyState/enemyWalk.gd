extends EnemyState

## Chases the player and decides when to swing.
##
## Steering is direct rather than navigated: the maps have no baked
## NavigationRegion2D, so a NavigationAgent2D would hand back the monster's own
## position and it would never move.


func on_physics_process(_delta: float) -> void:
	var distance: float = enemy.distance_to_player()
	if distance > enemy.lose_interest_range:
		change_state("idle")
		return

	var to_player: Vector2 = enemy.direction_to_player()
	enemy.face(to_player)

	if distance <= enemy.attack_range:
		if enemy.attack_off_cooldown():
			change_state("attack")
		else:
			## In range but still recovering. Hold position rather than shoving
			## the player around while the claws reset.
			enemy.stop()
			enemy.play_loop("idle")
		return

	enemy.move_towards(to_player, enemy.move_speed)
	enemy.play_loop("walk")
