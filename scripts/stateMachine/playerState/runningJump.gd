extends PlayerClass

## A leap out of a run. Longer than the standing hop because it keeps the speed
## she already had.

const LEAP_TIME: float = 0.6
const LEAP_SPEED: float = 300.0

var _heading: Vector2 = Vector2.ZERO

func on_enter():
	pc.actionBlockInput = true
	var input: Vector2 = pc.InputHandler()
	_heading = input if input != Vector2.ZERO else pc.stateDirection(pc.facing_dir)
	action_timer.wait_time = LEAP_TIME
	action_timer.start()

func on_process(_delta):
	stateAnimation("runningJump", 10)

func on_physics_process(_delta):
	pc.velocity = _heading.normalized() * LEAP_SPEED
	pc.velocity.y *= 0.5
	pc.move_and_slide()
	if action_timer.is_stopped():
		change_state("run")

func on_exit():
	pc.actionBlockInput = false
	action_timer.stop()
