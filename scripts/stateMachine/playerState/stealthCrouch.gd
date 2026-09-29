extends PlayerClass

## Flat against the floor. The quietest she gets, she cannot move, and it is the
## only place the stealth attack opens from.

func on_enter():
	pc.speed = 0.0
	pc.stealthed = true
	pc.crouched = true

func on_process(_delta):
	## Hiding costs. Being unseen is the strongest position in the game, so it
	## runs on a meter and she is forced upright when it empties rather than
	## being able to cross a whole floor unnoticed.
	pc.drain_sneak(pc.crouch_drain, _delta)
	if pc.sneak_spent():
		change_state("idle")
		return
	stateAnimation("stealthCrouch", 2)
	## Striking from a crouch is the stealth attack.
	if Input.is_action_just_pressed("Attack"):
		change_state("flair")
		return
	if Input.is_action_just_pressed("Defend") or pc.InputHandler() != Vector2.ZERO:
		change_state("stealthIdle")
	if Input.is_action_just_pressed("Jump"):
		change_state("forwardRoll")
	if Input.is_action_just_pressed("Stealth"):
		change_state("idle")

func on_exit():
	pc.stealthed = false
	pc.crouched = false
