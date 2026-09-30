extends PlayerClass

## Taunt. Draws anything that can see her — she is deliberately loud, which is
## the point: it pulls a patrol off a route she would rather not fight through.
const TAUNT_RANGE: float = 340.0

func on_enter():
	pc.speed = 0.0
	action_timer.wait_time = play_oneshot("seductiveDance")
	action_timer.start()
	_provoke()

func on_process(_delta):
	if pc.InputHandler() != Vector2.ZERO or pc.input.just_pressed("Attack"):
		change_state("idle")

func on_physics_process(_delta):
	if action_timer.is_stopped():
		change_state("idle")

## Anything in earshot comes looking.
func _provoke() -> void:
	for enemy in pc.get_tree().get_nodes_in_group("enemies"):
		if enemy is Node2D and pc.global_position.distance_to(enemy.global_position) <= TAUNT_RANGE:
			if enemy.has_method("provoke"):
				enemy.provoke()

func on_exit():
	animated_sprite.speed_scale = 1.0
	action_timer.stop()
