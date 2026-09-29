extends PlayerClass

## Clearing the scabbard. Sped up to match the sheathe — both used to run for a
## fixed 0.75s during which she could neither move nor act.
const RATE: float = 1.45

var _left: float = 0.0


func on_enter():
	pc.katana_drawn = true
	pc.speed = 0.0
	_left = play_oneshot("katanaDraw", RATE)


func on_physics_process(delta):
	_left -= delta
	if _left <= 0.0:
		change_state("katanaIdle")


func on_exit():
	animated_sprite.speed_scale = 1.0
