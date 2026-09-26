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

## True once the current swing has already dealt its damage.
var _swing_connected: bool = false

##Handles Input and returns a state string
func stateAnimation(state_to_animate,fps):
	fps = null #fps can be set in code or in the editor
	var string_animation : String
	string_animation = "%s_%s"%[state_to_animate,pc.facing_dir]
	animated_sprite.play(string_animation) 
			
## Arms the next swing. Call from an attack state's on_enter.
func beginAttack():
	_swing_connected = false

##attack enemy body when the swing reaches its hit frame
func playerAttack(hit_frame: int = 3):
	## on_process runs many times per animation frame, so without this guard a
	## single swing landed once per rendered frame the clip sat on hit_frame.
	if _swing_connected or animated_sprite.frame < hit_frame:
		return
	_swing_connected = true
	## Targets come from the live blade overlap on the actual hit frame, so a
	## monster that has already backed off is not hit and every breakable in
	## range responds. Ordinary body contact is still harmless.
	##
	## Asked of the character rather than resolved here: a state should not know
	## where the player keeps its hitboxes, and this used to re-walk a hardcoded
	## node path on every swing.
	if not pc.has_method("blade_targets"):
		return
	for body in pc.blade_targets():
		body.take_damage(pc.damage)

##Math Functions
func round_to_dec(num, digit):
	return round(num * pow(10.0, digit)) / pow(10.0, digit)
	
