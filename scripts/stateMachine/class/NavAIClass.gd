extends CharacterBody2D
class_name AI_Class

@onready var gameManager = get_node_or_null("/root/Main")
@onready var animated_sprite : AnimatedSprite2D = $AnimatedSprite2D
@onready var nav: NavigationAgent2D = $NavigationAgent2D
@onready var direction : Vector2 = Vector2.ZERO
@onready var facing_dir: String = "southWest"
@onready var self_state: String = "idle"
@onready var animation_state = "%s_%s"%[self_state,facing_dir]


## The inverse of directionState: the unit vector a named facing points along.
## Lives here beside its counterpart because the monsters need it to work out
## what is in front of them, and AI_Class does not inherit the player's copy.
const FACING_VECTORS := {
	"south": Vector2(0, 1), "southWest": Vector2(-1, 1), "west": Vector2(-1, 0),
	"northWest": Vector2(-1, -1), "north": Vector2(0, -1),
	"northEast": Vector2(1, -1), "east": Vector2(1, 0), "southEast": Vector2(1, 1),
}


func stateDirection(str_dir: String) -> Vector2:
	return FACING_VECTORS.get(str_dir, Vector2.ZERO)


func directionState(rnd_dir):
	var string_dir : String
	match rnd_dir:
		Vector2(0,1):
			string_dir = "south"
		Vector2(-1,1):
			string_dir = "southWest"
		Vector2(-1,0):
			string_dir = "west"
		Vector2(-1,-1):
			string_dir = "northWest"
		Vector2(0,-1):
			string_dir = "north"
		Vector2(1,-1):
			string_dir = "northEast"
		Vector2(1,0):
			string_dir = "east"
		Vector2(1,1):
			string_dir = "southEast"
	return string_dir
		
func animationState(fps):
	animation_state = "%s_%s"%[self_state,facing_dir]
	animated_sprite.play(animation_state,fps)


