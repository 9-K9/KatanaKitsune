extends PlayerClass

## The stealth run: fast and quiet. Reached by running while in stealth, and it
## keeps her hidden, so it is the only way to cross open ground unseen in a
## hurry. Costs the most stamina of anything she can do.

func on_enter():
	## The single fastest movement in the game. Staying hidden costs a meter and
	## gives up the katana, so it has to buy something you can feel.
	pc.speed = pc.runSpeed * 1.55
	pc.stealthed = true

func on_process(delta):
	## Sprinting while hidden is the best movement in the game, so it carries the
	## running rate rather than a multiple of the creeping one.
	pc.drain_sneak(pc.sneak_run_drain, delta)
	if pc.sneak_spent():
		change_state("run")
		return
	stateAnimation("ninjaRun", 12)
	if pc.InputHandler() == Vector2.ZERO:
		change_state("stealthIdle")
		return
	if not pc.input.pressed("Run"):
		change_state("stealthWalk")
		return

	pc.drain_stamina(pc.sprint_drain, delta)
	if winded():
		change_state("stealthWalk")
		return

	if pc.input.just_pressed("Stealth"):
		change_state("run")
	if pc.input.just_pressed("Jump"):
		change_state("forwardRoll")
	if pc.input.just_pressed("Katana"):
		change_state("katanaDraw")

func on_exit():
	pc.stealthed = false
