extends PlayerClass

## Akane's last state. Plays the collapse once, holds the final frame, then
## hands off to the Game Over screen.

## Beat between the animation ending and the screen appearing, so the death
## reads before the UI covers it.
const GAME_OVER_DELAY: float = 0.9

var _elapsed: float = 0.0
var _handed_off: bool = false


# Called when the state machine enters this state.
func on_enter() -> void:
	_elapsed = 0.0
	_handed_off = false
	pc.speed = 0.0
	pc.actionBlockInput = true
	## Out of the way: a corpse that still blocks movement turns a doorway into
	## a wall, and in a party it can seal a team-mate in.
	pc.collapse()
	## Lowercase, and played once here rather than every frame from on_process:
	## the clips are "death_south" etc, so "Death_south" resolved to nothing,
	## and re-calling play() each frame restarted the collapse forever.
	animated_sprite.play("death_%s" % pc.facing_dir)


# Called every frame when this state is active.
func on_process(delta: float) -> void:
	if _handed_off:
		return
	_elapsed += delta
	if animated_sprite.is_playing() or _elapsed < GAME_OVER_DELAY:
		return
	## Only once nobody is left standing. A fallen player in a party waits to be
	## picked up instead of ending the run — see AnimatedCharacterClass.revive.
	for other in pc.get_tree().get_nodes_in_group("player"):
		if other is CharacterBody2D and "is_dead" in other and not other.is_dead:
			return
	_handed_off = true
	var manager := pc.get_tree().current_scene
	if is_instance_valid(manager) and manager.has_method("setState"):
		manager.setState("game_over")


# Called every physics frame when this state is active.
func on_physics_process(delta: float) -> void:
	pass


# Called when there is an input event while this state is active.
func on_input(event: InputEvent) -> void:
	pass


# Called when the state machine exits this state.
func on_exit() -> void:
	## Hands the controls back. Every other state that blocks input clears it on
	## the way out; death never did, because until revive existed nothing ever
	## left this state. A revived player stood up and could not move.
	pc.actionBlockInput = false
	animated_sprite.speed_scale = 1.0
