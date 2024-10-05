class_name WalkState
extends PlayerClass

func on_enter():
	pc.speed = pc.walkSpeed

# Called every frame when this state is active.
func on_process(delta):	
	stateAnimation("walk",2)
	if pc.InputHandler() != Vector2.ZERO and Input.is_action_pressed("Run"):
		change_state("run")
	elif pc.InputHandler() == Vector2.ZERO:
		change_state("idle")
	
	if Input.is_action_just_pressed("Attack"):
		pass
		#change_state("attack")
	
# Called every physics frame when this state is active.
func on_physics_process(delta):
	pass
		
func on_exit():
	pass
