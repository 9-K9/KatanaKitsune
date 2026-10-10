extends PlayerClass

## The quick standing cut: a tap of Attack with the blade out. Less damage than
## the charged swing, but it is out and back before most things can answer.
##
## Plays katanaSlashMid: this state node has always existed without art of its
## own, and katanaSlashMid is the standing swing. The charged attack releases
## into the same clip, at a slower rate and for a lot more damage.
const RATE: float = 1.4

func on_enter():
	pc.speed = 0.0
	pc.actionBlockInput = true
	beginAttack()
	action_timer.wait_time = play_oneshot("katanaSlashMid", RATE)
	action_timer.start()
	_sync_weapon_tween("katanaSlashMid", RATE)

func on_process(_delta):
	playerAttack(3)

func on_physics_process(_delta):
	if action_timer.is_stopped():
		change_state("katanaIdle")

func on_exit():
	pc.actionBlockInput = false
	animated_sprite.speed_scale = 1.0
	action_timer.stop()
	_reset_weapon_tween()
