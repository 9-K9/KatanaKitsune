extends AI_Class
class_name EnemyBase

## Base class for the roaming monsters.
## Owns the stats, health and hit reactions; the behaviour itself lives in the
## states under scripts/stateMachine/enemyState/, driven by the monster's
## FiniteStateMachine child the same way the player's states are.

@export_group("Stats")
@export var max_health: float = 100.0
@export var move_speed: float = 55.0
@export var attack_damage: float = 12.0

@export_group("Ranges")
## All three are ground distances, not screen distances — see ground_distance_to.
## Starts chasing once the player is this close.
@export var detection_range: float = 420.0
## Stops and swings once the player is this close. Has to clear the player's own
## collision polygon, which is a tile-sized 128x64, or the monster can never get
## near enough to trigger a swing.
@export var attack_range: float = 110.0
## Gives up the chase past this. Kept above detection_range so a player sitting
## right on the edge does not flip the monster between idle and walk every frame.
@export var lose_interest_range: float = 560.0

@export_group("Timing")
## Seconds between swings.
@export var attack_cooldown: float = 0.9
## Minimum seconds spent staggered, so fast katana hits cannot stun-lock forever.
@export var hurt_lock: float = 0.3

## The map is drawn 2:1, so a step down the screen covers half the ground a step
## sideways does. Same convention as the player's movement code.
const ISO_Y_SCALE: float = 0.5
const HIT_FLASH: Color = Color(1.0, 0.35, 0.35, 1.0)

var health: float = 0.0
var is_dead: bool = false

@onready var health_bar: ProgressBar = get_node_or_null("HealthBar")
@onready var state_machine: FiniteStateMachine = get_node_or_null("FiniteStateMachine")
## Optional. A monster without one simply never taunts and fights on sight.
@onready var taunt: TauntComponent = get_node_or_null("TauntComponent")

var _player: CharacterBody2D = null
var _flash_tween: Tween = null
var _attack_ready_at_ms: int = 0
var _nav_checked: bool = false
var _nav_usable: bool = false


func _ready() -> void:
	health = max_health
	_refresh_health_bar()


## The player's body. Resolved lazily because the monster is spawned from code
## and may enter the tree before the player does.
func player() -> CharacterBody2D:
	if is_instance_valid(_player):
		return _player
	## The player's hitbox Area2D is in the "player" group too, so take the
	## first body rather than the first node.
	for node in get_tree().get_nodes_in_group("player"):
		if node is CharacterBody2D:
			_player = node
			return _player
	return null


## Distance along the ground rather than across the screen. The map is drawn
## 2:1, so without undoing the squash the same gap measures half as far when it
## is vertical and the monster would happily swing from a screen away.
func ground_distance_to(target_position: Vector2) -> float:
	var delta: Vector2 = target_position - global_position
	delta.y /= ISO_Y_SCALE
	return delta.length()


func distance_to_player() -> float:
	var target := player()
	if target == null:
		return INF
	return ground_distance_to(target.global_position)


## detection_range scaled by how well hidden she is, so sneaking and crouching
## actually shorten the range a monster wakes up at.
func effective_detection() -> float:
	var target := player()
	if target != null and target.has_method("stealth_ratio"):
		return detection_range * target.stealth_ratio()
	return detection_range


## Unit vector pointing at the player on screen, or ZERO when there is none.
## This is the straight line, used for facing and for aiming a swing.
func direction_to_player() -> Vector2:
	var target := player()
	if target == null:
		return Vector2.ZERO
	return (target.global_position - global_position).normalized()


## The direction to actually walk in. Follows a navigated path where the map
## has one, so the monster rounds corners instead of grinding along a wall.
##
## Falls back to the straight line when there is no baked navigation — the
## hand-built maps have none, and this same scene is used in both.
func chase_direction() -> Vector2:
	var target := player()
	if target == null:
		return Vector2.ZERO
	var direct: Vector2 = (target.global_position - global_position).normalized()
	if not _navigation_available():
		return direct

	nav.target_position = target.global_position
	if nav.is_navigation_finished():
		return direct
	var step: Vector2 = nav.get_next_path_position() - global_position
	## Standing almost exactly on the next waypoint makes the normalised
	## direction meaningless; keep walking the straight line for a frame.
	if step.length() < 1.0:
		return direct
	return step.normalized()


## Cached because it only changes when a map is loaded, and the answer is a
## server round-trip.
func _navigation_available() -> bool:
	if _nav_checked:
		return _nav_usable
	_nav_checked = true
	if not is_instance_valid(nav):
		_nav_usable = false
		return false
	var map: RID = nav.get_navigation_map()
	_nav_usable = map.is_valid() and NavigationServer2D.map_get_regions(map).size() > 0
	return _nav_usable


