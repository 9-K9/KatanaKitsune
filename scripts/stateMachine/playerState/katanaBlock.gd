extends PlayerClass

## Guard up. Held, not toggled: releasing Defend drops straight back to idle.
## Incoming damage is cut while pc.blocking is set — see AnimatedCharacterClass.

func on_enter():
	pc.speed = 0.0
	pc.blocking = true
	pc.actionBlockInput = true
	pc.block_opened_at = Time.get_ticks_msec()

func on_process(_delta):
	stateAnimation("katanaBlock", 4)
	if not Input.is_action_pressed("Defend"):
		change_state("katanaIdle")
		return
	if pc.InputHandler() != Vector2.ZERO:
		change_state("katanaBlockCrouched")
	## A hit taken inside the parry window opens the riposte.
	if pc.parry_ready:
		change_state("katanaCounterSlash")

func on_exit():
	pc.blocking = false
	pc.actionBlockInput = false
