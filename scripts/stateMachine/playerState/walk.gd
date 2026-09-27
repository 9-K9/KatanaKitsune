extends PlayerClass

func on_enter():
	pc.speed = pc.walkSpeed

# Called every frame when this state is active.
func on_process(delta):	
	stateAnimation("walk",2)
	if pc.InputHandler() != Vector2.ZERO and Input.is_action_pressed("Run"):
		change_state("slowRun" if winded() else "run")
	elif pc.InputHandler() == Vector2.ZERO:
		change_state("idle")
	
	if Input.is_action_just_pressed("Katana"):
		change_state("katanaDraw")
	if Input.is_action_just_pressed("Attack"):
		change_state("highKick")
	if Input.is_action_just_pressed("Stealth"):
		change_state("stealthWalk")
	if Input.is_action_just_pressed("Dodge"):
		change_state("forwardRoll")
	if Input.is_action_just_pressed("Jump"):
		change_state("runningJump")
	
# Called every physics frame when this state is active.
func on_physics_process(delta):
	pass
		
func on_exit():
	pass
