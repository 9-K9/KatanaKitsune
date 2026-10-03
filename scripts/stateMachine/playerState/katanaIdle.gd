extends PlayerClass

## Blade out and waiting. Attack is tap-or-hold: a tap is the quick standing
## slash, holding winds up the heavy one.
const CHARGE_HOLD: float = 0.22

var _attack_held: float = 0.0

func on_enter():
	pc.speed = 0.0
	_attack_held = 0.0

# Called every frame when this state is active.
func on_process(delta):
	stateAnimation("katanaIdle")
	## Checked before movement. This used to sit below, so any stick input sent
	## her to katanaWalk first and the wind-up was unreachable — in a fight she
	## is always moving, which made the charged attack impossible to land.
	if pc.input.pressed("Attack"):
		_attack_held += delta
		## Plants while deciding, so the wind-up reads as a commitment.
		if _attack_held >= CHARGE_HOLD:
			change_state("katanaChargeAttack")
		return
	elif _attack_held > 0.0:
		## Let go before the wind-up: a quick standing cut.
		change_state("katanaSlashStand")
		return

	if 	pc.InputHandler() != Vector2.ZERO and pc.input.pressed("Run"):
		change_state("katanaRun")
		return
	elif pc.InputHandler() != Vector2.ZERO:
		change_state("katanaWalk")
		return

	if pc.input.just_pressed("Katana"):
		change_state("katanaSeath")
	if pc.input.pressed("Defend"):
		change_state("katanaBlock")
	if pc.input.just_pressed("Dodge"):
		change_state("forwardRoll")
	if pc.input.just_pressed("Jump"):
		change_state("katanaJump")

func on_physics_process(delta):
	pass

func on_exit():
	pass
