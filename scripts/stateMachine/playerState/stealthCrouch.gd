extends PlayerClass

## Flat against the floor. The quietest she gets, she cannot move, and it is the
## only place the stealth attack opens from.

func on_enter():
	pc.speed = 0.0
	pc.stealthed = true
	pc.crouched = true

func on_process(_delta):
	stateAnimation("stealthCrouch")
	## Striking from a crouch is the stealth attack.
	if pc.input.just_pressed("Attack"):
		change_state("flair")
		return
	if pc.input.just_pressed("Defend") or pc.InputHandler() != Vector2.ZERO:
		change_state("stealthIdle")
	if pc.input.just_pressed("Jump"):
		change_state("forwardRoll")
	if pc.input.just_pressed("Stealth"):
		change_state("idle")

func on_exit():
	pc.stealthed = false
	pc.crouched = false
