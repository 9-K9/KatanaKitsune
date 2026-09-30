extends PlayerClass

## Skid-turn. Reversing at a run plants her instead of snapping the sprite round
## in a single frame. Input stays live so she comes out of it already facing the
## new way, which is also what stops it re-triggering on itself.
const RATE: float = 2.0

func on_enter():
	pc.speed = 0.0
	action_timer.wait_time = play_oneshot("switchDirections", RATE)
	action_timer.start()

func on_physics_process(_delta):
	## Bleeds off the speed she arrived with, so the plant has some weight.
	pc.velocity *= 0.82
	pc.move_and_slide()
	if action_timer.is_stopped():
		if pc.InputHandler() == Vector2.ZERO:
			change_state("idle")
		else:
			change_state("run" if pc.input.pressed("Run") else "walk")

func on_exit():
	animated_sprite.speed_scale = 1.0
	action_timer.stop()
