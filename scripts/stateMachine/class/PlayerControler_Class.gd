extends CharacterBody2D
class_name PC_Class

@onready var gameManager = get_node("/root/Main")
@onready var animated_sprite : AnimatedSprite2D = $AnimatedSprite2D
@onready var nav: NavigationAgent2D = $NavigationAgent2D
@onready var direction : Vector2 = Vector2.ZERO
@onready var round_dir = round(direction)
@onready var facing_dir: String = "southWest"
@onready var player_state: String = "idle"
@onready var action_timer : Timer = $ActionTimer
@onready var animation_state = "%s_%s"%[player_state,facing_dir]
@onready var rayCast2D : RayCast2D = $RayCast2D 
@onready var actionArea : Area2D = $RayCast2D/ActionArea
@onready var debugRayCastCollision : Line2D = $RayCast2D/ActionArea/Line2D
@onready var debugCircleCastCollision : Line2D = $RayCast2D/ActionArea/CollisionShape2D/Circle
@onready var rayCastCollision : CollisionShape2D = $RayCast2D/ActionArea/CollisionShape2D
@onready var enemyBody : CharacterBody2D
@export var walkSpeed : float = 5000.00
@export var runSpeed : float = 10000.00
@export var damage : float = 0.25 #frame rate multiplies by 4

#playerControler
func playerControler(spd,fps,dt):
	#only runs playerControler during gameplay
	if gameManager.getState() == "game_play":
		if directionState(round_dir):
			facing_dir = directionState(round_dir)
		animationState(animated_sprite,actionState(),facing_dir,fps)
		#player movement
		velocity = (direction * spd) * dt
		velocity.y = velocity.y / 2
		move_and_slide()
		#calls attack function if in attack state
		if player_state == "attack":
			playerAttack()

#Helper Functions
#sets the action state for the player
func actionState():	
	#movement based on players direciton from input
	direction = Input.get_vector("Left", "Right", "Up", "Down")	
	direction = direction.normalized()
	round_dir = round(direction)
	if round_dir != Vector2.ZERO:	
		setRayCast2D(round_dir)
	if action_timer.is_stopped():
		if direction == Vector2.ZERO:
			player_state = "idle"
		elif direction != Vector2.ZERO:
			player_state = "walk"
			if Input.is_action_pressed("Run"):
				player_state = "run"
	#attacking state sets of an action timer		
	if Input.is_action_just_pressed("Attack"):
		action_timer.start()
		player_state = "attack"
	return player_state	

#attack enemy body when timer is nearly finished
func playerAttack():
	if is_instance_valid(enemyBody):
		#calculate attack damage out of 8 (0 to 7) on frame 3 (halfway)
		if animated_sprite.frame == 3:
			enemyBody.take_damage(damage)
			return
			
#round float num to decimal place digit			
func round_to_dec(num, digit):
	return round(num * pow(10.0, digit)) / pow(10.0, digit)
	
#sets the animated sprite to play state and direcion	
func animationState(animatedSprite2D,state,string_dir,frameRate):
	var string_animation = "%s_%s"%[state,string_dir]
	animatedSprite2D.play(string_animation,frameRate)	
		
#gets the rounded direction vector2 and returns a direction string state	
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

#set raycast to direction of player to check interaction events
func setRayCast2D(rnd_dir):
		rayCast2D.target_position = rnd_dir * Vector2(32,32)
		debugRayCastCollision.set_point_position(0, Vector2.ZERO)
		debugRayCastCollision.set_point_position(1, rayCast2D.target_position)
		rayCastCollision.position = rayCast2D.target_position

		
	
	


