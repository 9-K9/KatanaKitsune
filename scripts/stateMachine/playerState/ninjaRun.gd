extends PlayerClass

## The stealth run: fast and quiet. Reached by running while in stealth, and it
## keeps her hidden, so it is the only way to cross open ground unseen in a
## hurry. Costs the most stamina of anything she can do.

func on_enter():
	pc.speed = pc.runSpeed * 1.35
	pc.stealthed = true

func on_process(delta):
	stateAnimation("ninjaRun", 12)
	if pc.InputHandler() == Vector2.ZERO:
		change_state("stealthIdle")
		return
	if not Input.is_action_pressed("Run"):
		change_state("stealthWalk")
		return

	pc.drain_stamina(pc.sprint_drain, delta)
	if winded():
		change_state("stealthWalk")
		return

	if Input.is_action_just_pressed("Stealth"):
		change_state("run")
	if Input.is_action_just_pressed("Jump"):
		change_state("forwardRoll")
	if Input.is_action_just_pressed("Katana"):
		change_state("katanaDraw")

func on_exit():
	pc.stealthed = false
