extends PlayerClass

## A jog: all that is left once stamina is gone. Holding Run gets her this until
## she has recovered enough to break back into a proper run.
const RECOVERED_AT: float = 35.0

func on_enter():
	pc.speed = pc.walkSpeed * 1.3

func on_process(_delta):
	stateAnimation("slowRun")
	if pc.InputHandler() == Vector2.ZERO:
		change_state("idle")
		return
	if not pc.input.pressed("Run"):
		change_state("walk")
		return

	## Back on her feet, so the run is available again.
	if pc.stamina >= RECOVERED_AT:
		change_state("run")
		return

	if pc.input.just_pressed("Jump"):
		change_state("runningJump")
	if pc.input.just_pressed("Attack"):
		change_state("roundKick")
	if pc.input.just_pressed("Katana"):
		change_state("katanaDraw")
