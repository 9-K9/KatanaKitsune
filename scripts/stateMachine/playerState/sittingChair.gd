extends PlayerClass

## Resting. She recovers health for as long as she is left alone, and any input
## gets her up again. Reached by standing still — see idle.gd.

var _chair: Node2D = null

func on_enter():
	pc.speed = 0.0
	pc.velocity = Vector2.ZERO
	_chair = chair_underfoot()
	if _chair == null:
		change_state("idle")
		return
	pc.global_position = _chair_position(_chair)
	if _chair.has_method("get_sit_facing"):
		pc.facing_dir = _chair.get_sit_facing()

func on_process(_delta):
	stateAnimation("sittingChair", 2)
	if pc.InputHandler() != Vector2.ZERO \
			or Input.is_action_just_pressed("Attack") \
			or Input.is_action_just_pressed("Katana") \
			or Input.is_action_just_pressed("Stealth") \
			or Input.is_action_just_pressed("Jump") \
			or Input.is_action_just_pressed("Dodge"):
		change_state("idle")

func on_physics_process(delta):
	pc.rest(delta)

func on_exit():
	_chair = null
