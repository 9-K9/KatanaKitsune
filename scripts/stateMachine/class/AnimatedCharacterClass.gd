class_name AnimatedCharacterClass
extends CharacterBody2D

##Movement Variables
@onready var direction: Vector2 = Vector2.ZERO
@onready var facing_dir: String = "southWest"
@export var ray_w : int
@export var ray_h : int
var speed : float = 0.0
@export var walkSpeed : float = 5000.00
@export var runSpeed : float = 10000.00
@export var damage : float = 0.25 ##frame rate multiplies by 4
##Ray Casting 
@export_node_path("AnimatedSprite2D") var _animatedSprite2D: NodePath = "../../AnimatedSprite2D"
@export_node_path("Timer") var _actionTimer: NodePath = "../../ActionTimer"
@export_node_path("RayCast2D") var _rayCast2D: NodePath = "RayCast2D"
@export_node_path("Line2D") var _debugRayCastCollision: NodePath = "RayCast2D/ActionArea/Line2D"
@export_node_path("Line2D") var _debugCircleCastCollision: NodePath = "RayCast2D/ActionArea/CollisionShape2D/Circle"
@export_node_path("CollisionShape2D") var _rayCastCollision: NodePath = "RayCast2D/ActionArea/CollisionShape2D"
@onready var rayCast2D : RayCast2D = get_node(_rayCast2D)
@onready var debugRayCastCollision : Line2D = get_node(_debugRayCastCollision)
@onready var debugCircleCastCollision : Line2D = get_node(_debugCircleCastCollision)
@onready var rayCastCollision : CollisionShape2D = get_node(_rayCastCollision)
@onready var myAnimatedSprite2D : AnimatedSprite2D = get_node(_animatedSprite2D)
@onready var myTimer : Timer = get_node(_actionTimer)
			
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
	
func stateDirection(str_dir):
	var vector_dir : Vector2
	match str_dir:
		"south":
			vector_dir = Vector2(0,1)
		"southWest":
			vector_dir = Vector2(-1,1)
		"west":
			vector_dir = Vector2(-1,0)
		"northWest":
			vector_dir = Vector2(-1,-1)
		"north":
			vector_dir = Vector2(0,-1)
		"northEast":
			vector_dir = Vector2(1,-1)
		"east":
			vector_dir = Vector2(1,0)
		"southEast":
			vector_dir = Vector2(1,1)
	return vector_dir
	
func updateRayCast2D(str_dir):

	setRayCast2D(stateDirection(str_dir)) 

##set raycast to direction of player to check interaction events
func setRayCast2D(rnd_dir):
		if directionState(rnd_dir) == "south" or directionState(rnd_dir) == "north":
			rayCast2D.target_position = rnd_dir * Vector2(ray_w,ray_w)
		else:
			rayCast2D.target_position = rnd_dir * Vector2(ray_w,ray_h)
		debugRayCastCollision.set_point_position(0, Vector2.ZERO)
		debugRayCastCollision.set_point_position(1, rayCast2D.target_position)
		rayCastCollision.position = rayCast2D.target_position
		facing_dir = directionState(rnd_dir)
