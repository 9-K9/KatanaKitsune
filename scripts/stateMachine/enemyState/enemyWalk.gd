extends EnemyState

## Chases the player and decides when to swing.


func on_physics_process(_delta: float) -> void:
	var distance: float = enemy.distance_to_player()
	if distance > enemy.lose_interest_range:
		change_state("idle")
		return

	## Face where the player actually is, but walk where the path says: looking
	## at a corridor corner while chasing reads as the monster losing interest.
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

	var step: Vector2 = enemy.chase_direction()
	enemy.move_towards(step if step != Vector2.ZERO else to_player, enemy.move_speed)
	enemy.play_loop("walk")
