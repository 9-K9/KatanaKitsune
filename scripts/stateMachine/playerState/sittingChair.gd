extends PlayerClass

## Resting. She recovers health for as long as she is left alone, and any input
## gets her up again. Reached by standing still — see idle.gd.
##
## She walks the last few steps to the seat rather than being teleported onto
## it. Snapping made every near-miss look like a mistake: she would be standing
## beside a chair and appear on it a frame later, and any error in the seat
## position showed up as her sitting in mid-air. Walking in covers small errors
## and reads as intent.

## Close enough to the seat to settle onto it.
const ARRIVED_WITHIN: float = 5.0
## Walking in is abandoned after this, in case something is in the way. She sits
## where she stands rather than shuffling against an obstacle forever.
const APPROACH_LIMIT: float = 1.2
## Slower than a walk — she is settling down, not going somewhere.
const APPROACH_SPEED: float = 0.55

var _chair: Node2D = null
var _seat: Vector2 = Vector2.ZERO
var _seated: bool = false
var _approach_left: float = 0.0


func on_enter():
	pc.speed = 0.0
	pc.velocity = Vector2.ZERO
	_chair = chair_underfoot()
	if _chair == null:
		change_state("idle")
		return
	_seat = _chair_position(_chair)
	_seated = false
	_approach_left = APPROACH_LIMIT


func on_process(_delta):
	## The walk plays while she is closing the gap, the sit once she is there.
	if _seated:
		stateAnimation("sittingChair")
	else:
		stateAnimation("walk")

	if pc.InputHandler() != Vector2.ZERO \
			or pc.input.just_pressed("Attack") \
			or pc.input.just_pressed("Katana") \
			or pc.input.just_pressed("Stealth") \
			or pc.input.just_pressed("Jump") \
			or pc.input.just_pressed("Dodge"):
		change_state("idle")


func on_physics_process(delta):
	if not _seated:
		_walk_in(delta)
		return
	pc.rest(delta)


func _walk_in(delta: float) -> void:
	_approach_left -= delta
	var to_seat: Vector2 = _seat - pc.global_position
	## Measured along the ground, like every other distance here, so she does not
	## stop short when the last of the gap happens to be vertical.
	var ground := to_seat
	ground.y /= 0.5
	if ground.length() <= ARRIVED_WITHIN or _approach_left <= 0.0:
		_settle()
		return

	var step: Vector2 = to_seat.normalized()
	pc.facing_dir = pc.directionState(round(step))
	pc.velocity = step * pc.walkSpeed * APPROACH_SPEED
	pc.velocity.y *= 0.5
	pc.move_and_slide()


func _settle() -> void:
	_seated = true
	AudioManager.play_for("sfx_player_sit_rest", pc, -5.0)
	pc.velocity = Vector2.ZERO
	pc.speed = 0.0
	## The last pixels are taken exactly: walking gets her close, and the seat is
	## a fixed spot the art was drawn around.
	pc.global_position = _seat
	if _chair.has_method("get_sit_facing"):
		pc.facing_dir = _chair.get_sit_facing()


func on_exit():
	_chair = null
	_seated = false
