extends PlayerClass

## Sneaking. Slower than a walk, and quiet: detection range is halved.

func on_enter():
	pc.speed = pc.walkSpeed * 0.55
	pc.stealthed = true

func on_process(_delta):
	## Moving unseen is what costs. Crouching in a corner is free — the meter
	## exists to stop her crossing a whole floor unnoticed, not to punish
	## waiting, and a gauge that drains while you stand still just means you
	## never stand still.
	pc.drain_sneak(pc.sneak_drain, _delta)
	if pc.sneak_spent():
		change_state("walk")
		return
	stateAnimation("stealthWalk", 2)
	## Striking from cover is the stealth attack, wherever she is hidden.
	if Input.is_action_just_pressed("Attack"):
		change_state("flair")
		return
	if Input.is_action_just_pressed("Stealth"):
		change_state("walk")
		return
	if pc.InputHandler() == Vector2.ZERO:
		change_state("stealthIdle")
		return

	## Running while hidden is the ninja run, provided she has the wind for it.
	if Input.is_action_pressed("Run") and not winded():
		change_state("ninjaRun")
		return

	if Input.is_action_just_pressed("Jump"):
		change_state("forwardRoll")
	if Input.is_action_just_pressed("Katana"):
		change_state("katanaDraw")

func on_exit():
	pc.stealthed = false
