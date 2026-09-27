extends PlayerClass

## The stealth attack, out of a crouch. Hits for far more than an honest swing —
## the payoff for crossing a room unseen instead of charging it.
const RATE: float = 1.5
const ASSASSINATE_BONUS: float = 4.0

var _base_damage: float = 0.0

func on_enter():
	pc.speed = 0.0
	pc.actionBlockInput = true
	_base_damage = pc.damage
	pc.damage = _base_damage * ASSASSINATE_BONUS
	beginAttack()
	action_timer.wait_time = play_oneshot("flair", RATE)
	action_timer.start()

func on_process(_delta):
	playerAttack(3)

func on_physics_process(_delta):
	if action_timer.is_stopped():
		## Straight back into cover, still hidden.
		change_state("stealthCrouch")

func on_exit():
	pc.damage = _base_damage
	pc.actionBlockInput = false
	animated_sprite.speed_scale = 1.0
	action_timer.stop()
