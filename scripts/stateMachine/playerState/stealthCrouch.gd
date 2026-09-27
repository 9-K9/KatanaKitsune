extends PlayerClass

## Flat against the floor. The quietest she gets, and she cannot move.

func on_enter():
	pc.speed = 0.0
	pc.stealthed = true
	pc.crouched = true

func on_process(_delta):
	stateAnimation("stealthCrouch", 2)
	if Input.is_action_just_pressed("Defend") or pc.InputHandler() != Vector2.ZERO:
		change_state("stealthIdle")
	if Input.is_action_just_pressed("Stealth"):
		change_state("idle")

func on_exit():
	pc.stealthed = false
	pc.crouched = false
