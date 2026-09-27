extends PlayerClass

## Walking with the blade out. Attack is tap-or-hold here exactly as it is in
## katanaIdle: a tap is the moving cut, holding plants her and winds up the
## heavy one. Without this the charge was unreachable in a fight, because any
## movement dropped her out of katanaIdle before the hold could be counted.
const CHARGE_HOLD: float = 0.22

var _attack_held: float = 0.0

func on_enter():
	pc.speed = pc.walkSpeed
	_attack_held = 0.0

# Called every frame when this state is active.
func on_process(delta):
	stateAnimation("katanaWalk",8)

	## Before the movement transitions, so holding Attack always wins.
	if Input.is_action_pressed("Attack"):
		_attack_held += delta
		if _attack_held >= CHARGE_HOLD:
			change_state("katanaChargeAttack")
		return
	elif _attack_held > 0.0:
		change_state("katanaSlashCrouched")
		return

	## Not promoted to a run while winded, or the two trade places every frame.
	if pc.InputHandler() != Vector2.ZERO and Input.is_action_pressed("Run") and not winded():
		change_state("katanaRun")
		return
	elif pc.InputHandler() == Vector2.ZERO:
		change_state("katanaIdle")
		return

	if Input.is_action_just_pressed("Katana"):
		change_state("katanaSeath")
	if Input.is_action_just_pressed("Jump"):
		change_state("katanaJump")

# Called every physics frame when this state is active.
func on_physics_process(delta):
	pass

func on_exit():
	pass
