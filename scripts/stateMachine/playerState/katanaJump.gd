extends PlayerClass

## A hop with the blade out. Short, and it does not clear anything — it is a
## repositioning move, not traversal.

const HOP_TIME: float = 0.5
const HOP_SPEED: float = 200.0

var _heading: Vector2 = Vector2.ZERO

func on_enter():
	pc.actionBlockInput = true
	var input: Vector2 = pc.InputHandler()
	_heading = input if input != Vector2.ZERO else pc.stateDirection(pc.facing_dir)
	action_timer.wait_time = HOP_TIME
	action_timer.start()

func on_process(_delta):
	stateAnimation("katanaJump", 10)

func on_physics_process(_delta):
	pc.velocity = _heading.normalized() * HOP_SPEED
	pc.velocity.y *= 0.5
	pc.move_and_slide()
	if action_timer.is_stopped():
		change_state("katanaIdle")

func on_exit():
	pc.actionBlockInput = false
	action_timer.stop()
