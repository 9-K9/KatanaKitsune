extends AnimatedCharacterClass

@onready var timerTimeOut : bool = false
@onready var actionBlockInput : bool = false
@export var contact_damage: float = 10.0

## What the blade is currently over. Resolved once — the attack code used to
## re-look this up by string path on every swing.
@onready var action_area: Area2D = $CollisionChecker/RayCast2D/ActionArea

## Things a katana swing is allowed to damage. Ordinary body contact is not a
## hit, so this is only ever consulted on an attack's hit frame.
const HITTABLE_GROUPS: PackedStringArray = ["enemy", "breakable"]

func _ready() -> void:
	health = max_health
	## Repaint into the chosen aspect. Only the sheets behind each frame change,
	## so every animation, region and timing is untouched.
	var sprite := get_node_or_null("AnimationManager/AnimatedSprite2D")
	if sprite != null:
		PowerState.apply_to(sprite)
	var hitbox = $CollisionChecker/PlayerHitBox
	hitbox.body_entered.connect(_on_player_hit_box_body_entered)


## Everything inside the blade right now that can take a hit.
##
## The single answer to "what am I aiming at". Targeting used to be resolved
## two different ways — a cached enemyBody kept in sync by Area2D signals, and
## a separate live overlap query inside playerAttack — which could disagree,
## and the cache only ever held one body.
func blade_targets() -> Array[Node2D]:
	var found: Array[Node2D] = []
	if not is_instance_valid(action_area):
		return found
	for body in action_area.get_overlapping_bodies():
		if not is_instance_valid(body) or not body.has_method("take_damage"):
			continue
		for group in HITTABLE_GROUPS:
			if body.is_in_group(group):
				found.append(body)
				break
	return found


## The monster a non-attack interaction applies to: the nearest one in the
## blade. Breakables are skipped — only monsters have anything to say.
func current_target() -> Node2D:
	var best: Node2D = null
	var best_distance: float = INF
	for body in blade_targets():
		if not body.is_in_group("enemy"):
			continue
		var distance: float = global_position.distance_squared_to(body.global_position)
		if distance < best_distance:
			best_distance = distance
			best = body
	return best

func _on_death() -> void:
	$FiniteStateMachine.change_state("death")
		
func InputHandler():
	##movement based on players direciton from input
	direction = Input.get_vector("Left", "Right", "Up", "Down")
	direction = direction.normalized()
	return round(direction)

func _physics_process(_delta):
	update_buffs()
	## Unconditional: the running states call drain_stamina, which resets the rest
	## timer, so spending and recovering cannot both apply in the same frame.
	recover_stamina(_delta)
	recover_sneak(_delta)
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

func _on_action_timer_timeout():
	timerTimeOut = true

func _on_player_hit_box_body_entered(body):
	## Deliberately does nothing now. Monsters damage Akane from the hit frame of
	## their attack animation (EnemyBase.strike), which is telegraphed and can be
	## read and dodged. Contact damage predates that AI and meant simply brushing
	## past a monster — or walking into one still taunting — cost 10 health with
	## no wind-up to react to.
	pass
