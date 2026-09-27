extends PlayerClass

## Running with the blade out. Costs the same stamina as running without it —
## it used to cost nothing, which made drawing the katana the cheapest way to
## cross a floor.

func on_enter():
	pc.speed = pc.runSpeed

# Called every frame when this state is active.
func on_process(delta):
	stateAnimation("katanaRun",16)
	if pc.InputHandler() != Vector2.ZERO and Input.is_action_just_released("Run"):
		change_state("katanaWalk")
		return
	elif pc.InputHandler() == Vector2.ZERO:
		change_state("katanaIdle")
		return

	pc.drain_stamina(pc.run_drain, delta)
	## Out of wind: she can still walk it off, but not at a run.
	if winded():
		change_state("katanaWalk")
		return

	if Input.is_action_just_pressed("Katana"):
		change_state("katanaSeath")
	if Input.is_action_just_pressed("Attack"):
		change_state("katanaKick")
	if Input.is_action_just_pressed("Jump"):
		change_state("katanaJump")

# Called every physics frame when this state is active.
func on_physics_process(delta):
	pass

func on_exit():
	pass
