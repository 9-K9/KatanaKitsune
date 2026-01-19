extends AnimatedCharacterClass

@onready var gameManager = $"."


@onready var enemyBody : CharacterBody2D = null
@onready var timerTimeOut : bool = false
@onready var actionBlockInput : bool = false
@export var contact_damage: float = 10.0

func _ready() -> void:
	health = max_health
	var hitbox = $CollisionChecker/PlayerHitBox
	hitbox.body_entered.connect(_on_player_hit_box_body_entered)

func _on_death() -> void:
	$FiniteStateMachine.change_state("death")
		
func InputHandler():	
	##movement based on players direciton from input
	direction = Input.get_vector("Left", "Right", "Up", "Down")	
	direction = direction.normalized()
	return round(direction)
		
func _physics_process(delta):
	if InputHandler() and not(actionBlockInput):
		facing_dir = directionState(InputHandler())
		updateRayCast2D(facing_dir)
		velocity = ((InputHandler() * speed) * delta)
		velocity.y = velocity.y / 2
	else:
		velocity = Vector2.ZERO
	move_and_slide()

func _on_action_area_body_entered(body):
	if body.is_in_group("enemy"):
		enemyBody = body


func _on_action_timer_timeout():
	timerTimeOut = true

func _on_player_hit_box_body_entered(body):
	if body.is_in_group("enemy"):
		take_damage(contact_damage)
