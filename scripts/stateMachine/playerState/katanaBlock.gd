extends PlayerClass

## Guard up. Held, not toggled: releasing Defend lowers the blade and drops back
## to idle.
##
## She can still move, slowly, and still turn. A guard you cannot walk behind is
## a trap rather than a defence — and since what the guard is worth depends on
## which way she faces, being unable to turn made the direction meaningless.
##
## The raise plays once and stops on its last frame; releasing plays the same
## frames backwards. Turning mid-guard swaps to the new direction's clip already
## at its end, so she pivots with the blade up instead of re-raising it.
const RAISE_RATE: float = 2.2
## A fraction of a walk. Enough to give ground or hold a doorway, not enough to
## carry a guard around as free protection.
const GUARD_SPEED: float = 0.42

var _lowering: bool = false
var _facing: String = ""
var _walking: bool = false


func on_enter():
	pc.blocking = true
	pc.block_opened_at = Time.get_ticks_msec()
	pc.speed = pc.walkSpeed * GUARD_SPEED
	_lowering = false
	_walking = false
	_facing = pc.facing_dir
	## Played once here rather than every frame. Calling play() on a finished
	## non-looping clip restarts it, which is half of why the guard cycled; the
	## other half was seven of the eight clips being marked as looping.
	animated_sprite.speed_scale = RAISE_RATE
	animated_sprite.play(_clip())


func on_process(_delta):
	if _lowering:
		if not animated_sprite.is_playing():
			change_state("katanaIdle")
		return

	if not Input.is_action_pressed("Defend"):
		_lower()
		return
	## There is no art for walking with the guard up, so moving borrows the
	## stealth walk — a low, careful step, which is what carrying a raised blade
	## should look like anyway. Standing still returns to the guard.
	var moving: bool = pc.InputHandler() != Vector2.ZERO
	if moving != _walking or (moving and pc.facing_dir != _facing):
		_walking = moving
		_facing = pc.facing_dir
		if moving:
			animated_sprite.speed_scale = 1.0
			animated_sprite.play("stealthWalk_%s" % pc.facing_dir)
		else:
			_hold_guard()
	elif pc.facing_dir != _facing:
		_turn()
	if Input.is_action_just_pressed("Stealth"):
		change_state("katanaBlockCrouched")
		return
	## A hit taken inside the parry window opens the riposte.
	if pc.parry_ready:
		change_state("katanaCounterSlash")
		return
	if Input.is_action_just_pressed("Jump"):
		change_state("forwardRoll")


## Swaps to the clip for the way she now faces, landing on its final frame so
## the guard stays up through the turn rather than dropping and re-raising.
func _turn() -> void:
	_facing = pc.facing_dir
	_hold_guard()


## Shows the guard for the way she now faces, already at its final frame, so she
## pivots or stops walking with the blade up rather than re-raising it.
func _hold_guard() -> void:
	var clip := _clip()
	animated_sprite.play(clip)
	var frames: SpriteFrames = animated_sprite.sprite_frames
	if frames != null and frames.has_animation(clip):
		animated_sprite.frame = frames.get_frame_count(clip) - 1
		animated_sprite.pause()


## Drops the guard immediately, then runs the raise backwards. The blade stops
## protecting the moment the button comes up, so the lowering frames cannot be
## used as free cover.
func _lower() -> void:
	_lowering = true
	pc.blocking = false
	pc.speed = 0.0
	animated_sprite.play_backwards(_clip())


func _clip() -> String:
	return "katanaBlock_%s" % pc.facing_dir


func on_exit():
	pc.blocking = false
	animated_sprite.speed_scale = 1.0
