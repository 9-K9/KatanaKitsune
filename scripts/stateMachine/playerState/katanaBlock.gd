extends PlayerClass

## Guard up. Held, not toggled: releasing Defend lowers the blade and drops back
## to idle.
##
## She can turn, but not walk: stepping off a guard sheathes the blade and drops
## her into a sneak instead, which defends on the same arc for less. Turning
## matters because what the guard is worth depends on which way she faces.
##
## The raise plays once and stops on its last frame; releasing plays the same
## frames backwards. Turning mid-guard swaps to the new direction's clip already
## at its end, so she pivots with the blade up instead of re-raising it.
const RAISE_RATE: float = 2.2
## Planted. Movement is the sneak's job now.
const GUARD_SPEED: float = 0.0

var _lowering: bool = false
var _facing: String = ""


func on_enter():
	pc.blocking = true
	pc.block_opened_at = Time.get_ticks_msec()
	pc.speed = pc.walkSpeed * GUARD_SPEED
	_lowering = false
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
	## Moving out of a guard puts the blade away first. She used to snap from a
	## raised katana straight into a borrowed stealth-walk clip, which read as the
	## sword vanishing mid-step; now she sheathes and comes up in a sneak, which
	## is the same defence by other means — see AnimatedCharacterClass.take_damage,
	## where a low stance guards on the same arc without a blade.
	##
	## Only once the blade is actually up. Tapping Defend with a direction still
	## held would otherwise sheathe on the first frame, so the guard never
	## appeared at all — she just swapped one walk for another.
	if _raised() and pc.InputHandler() != Vector2.ZERO:
		## With nothing left in the sneak meter there is no low stance to go to,
		## so she simply walks. Sending her to stealthWalk regardless would have
		## it eject her again on its first frame.
		pc.sheathe_into = "stealthWalk" if pc.can_sneak() else "walk"
		change_state("katanaSeath")
		return
	if pc.facing_dir != _facing:
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


## True once the raise has played out — the clip stops of its own accord, and
## _hold_guard pauses on the last frame, so "not playing" means "guard up".
func _raised() -> bool:
	return not animated_sprite.is_playing()


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
