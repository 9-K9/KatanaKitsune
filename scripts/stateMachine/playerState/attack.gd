class_name AttackState
extends PlayerClass


# Called when the state machine enters this state.
func on_enter():
	pc.speed = 0.0
	action_timer.start()

# Called every frame when this state is active.
func on_process(delta):
	if action_timer.is_stopped():
		change_state("idle")
	else:
		stateAnimation("attack",3)
		
func on_physics_process(delta):
	playerAttack()

# Called when the state machine exits this state.
func on_exit():
	action_timer.stop()


