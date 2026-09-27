extends PlayerClass

func on_enter():
	pc.speed = 0.0
		
# Called every frame when this state is active.
func on_process(delta):
	stateAnimation("idle",1)	
	if 	pc.InputHandler() != Vector2.ZERO and Input.is_action_pressed("Run"):
		change_state("run")	
	elif pc.InputHandler() != Vector2.ZERO:
		change_state("walk")
		
	if Input.is_action_just_pressed("Katana"):
		change_state("katanaDraw")	
	if Input.is_action_just_pressed("Attack"):
		change_state("midKick")
	if Input.is_action_just_pressed("Stealth"):
		change_state("stealthIdle")
	if Input.is_action_just_pressed("Dodge"):
		change_state("forwardRoll")
	
func on_physics_process(delta):
	pass
	
func on_exit():
	pass
