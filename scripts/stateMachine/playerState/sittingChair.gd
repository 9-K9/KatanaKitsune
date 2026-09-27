extends PlayerClass

## Idle flourish. Plays out and returns to idle; any input cuts it short.

func on_enter():
	pc.speed = 0.0
	action_timer.wait_time = 3.0
	action_timer.start()

func on_process(_delta):
	stateAnimation("sittingChair", 2)
	if pc.InputHandler() != Vector2.ZERO or Input.is_action_just_pressed("Attack"):
		change_state("idle")

func on_physics_process(_delta):
	if action_timer.is_stopped():
		change_state("idle")

func on_exit():
	action_timer.stop()
