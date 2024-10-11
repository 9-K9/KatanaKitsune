class_name RunState
extends PlayerClass

func on_enter():
	pc.speed = pc.runSpeed

# Called every frame when this state is active.
func on_process(delta):
	stateAnimation("fastRun",3)
	if pc.InputHandler() != Vector2.ZERO and Input.is_action_just_released("Run"):
		change_state("walk")
	elif pc.InputHandler() == Vector2.ZERO:
		change_state("idle")
	
	if Input.is_action_just_pressed("Attack"):
		change_state("katanaDraw")

# Called every physics frame when this state is active.
func on_physics_process(delta):
	pass
	
func on_exit():
	pass
