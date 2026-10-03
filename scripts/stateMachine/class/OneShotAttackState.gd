class_name OneShotAttackState
extends PlayerClass

## A single committed swing or kick: root her, play one clip, land the hit on
## its hit frame, then hand back to a resting state.
##
## Five states were twenty-six identical lines apiece, differing only in the
## clip, the fps argument, how long they lock input for and which idle they
## return to. Subclasses now set those four in _init and inherit the rest.
##
## Not used by katanaSlashStand or katanaChargeAttack: those derive their
## duration from the art with play_oneshot() rather than carrying a number, and
## the charged one has a wind-up and a release to sequence.

## Clip name without the facing suffix — stateAnimation appends that.
var clip: String = ""
## Passed through to stateAnimation. It is discarded there today (the function
## nulls it on its first line), but the five states disagreed about it — 8 or
## 12 — so the values are kept rather than quietly collapsed, in case that
## function is ever made to honour them.
var fps: int = 8
## Seconds of input lock. Deliberately a number rather than clip_length(): for
## midKick and katanaSlashCrouched it already equals the art exactly, and for
## the other three it runs 0.08s long, which is a balance decision rather than
## something to silently change during a refactor.
var duration: float = 1.0
## Where to go when the timer runs out — "idle" bare-handed, "katanaIdle" with
## the blade drawn.
var exit_state: String = "idle"


func on_enter() -> void:
	pc.speed = 0.0
	pc.actionBlockInput = true
	pc.timerTimeOut = false
	action_timer.wait_time = duration
	action_timer.start()
	beginAttack()


func on_process(_delta: float) -> void:
	stateAnimation(clip, fps)
	playerAttack()


func on_physics_process(_delta: float) -> void:
	if action_timer.is_stopped():
		pc.timerTimeOut = true
		change_state(exit_state)


func on_exit() -> void:
	pc.actionBlockInput = false
	pc.timerTimeOut = true
	action_timer.stop()
