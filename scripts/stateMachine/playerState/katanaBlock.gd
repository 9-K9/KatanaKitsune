extends PlayerClass

## Guard up. Held, not toggled: releasing Defend drops straight back to idle.
## Incoming damage is cut while pc.blocking is set — see AnimatedCharacterClass.
##
## Moving does not break the guard. It used to fall through to the crouched block
## the instant a movement key was touched, which made the standing guard almost
## impossible to see; crouching is now a deliberate press of Stealth.

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
	if Input.is_action_just_pressed("Stealth"):
		change_state("katanaBlockCrouched")
		return
	## A hit taken inside the parry window opens the riposte.
	if pc.parry_ready:
		change_state("katanaCounterSlash")

	if Input.is_action_just_pressed("Jump"):
		change_state("forwardRoll")

func on_exit():
	pc.blocking = false
	pc.actionBlockInput = false
