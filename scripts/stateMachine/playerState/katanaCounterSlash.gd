extends PlayerClass

## The riposte. Only reachable from a block that absorbed a hit inside its parry
## window, and it hits harder than an ordinary swing — the reward for timing a
## guard rather than holding one.

const COUNTER_BONUS: float = 2.0

var _base_damage: float = 0.0

func on_enter():
	pc.speed = 0.0
	pc.actionBlockInput = true
	pc.parry_ready = false
	_base_damage = pc.damage
	pc.damage = _base_damage * COUNTER_BONUS
	action_timer.wait_time = 0.8
	action_timer.start()
	beginAttack()

func on_process(_delta):
	stateAnimation("katanaCounterSlash", 10)
	playerAttack(2)

func on_physics_process(_delta):
	if action_timer.is_stopped():
		change_state("katanaIdle")

func on_exit():
	pc.damage = _base_damage
	pc.actionBlockInput = false
	action_timer.stop()
