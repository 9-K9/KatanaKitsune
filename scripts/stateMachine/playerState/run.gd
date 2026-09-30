extends PlayerClass

## Running burns stamina. Run it dry and she drops to a jog, so a long chase
## costs her the speed to get out of the next one.

## A reversal only counts once she is actually up to speed; before that her
## facing is still catching up to the stick and every start would skid.
const TURN_GRACE: float = 0.3

var _held: float = 0.0

func on_enter():
	pc.speed = pc.runSpeed
	_held = 0.0

# Called every frame when this state is active.
func on_process(delta):
	stateAnimation("fastRun",3)
	var input: Vector2 = pc.InputHandler()
	if input != Vector2.ZERO and pc.input.just_released("Run"):
		change_state("walk")
		return
	elif input == Vector2.ZERO:
		change_state("idle")
		return

	_held += delta
	pc.drain_stamina(pc.run_drain, delta)
	if winded():
		change_state("slowRun")
		return

	## Reversing at speed plants a skid-turn rather than snapping round a frame.
	if _held >= TURN_GRACE \
			and pc.stateDirection(pc.facing_dir).normalized().dot(input.normalized()) < -0.65:
		change_state("switchDirections")
		return

	if pc.input.just_pressed("Katana"):
		change_state("katanaDraw")
	if pc.input.just_pressed("Attack"):
		change_state("roundKick")
	if pc.input.just_pressed("Jump"):
		change_state("runningJump")
	if pc.input.just_pressed("Stealth"):
		change_state("ninjaRun")

# Called every physics frame when this state is active.
func on_physics_process(delta):
	pass

func on_exit():
	pass