## Points the sprite along `dir`. Facing is taken from the unforeshortened
## vector so the monster looks where the player actually is on screen.
func face(dir: Vector2) -> void:
	if dir == Vector2.ZERO:
		return
	var named: String = directionState(round(dir))
	if named != "":
		facing_dir = named


func move_towards(dir: Vector2, speed: float) -> void:
	velocity = dir * speed
	velocity.y *= ISO_Y_SCALE
	move_and_slide()


func stop() -> void:
	velocity = Vector2.ZERO
	move_and_slide()


## Loops a clip in the current facing. Restarts only when the clip or the
## direction actually changed — calling play() every frame would pin the
## animation to frame 0 forever.
func play_loop(state_name: String) -> void:
	var clip: String = "%s_%s" % [state_name, facing_dir]
	if animated_sprite.animation != clip or not animated_sprite.is_playing():
		animated_sprite.play(clip)


## Plays a one-shot clip from the top. Only call this from a state's on_enter.
func play_once(state_name: String) -> void:
	animated_sprite.play("%s_%s" % [state_name, facing_dir])


func animation_finished() -> bool:
	return not animated_sprite.is_playing()


func attack_off_cooldown() -> bool:
	return Time.get_ticks_msec() >= _attack_ready_at_ms


func start_attack_cooldown() -> void:
	_attack_ready_at_ms = Time.get_ticks_msec() + int(attack_cooldown * 1000.0)


## Lands a claw hit if the player is still inside the swing. `reach` is a
## multiplier on attack_range, so a player backing off mid-swing can still be
## clipped by the follow-through.
func strike(reach: float = 1.35) -> void:
	if is_dead:
		return
	var target := player()
	if target == null:
		return
	if ground_distance_to(target.global_position) > attack_range * reach:
		return
	if target.has_method("take_damage"):
		target.take_damage(attack_damage)
	_strike_breakables(reach)


## Enemy swings may smash props caught in the same attack radius. This query
## runs only on the attack animation's hit frame; walking into a prop cannot
## damage it.
func _strike_breakables(reach: float) -> void:
	var shape := CircleShape2D.new()
	shape.radius = attack_range * reach
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = shape
	query.transform = Transform2D(0.0, global_position)
	query.collision_mask = 2
	query.exclude = [get_rid()]
	query.collide_with_bodies = true
	query.collide_with_areas = false
	for hit in get_world_2d().direct_space_state.intersect_shape(query, 32):
		var body = hit.get("collider")
		if is_instance_valid(body) and body.is_in_group("breakable") and body.has_method("take_damage"):
			body.take_damage(attack_damage)


## Called when the player interacts with this monster — an Action press or the
## start of a swing. Returns true if that provocation started a taunt, so the
## caller knows the monster is now busy talking.
##
## Safe to call every frame; the component latches after the first success.
func provoke() -> bool:
	if is_dead or not is_instance_valid(taunt):
		return false
	if not taunt.provoke():
		return false
	_change_state("taunt")
	return true


## Whether this monster is past its dialogue and free to fight. True for
## monsters that never had a line in the first place.
func taunt_done() -> bool:
	if not is_instance_valid(taunt):
		return true
	return taunt.has_spoken and not taunt.is_speaking


func take_damage(amount: float) -> void:
	if is_dead:
		return
	health = maxf(health - amount, 0.0)
	_refresh_health_bar()
	_flash()
	if health <= 0.0:
		_change_state("death")
		return
	## A hit landed mid-sentence still hurts, but must not knock the monster
	## into `hurt` — that would leave the dialogue running with nothing waiting
	## on it, and the monster would never reach its fighting states.
	if is_instance_valid(taunt) and taunt.is_speaking:
		return
	_change_state("hurt")


## Drops the corpse out of collision immediately so it stops blocking movement
## and the player's ActionArea releases it as a target.
func begin_death() -> void:
	is_dead = true
	velocity = Vector2.ZERO
	set_deferred("collision_layer", 0)
	set_deferred("collision_mask", 0)
	if is_instance_valid(health_bar):
		health_bar.visible = false


## Called by the death state once the animation has played out.
func finish_death() -> void:
	var fade: Tween = create_tween()
	fade.tween_interval(1.0)
	fade.tween_property(animated_sprite, "modulate:a", 0.0, 0.8)
	fade.tween_callback(queue_free)


func _change_state(state_name: String) -> void:
	if is_instance_valid(state_machine):
		state_machine.change_state(state_name)


func _flash() -> void:
	if is_instance_valid(_flash_tween):
		_flash_tween.kill()
	animated_sprite.modulate = HIT_FLASH
	_flash_tween = create_tween()
	_flash_tween.tween_property(animated_sprite, "modulate", Color.WHITE, 0.18)


func _refresh_health_bar() -> void:
	if is_instance_valid(health_bar):
		health_bar.max_value = max_health
		health_bar.value = health
