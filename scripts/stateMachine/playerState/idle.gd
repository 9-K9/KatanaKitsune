extends PlayerClass

## Left alone this long she sits down, and sitting mends her — so resting is a
## real option between fights rather than something only potions can do.
const REST_AFTER: float = 8.0

var _still_for: float = 0.0

func on_enter():
	pc.speed = 0.0
	_still_for = 0.0

# Called every frame when this state is active.
func on_process(delta):
	stateAnimation("idle",1)
	var input: Vector2 = pc.InputHandler()
	if 	input != Vector2.ZERO and Input.is_action_pressed("Run"):
		change_state("slowRun" if winded() else "run")
		return
	elif input != Vector2.ZERO:
		change_state("walk")
		return

	if Input.is_action_just_pressed("Katana"):
		change_state("katanaDraw")
	if Input.is_action_just_pressed("Attack"):
		change_state("midKick")
	if Input.is_action_just_pressed("Stealth"):
		change_state("stealthIdle")
	if Input.is_action_just_pressed("Dodge"):
		change_state("forwardRoll")
	if Input.is_action_just_pressed("Jump"):
		change_state("runningJump")
	## Unarmed, Defend is the taunt — it pulls a patrol off its route.
	if Input.is_action_just_pressed("Defend"):
		change_state("seductiveDance")
		return

	_still_for += delta
	if _still_for >= REST_AFTER:
		## Takes the chair if she is standing over one, otherwise the floor.
		change_state("sittingChair" if chair_underfoot() != null else "sittingFloor")

func on_physics_process(delta):
	pass

func on_exit():
	pass
