extends PlayerClass

## Running with the blade out. Costs the same stamina as running without it —
## it used to cost nothing, which made drawing the katana the cheapest way to
## cross a floor.

func on_enter():
	pc.speed = pc.phase_run_speed(false)

# Called every frame when this state is active.
func on_process(delta):
	pc.speed = pc.phase_run_speed(false)
	stateAnimation("katanaRun")
	if pc.InputHandler() != Vector2.ZERO and pc.input.just_released("Run"):
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

	if pc.input.just_pressed("Katana"):
		change_state("katanaSeath")
	if pc.input.just_pressed("Attack"):
		change_state("katanaKick")
	if pc.input.just_pressed("Jump"):
		change_state("katanaJump")

# Called every physics frame when this state is active.
func on_physics_process(delta):
	pass

func on_exit():
	pass
