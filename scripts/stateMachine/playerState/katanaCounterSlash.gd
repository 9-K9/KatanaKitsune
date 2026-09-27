extends PlayerClass

## The riposte. Only reachable from a block that absorbed a hit inside its parry
## window, and it hits harder than an ordinary swing — the reward for timing a
## guard rather than holding one.
const RATE: float = 2.0
const COUNTER_BONUS: float = 2.0

var _base_damage: float = 0.0

func on_enter():
	pc.speed = 0.0
	pc.actionBlockInput = true
	pc.parry_ready = false
	_base_damage = pc.damage
	pc.damage = _base_damage * COUNTER_BONUS
	beginAttack()
	action_timer.wait_time = play_oneshot("katanaCounterSlash", RATE)
	action_timer.start()

func on_process(_delta):
	playerAttack(2)

func on_physics_process(_delta):
	if action_timer.is_stopped():
		change_state("katanaIdle")

func on_exit():
	pc.damage = _base_damage
	pc.actionBlockInput = false
	animated_sprite.speed_scale = 1.0
	action_timer.stop()
