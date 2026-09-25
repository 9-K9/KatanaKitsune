class_name AnimatedCharacterClass
extends CharacterBody2D

##Movement Variables
@onready var direction: Vector2 = Vector2.ZERO
@onready var facing_dir: String = "southWest"
@export var ray_w : int
@export var ray_h : int
var speed : float = 0.0
## Speeds are in pixels/second. Previously these were ~60x larger because the
## movement code multiplied by delta before move_and_slide() applied it again;
## these values reproduce the old 60fps feel exactly (5000/60, 10000/60).
@export var walkSpeed : float = 83.333
@export var runSpeed : float = 166.667
## Damage one katana swing deals. Each swing now lands exactly once (see
## PlayerClass.playerAttack), where it used to fire on every rendered frame the
## clip sat on the hit frame — hence the old 0.25 "frame rate multiplies by 4".
@export var damage : float = 25.0
##Health Variables
@export var max_health: float = 100.0
var health: float = 100.0
var is_invincible: bool = false
## Latched on the killing blow. Without it every later hit on the corpse ran
## _on_death() again and restarted the death animation from the top.
var is_dead: bool = false
@export var invincibility_duration: float = 0.8
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

func take_damage(amount: float) -> void:
	if is_invincible or is_dead:
		return
	health -= amount
	health = max(health, 0)
	if health <= 0:
		is_dead = true
		_on_death()
	else:
		_start_invincibility()

func _start_invincibility() -> void:
	is_invincible = true
	# Visual feedback - flash the sprite
	var tween = create_tween()
	tween.tween_property(myAnimatedSprite2D, "modulate:a", 0.5, 0.1)
	tween.tween_property(myAnimatedSprite2D, "modulate:a", 1.0, 0.1)
	tween.set_loops(4)  # Flash 4 times over ~0.8s
	await get_tree().create_timer(invincibility_duration).timeout
	is_invincible = false

func _on_death() -> void:
	pass  # Override in subclass
