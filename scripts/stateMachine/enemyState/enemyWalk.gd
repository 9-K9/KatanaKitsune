extends EnemyState

## Hunting her. Holds this state only while she is actually in sight; the moment
## she is not, it hands over to `alert`, which keeps looking for a few seconds
## before giving up.


func on_physics_process(_delta: float) -> void:
	if not enemy.sees_player():
		change_state("alert")
		return

	var distance: float = enemy.distance_to_player()
	## Face where she actually is, but walk where the path says: staring at a
	## corner while rounding it reads as the monster losing interest.
	var to_player: Vector2 = enemy.direction_to_player()
	enemy.face(to_player)

	if distance <= enemy.attack_range:
		if enemy.attack_off_cooldown():
			change_state("attack")
		else:
			## In range but still recovering. Holds position rather than shoving
			## her around while the claws reset.
			enemy.stop()
			enemy.play_loop("idle")
		return

	var step: Vector2 = enemy.chase_direction()
	enemy.move_towards(step if step != Vector2.ZERO else to_player, enemy.move_speed)
	enemy.play_loop("walk")
