extends PlayerClass

func on_enter():
	pc.speed = pc.walkSpeed

# Called every frame when this state is active.
func on_process(delta):	
	stateAnimation("katanaWalk",8)
	if pc.InputHandler() != Vector2.ZERO and Input.is_action_pressed("Run"):
		change_state("katanaRun")
	elif pc.InputHandler() == Vector2.ZERO:
		change_state("katanaIdle")
	
	if Input.is_action_just_pressed("Katana"):
		change_state("katanaSeath")
	if Input.is_action_just_pressed("Attack"):
		change_state("katanaSlashCrouched")	
	
# Called every physics frame when this state is active.
func on_physics_process(delta):
	pass
		
func on_exit():
	pass
