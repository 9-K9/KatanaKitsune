extends PlayerClass

## The stealth attack, out of a crouch. Hits for far more than an honest swing —
## the payoff for crossing a room unseen instead of charging it.
const RATE: float = 1.5
const ASSASSINATE_BONUS: float = 4.0

func on_enter():
	## Most of a bar for a guaranteed kill. Creeping is cheap; using what the
	## creeping bought is not.
	pc.spend_sneak(pc.flair_sneak_cost)
	pc.speed = 0.0
	pc.actionBlockInput = true
	attack_damage_multiplier = ASSASSINATE_BONUS
	beginAttack()
	action_timer.wait_time = play_oneshot("flair", RATE)
	action_timer.start()

func on_process(_delta):
	playerAttack(3)

func on_physics_process(_delta):
	if action_timer.is_stopped():
		## Straight back into cover if there is cover left to go back to —
		## the strike itself is free, but it does not refill the meter.
		change_state("stealthIdle" if pc.can_sneak() else "idle")

func on_exit():
	attack_damage_multiplier = 1.0
	pc.actionBlockInput = false
	animated_sprite.speed_scale = 1.0
	action_timer.stop()
