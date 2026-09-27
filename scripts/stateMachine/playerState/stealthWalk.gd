extends PlayerClass

## Sneaking. Slower than a walk, and quiet: detection range is halved.

func on_enter():
	pc.speed = pc.walkSpeed * 0.55
	pc.stealthed = true

func on_process(_delta):
	stateAnimation("stealthWalk", 2)
	if Input.is_action_just_pressed("Stealth"):
		change_state("walk")
		return
	if pc.InputHandler() == Vector2.ZERO:
		change_state("stealthIdle")
	if Input.is_action_just_pressed("Katana"):
		change_state("katanaDraw")

func on_exit():
	pc.stealthed = false
