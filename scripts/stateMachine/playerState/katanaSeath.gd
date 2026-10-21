extends PlayerClass

## Putting the blade away. Faster than it was drawn at — three quarters of a
## second of animation with no control is a long time to stand still in a fight.
##
## Where she ends up is set by whoever asked for the sheathe: guarding and then
## walking sheathes *into* a sneak, so the blade goes away before she slips low
## rather than her teleporting between the two stances.
const RATE: float = 1.45

var _left: float = 0.0
var _next: String = ""


func on_enter():
	AudioManager.play_for("sfx_katana_sheathe", pc)
	pc.katana_drawn = false
	pc.speed = 0.0
	## Claimed on the way in rather than on the way out, so a sheathe cut short
	## by a hit or a death cannot leave a stale destination behind for the next
	## one to pick up.
	_next = pc.sheathe_into
	pc.sheathe_into = ""
	_left = play_oneshot("katanaSeath", RATE)


func on_physics_process(delta):
	_left -= delta
	if _left <= 0.0:
		change_state(_next if _next != "" else "idle")


func on_exit():
	animated_sprite.speed_scale = 1.0
