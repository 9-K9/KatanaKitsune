extends PlayerClass

## Braced low. Blocks the same, and is the harder read for anything swinging high.

func on_enter():
	pc.speed = 0.0
	pc.blocking = true
	pc.crouched = true
	pc.actionBlockInput = true
	pc.block_opened_at = Time.get_ticks_msec()

func on_process(_delta):
	stateAnimation("katanaBlockCrouched", 4)
	if not pc.input.pressed("Defend"):
		change_state("katanaIdle")
		return
	if pc.input.just_pressed("Stealth"):
		change_state("katanaBlock")
		return
	if pc.parry_ready:
		change_state("katanaCounterSlash")

	if pc.input.just_pressed("Jump"):
		change_state("forwardRoll")

func on_exit():
	pc.blocking = false
	pc.crouched = false
	pc.actionBlockInput = false
