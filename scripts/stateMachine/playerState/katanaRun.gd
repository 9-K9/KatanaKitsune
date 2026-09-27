extends PlayerClass

func on_enter():
	pc.speed = pc.runSpeed

# Called every frame when this state is active.
func on_process(delta):
	stateAnimation("katanaRun",16)
	if pc.InputHandler() != Vector2.ZERO and Input.is_action_just_released("Run"):
		change_state("katanaWalk")
	elif pc.InputHandler() == Vector2.ZERO:
		change_state("katanaIdle")
	
	if Input.is_action_just_pressed("Katana"):
		change_state("katanaSeath")
	if Input.is_action_just_pressed("Attack"):
		change_state("katanaKick")

# Called every physics frame when this state is active.
func on_physics_process(delta):
	pass
	
	if Input.is_action_just_pressed("Jump"):
		change_state("katanaJump")

func on_exit():
	pass
