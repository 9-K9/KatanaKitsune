extends PlayerClass

## Braced low. Blocks the same but cannot be pushed as easily.

func on_enter():
	pc.speed = 0.0
	pc.blocking = true
	pc.crouched = true
	pc.actionBlockInput = true

func on_process(_delta):
	stateAnimation("katanaBlockCrouched", 4)
	if not Input.is_action_pressed("Defend"):
		change_state("katanaIdle")
		return
	if pc.parry_ready:
		change_state("katanaCounterSlash")

func on_exit():
	pc.blocking = false
	pc.crouched = false
	pc.actionBlockInput = false
