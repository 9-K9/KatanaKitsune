extends PlayerClass

## Crouched and still. Monsters notice her at half range while she is in stealth
## — see PlayerClass.stealth_ratio, which EnemyBase multiplies its detection by.

func on_enter():
	pc.speed = 0.0
	pc.stealthed = true

func on_process(_delta):
	stateAnimation("stealthIdle", 1)
	if Input.is_action_just_pressed("Stealth"):
		change_state("idle")
		return
	if pc.InputHandler() != Vector2.ZERO:
		change_state("stealthWalk")
	if Input.is_action_just_pressed("Defend"):
		change_state("stealthCrouch")
	if Input.is_action_just_pressed("Katana"):
		change_state("katanaDraw")

func on_exit():
	pc.stealthed = false
