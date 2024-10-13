extends PlayerClass

# Called when the state machine enters this state.
func on_enter():
	pc.speed = 0.0
	pc.actionBlockInput = true
	pc.timerTimeOut = false
	action_timer.wait_time = 1
	action_timer.start()

# Called every frame when this state is active.
func on_process(delta):
	stateAnimation("midKick",8)
		
func on_physics_process(delta):
	if action_timer.is_stopped():
		pc.timerTimeOut = true
		change_state("idle")
		
# Called when the state machine exits this state.
func on_exit():
	pc.actionBlockInput = false
	pc.timerTimeOut = true
	action_timer.stop()
