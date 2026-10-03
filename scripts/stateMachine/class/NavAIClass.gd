extends CharacterBody2D
class_name AI_Class

@onready var gameManager = get_node_or_null("/root/Main")
@onready var animated_sprite : AnimatedSprite2D = $AnimatedSprite2D
@onready var nav: NavigationAgent2D = $NavigationAgent2D
@onready var direction : Vector2 = Vector2.ZERO
@onready var facing_dir: String = "southWest"
@onready var self_state: String = "idle"
@onready var animation_state = "%s_%s"%[self_state,facing_dir]


## Facing lookups live in IsoFacing so the monsters and the player share one
## table. Kept as methods rather than replaced at the call sites because Radar
## finds anything that can report a facing with has_method("stateDirection").

## The unit vector a named facing points along, or ZERO if it is not one of the
## eight. The monsters need it to work out what is in front of them.
func stateDirection(str_dir: String) -> Vector2:
	return IsoFacing.vector_of(str_dir)


## The facing name for a rounded direction vector, or "" if it is not one of
## the eight.
func directionState(rnd_dir):
	return IsoFacing.name_of(rnd_dir)
		
func animationState(fps):
	animation_state = "%s_%s"%[self_state,facing_dir]
	animated_sprite.play(animation_state,fps)


