extends PlayerClass

## Guard up. Held, not toggled: releasing Defend lowers the blade and drops back
## to idle.
##
## The raise plays once and stops on its last frame rather than looping — a
## guard that keeps re-raising itself reads as a twitch rather than a stance.
## Releasing plays the same frames backwards, so the blade comes down the way it
## went up instead of snapping.
##
## What the guard is worth depends on where the blow comes from; see
## AnimatedCharacterClass._guarded. Meeting one head-on stops it outright,
## catching one on the flank blunts it, and nothing stops a blade in the back.
const RAISE_RATE: float = 2.2

var _lowering: bool = false


func on_enter():
	pc.speed = 0.0
	pc.blocking = true
	pc.actionBlockInput = true
	pc.block_opened_at = Time.get_ticks_msec()
	_lowering = false
	## Played once here rather than every frame in on_process. Calling play() on
	## a finished, non-looping clip restarts it, which is what made the guard
	## cycle instead of holding.
	animated_sprite.speed_scale = RAISE_RATE
	animated_sprite.play(_clip())


func on_process(_delta):
	if _lowering:
		## Nothing to decide while the blade comes down; she is committed.
		if not animated_sprite.is_playing():
			change_state("katanaIdle")
		return

	if not Input.is_action_pressed("Defend"):
		_lower()
		return
	if Input.is_action_just_pressed("Stealth"):
		change_state("katanaBlockCrouched")
		return
	## A hit taken inside the parry window opens the riposte.
	if pc.parry_ready:
		change_state("katanaCounterSlash")
		return
	if Input.is_action_just_pressed("Jump"):
		change_state("forwardRoll")


## Drops the guard immediately, then runs the raise backwards. The blade is no
## longer in the way from the moment the button comes up, so a player cannot
## keep the protection through the lowering frames.
func _lower() -> void:
	_lowering = true
	pc.blocking = false
	animated_sprite.play_backwards(_clip())


func _clip() -> String:
	return "katanaBlock_%s" % pc.facing_dir


func on_exit():
	pc.blocking = false
	pc.actionBlockInput = false
	animated_sprite.speed_scale = 1.0
