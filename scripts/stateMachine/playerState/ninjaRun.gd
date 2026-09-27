extends PlayerClass

## Flat-out sprint. Faster than run, and reached by holding Run while already
## running rather than by a separate key.

func on_enter():
	pc.speed = pc.runSpeed * 1.35

func on_process(_delta):
	stateAnimation("ninjaRun", 12)
	if pc.InputHandler() == Vector2.ZERO:
		change_state("idle")
	elif not Input.is_action_pressed("Run"):
		change_state("walk")
	if Input.is_action_just_pressed("Jump"):
		change_state("runningJump")
	if Input.is_action_just_pressed("Katana"):
		change_state("katanaDraw")
