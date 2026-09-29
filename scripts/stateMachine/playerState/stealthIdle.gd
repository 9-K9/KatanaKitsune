extends PlayerClass

## Crouched and still. Monsters notice her at half range while she is in stealth
## — see PlayerClass.stealth_ratio, which EnemyBase multiplies its detection by.

func on_enter():
	pc.speed = 0.0
	pc.stealthed = true

func on_process(_delta):
	## Hiding costs. Being unseen is the strongest position in the game, so it
	## runs on a meter and she is forced upright when it empties rather than
	## being able to cross a whole floor unnoticed.
	pc.drain_sneak(pc.sneak_drain * 0.5, _delta)
	if pc.sneak_spent():
		change_state("idle")
		return
	stateAnimation("stealthIdle", 1)
	## Striking from cover is the stealth attack, wherever she is hidden.
	if Input.is_action_just_pressed("Attack"):
		change_state("flair")
		return
	if Input.is_action_just_pressed("Stealth"):
		change_state("idle")
		return
	if pc.InputHandler() != Vector2.ZERO:
		change_state("stealthWalk")
	if Input.is_action_just_pressed("Defend"):
		change_state("stealthCrouch")
	if Input.is_action_just_pressed("Katana"):
		change_state("katanaDraw")

	if Input.is_action_just_pressed("Jump"):
		change_state("forwardRoll")

func on_exit():
	pc.stealthed = false
