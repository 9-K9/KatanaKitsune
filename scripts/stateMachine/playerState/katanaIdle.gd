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
		
	if Input.is_action_just_pressed("Katana"):
		change_state("katanaSeath")	
	if Input.is_action_just_pressed("Attack"):
		change_state("katanaChargeAttack")
	if Input.is_action_pressed("Defend"):
		change_state("katanaBlock")
	if Input.is_action_just_pressed("Dodge"):
		change_state("forwardRoll")
	if Input.is_action_just_pressed("Jump"):
		change_state("katanaJump")
	
func on_physics_process(delta):
	pass
	
func on_exit():
	pass
