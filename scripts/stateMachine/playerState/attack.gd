class_name AttackState
extends PlayerClass


# Called when the state machine enters this state.
func on_enter():
	pc.speed = 0.0
	pc.timerTimeOut = false
	action_timer.start()

# Called every frame when this state is active.
func on_process(delta):
	if action_timer.is_stopped():
		pc.timerTimeOut = true
		change_state("idle")
	else:
		stateAnimation("attack",3)
		
func on_physics_process(delta):
	if pc.timerTimeOut == false:
		playerAttack()

# Called when the state machine exits this state.
func on_exit():
	pc.timerTimeOut = true
	action_timer.stop()
