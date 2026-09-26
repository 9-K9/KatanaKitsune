extends AnimatedCharacterClass

@onready var enemyBody : CharacterBody2D = null
@onready var timerTimeOut : bool = false
@onready var actionBlockInput : bool = false
@export var contact_damage: float = 10.0

func _ready() -> void:
	health = max_health
	var hitbox = $CollisionChecker/PlayerHitBox
	hitbox.body_entered.connect(_on_player_hit_box_body_entered)
	## Only body_entered is wired in the scene. Without the matching exit the
	## last enemy walked past stays targeted forever, so katana swings kept
	## landing on a monster that was no longer anywhere near the blade.
	$CollisionChecker/RayCast2D/ActionArea.body_exited.connect(_on_action_area_body_exited)

func _on_death() -> void:
	$FiniteStateMachine.change_state("death")
		
func InputHandler():
	##movement based on players direciton from input
	direction = Input.get_vector("Left", "Right", "Up", "Down")
	direction = direction.normalized()
	return round(direction)

## Interacting with a monster makes it say its piece before it will fight.
## Checked here rather than in the individual states so every way of starting a
## swing routes through the same place — the katana states each read the attack
## inputs themselves, and duplicating this across them would drift.
const PROVOKE_ACTIONS: PackedStringArray = ["Action", "Attack", "Katana"]


func _try_provoke_target() -> void:
	if not is_instance_valid(enemyBody):
		return
	if not enemyBody.has_method("provoke"):
		return
	for action in PROVOKE_ACTIONS:
		if Input.is_action_just_pressed(action):
			enemyBody.provoke()
			return


func _physics_process(_delta):
	update_buffs()
	_try_provoke_target()
	## Sampled once per frame: InputHandler() was previously called three times
	## per physics tick, and the state scripts call it twice more per frame.
	var input_dir: Vector2 = InputHandler()
	if input_dir != Vector2.ZERO and not actionBlockInput:
		facing_dir = directionState(input_dir)
		updateRayCast2D(facing_dir)
		## No delta here: move_and_slide() already integrates velocity over the
		## physics step. Multiplying by delta as well made displacement scale
		## with delta squared, so the character moved twice as fast at 30fps.
		velocity = input_dir * speed
		velocity.y = velocity.y / 2
	else:
		velocity = Vector2.ZERO
	move_and_slide()

func _on_action_area_body_entered(body):
	if body.is_in_group("enemy"):
		enemyBody = body


func _on_action_area_body_exited(body):
	if body == enemyBody:
		enemyBody = null


func _on_action_timer_timeout():
	timerTimeOut = true

func _on_player_hit_box_body_entered(body):
	if body.is_in_group("enemy"):
		take_damage(contact_damage)
