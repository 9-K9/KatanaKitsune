extends PlayerClass

## Crouched and still. Monsters notice her at half range while she is in stealth
## — see PlayerClass.stealth_ratio, which EnemyBase multiplies its detection by.

func on_enter():
	pc.speed = 0.0
	pc.stealthed = true

func on_process(_delta):
	stateAnimation("stealthIdle", 1)
	## Striking from cover is the stealth attack, wherever she is hidden.
	if pc.input.just_pressed("Attack"):
		change_state("flair")
		return
	if pc.input.just_pressed("Stealth"):
		change_state("idle")
		return
	if pc.InputHandler() != Vector2.ZERO:
		change_state("stealthWalk")
	if pc.input.just_pressed("Defend"):
		change_state("stealthCrouch")
	if pc.input.just_pressed("Katana"):
		change_state("katanaDraw")

	if pc.input.just_pressed("Jump"):
		change_state("forwardRoll")

func on_exit():
	pc.stealthed = false
