extends PlayerClass

## Dodge roll. Carries her a fixed distance and cannot be cancelled, so spending
## it is a commitment; she is untouchable for most of it.

const ROLL_TIME: float = 0.55
const ROLL_SPEED: float = 240.0

var _heading: Vector2 = Vector2.ZERO

func on_enter():
	pc.actionBlockInput = true
	## Rolls the way she is facing if she is standing still.
	var input: Vector2 = pc.InputHandler()
	_heading = input if input != Vector2.ZERO else pc.stateDirection(pc.facing_dir)
	pc.is_invincible = true
	action_timer.wait_time = ROLL_TIME
	action_timer.start()

func on_process(_delta):
	stateAnimation("forwardRoll", 12)

func on_physics_process(_delta):
	pc.velocity = _heading.normalized() * ROLL_SPEED
	pc.velocity.y *= 0.5
	pc.move_and_slide()
	if action_timer.is_stopped():
		change_state("katanaIdle" if pc.katana_drawn else "idle")

func on_exit():
	pc.is_invincible = false
	pc.actionBlockInput = false
	action_timer.stop()
