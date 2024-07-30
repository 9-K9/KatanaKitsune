class_name PlayerClass
extends StateMachineState

## Base class for all character states.
## Contains a reference to character variables and helper functions.

## Node path to the character.
@export_node_path("CharacterBody2D") var _CharacterBody2D: NodePath = "../.."
@export_node_path("AnimatedSprite2D") var _animatedsprite2D: NodePath = "../../AnimatedSprite2D"
@export_node_path("Timer") var _action_timer: NodePath = "../../ActionTimer"

## Reference to the character node.
@onready var pc: CharacterBody2D = get_node(_CharacterBody2D)
@onready var animated_sprite : AnimatedSprite2D = get_node(_animatedsprite2D)
@onready var action_timer : Timer = get_node(_action_timer)
	
##Handles Input and returns a state string
func stateAnimation(state_to_animate,fps):
	var string_animation : String
	string_animation = "%s_%s"%[state_to_animate,pc.facing_dir]
	animated_sprite.play(string_animation,fps)
			
##attack enemy body when timer is nearly finished
func playerAttack():
	if is_instance_valid(pc.enemyBody):
		##calculate attack damage out of 8 (0 to 7) on frame 3 (halfway)
		if animated_sprite.frame == 3:
			pc.enemyBody.take_damage(pc.damage)
			return	
					
##Math Functions		
func round_to_dec(num, digit):
	return round(num * pow(10.0, digit)) / pow(10.0, digit)
	
