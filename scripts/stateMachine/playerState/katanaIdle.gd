class_name KatanaIdleState
extends PlayerClass

func on_enter():
	pc.speed = 0.0
		
# Called every frame when this state is active.
func on_process(delta):
	stateAnimation("katanaIdle",1)	
	if 	pc.InputHandler() != Vector2.ZERO and Input.is_action_pressed("Run"):
		change_state("katanaRun")	
	elif pc.InputHandler() != Vector2.ZERO:
		change_state("katanaWalk")
		
	if Input.is_action_just_pressed("Attack"):
		change_state("katanaSeath")	
	
func on_physics_process(delta):
	pass
	
func on_exit():
	pass
