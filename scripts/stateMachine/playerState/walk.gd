extends PlayerClass

func on_enter():
	pc.speed = pc.walkSpeed

# Called every frame when this state is active.
func on_process(delta):	
	stateAnimation("walk",2)
	if pc.InputHandler() != Vector2.ZERO and pc.input.pressed("Run"):
		change_state("slowRun" if winded() else "run")
	elif pc.InputHandler() == Vector2.ZERO:
		change_state("idle")
	
	if pc.input.just_pressed("Katana"):
		change_state("katanaDraw")
	if pc.input.just_pressed("Attack"):
		change_state("highKick")
	if pc.input.just_pressed("Stealth"):
		if pc.can_sneak():
			change_state("stealthWalk")
			return
	if pc.input.just_pressed("Dodge"):
		change_state("forwardRoll")
	if pc.input.just_pressed("Jump"):
		change_state("runningJump")
	
# Called every physics frame when this state is active.
func on_physics_process(delta):
	pass
		
func on_exit():
	pass
