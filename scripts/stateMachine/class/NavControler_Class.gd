extends CharacterBody2D
class_name AI_Class

@onready var gameManager = get_node("/root/Main")
@export var speed: int = 16
@export var accel: int = 8
@onready var animated_sprite : AnimatedSprite2D = $AnimatedSprite2D
@onready var nav: NavigationAgent2D = $NavigationAgent2D
@onready var direction : Vector2 = Vector2.ZERO
@onready var facing_dir: String = "southWest"
@onready var player_state: String = "idle"
@onready var run_frame = 1
@onready var animation_state = "%s_%s"%[player_state,facing_dir]

func navigationControler():
	direction = nav.get_next_path_position() - global_position
	direction = direction.normalized()
	var round_dir = round(direction)
	
	match round_dir:
		Vector2(0,1):
			facing_dir = "south"
		Vector2(-1,1):
			facing_dir = "southWest"
		Vector2(-1,0):
			facing_dir = "west"
		Vector2(-1,-1):
			facing_dir = "northWest"
		Vector2(0,-1):
			facing_dir = "north"
		Vector2(1,-1):
			facing_dir = "northEast"
		Vector2(1,0):
			facing_dir = "east"
		Vector2(1,1):
			facing_dir = "southEast"
		_: #Default Return
			pass
			
	if nav.is_navigation_finished():
		run_frame = 1
		player_state = "idle"
		velocity = Vector2.ZERO
	else:
		run_frame = 2
		player_state = "walk"
		velocity = direction * speed 
		if Input.is_action_pressed("Run"):
			run_frame = 3
			var speed_temp = speed * run_frame
			var accel_temp = accel * run_frame
			player_state = "run"
			velocity = direction * speed_temp
	
	animationState()
	move_and_slide()
	
func animationState():
	animation_state = "%s_%s"%[player_state,facing_dir]
	animated_sprite.play(animation_state,run_frame)


