extends CharacterBody2D
class_name PlayerClass

@onready var gameManager = get_node("/root/Main")
@export var speed: float = 2500.0
@export var runSpeed: float = 5000.0
@onready var animated_sprite : AnimatedSprite2D = $AnimatedSprite2D
@onready var nav: NavigationAgent2D = $NavigationAgent2D
@onready var direction : Vector2 = Vector2.ZERO
@onready var facing_dir: String = "southWest"
@onready var player_state: String = "idle"
@onready var run_frame = 1
@onready var animation_state = "%s_%s"%[player_state,facing_dir]

func playerMovement(dt):	
	direction = Input.get_vector("Left", "Right", "Up", "Down")
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
	
			
	if direction == Vector2.ZERO:
		run_frame = 1
		player_state = "idle"
		velocity = Vector2.ZERO
		if Input.is_action_pressed("Attack"):
			player_state = "attack"
			
	else:
		run_frame = 2
		player_state = "walk"
		velocity = (direction * (speed * dt))
		velocity.y = velocity.y/2
		if Input.is_action_pressed("Run"):
			run_frame = 3
			player_state = "run"
			velocity = (direction * (runSpeed * dt))
			velocity.y = velocity.y/2
	
func playerAnimation():
	animation_state = "%s_%s"%[player_state,facing_dir]
	animated_sprite.play(animation_state,run_frame)
	print(animation_state)
	move_and_slide()
