extends CharacterBody2D
class_name PC_Class

@onready var gameManager = get_node("/root/Main")
@onready var animated_sprite : AnimatedSprite2D = $AnimatedSprite2D
@onready var nav: NavigationAgent2D = $NavigationAgent2D
@onready var direction : Vector2 = Vector2.ZERO
@onready var round_dir = round(direction)
@onready var facing_dir: String = "southWest"
@onready var player_state: String = "idle"
@onready var animation_state = "%s_%s"%[player_state,facing_dir]

#controls the player in game_play
func playerControler(spd,fps,dt):
	if gameManager.getState() == "game_play":
		if directionState(round_dir):
			facing_dir = directionState(round_dir)
		animationState(animated_sprite,actionState(),facing_dir,fps)
		#player movement
		velocity = (direction * spd) * dt
		velocity.y = velocity.y / 2
		move_and_slide()

#Helper Functions
#sets the action state for the player
func actionState():	
	direction = Input.get_vector("Left", "Right", "Up", "Down")	
	direction = direction.normalized()
	round_dir = round(direction)	
	if direction == Vector2.ZERO:
		player_state = "idle"
	else:
		player_state = "walk"
		if Input.is_action_pressed("Run"):
			player_state = "run"
	
	#State Machine Needed to Fix This
	if Input.is_action_pressed("Attack"):
		player_state = "attack"
		
	return player_state	

#sets the animated sprite to play state and direcion	
func animationState(animatedSprite2D,state,string_dir,frameRate):
	var string_animation = "%s_%s"%[state,string_dir]
	print(string_animation)
	animatedSprite2D.play(string_animation,frameRate)	
		
#gets the rounded direction vector2 and returns a direction string state	
func directionState(round_dir):
	var string_dir : String
	match round_dir:
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
