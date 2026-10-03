extends AI_Class
class_name EnemyBase

## Base class for the roaming monsters.
## Owns the stats, health and hit reactions; the behaviour itself lives in the
## states under scripts/stateMachine/enemyState/, driven by the monster's
## FiniteStateMachine child the same way the player's states are.

## Which rung of the bestiary this monster is, 1 to 6. Drives what it is worth
## and, later, which behaviours it is allowed.
@export var tier: int = 1
## What this tier can do, read once on ready. Looked up rather than duplicated
## onto every monster scene, so retuning a rung is one table edit.
var traits: Dictionary = {}
## True only while a duellist is actually holding its guard up. The tier's
## passive soak applies whenever it is facing a blow; this is the deeper
## reduction for a block it deliberately raised.
var guarding: bool = false
## Latched after the draw animation finishes; a fresh instance resets it.
var blade_drawn: bool = false

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

@export_group("Timing")
## Seconds between swings.
@export var attack_cooldown: float = 0.9
## Minimum seconds spent staggered, so fast katana hits cannot stun-lock forever.
@export var hurt_lock: float = 0.3

## The map is drawn 2:1, so a step down the screen covers half the ground a step
## sideways does. Same convention as the player's movement code.
const ISO_Y_SCALE: float = 0.5

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


func apply_tier(to: int, wave: int = 1) -> void:
	tier = to
	## Duplicated, not referenced. EnemyTier.of returns the shared row out of
	## its table, so trimming it in place would strip the skill from every
	## monster of that rung for the rest of the run.
	traits = EnemyTier.of(to).duplicate()
	_drop_skills_without_states()
	## Scaled by the rung and then by how deep the run has gone, capped so a
	## long run does not become arithmetic rather than a fight.
	var deep: float = minf(1.0 + float(wave - 1) * 0.06, WAVE_CAP)
	max_health *= traits["health"] * deep
	health = max_health
	attack_damage *= traits["damage"] * deep
	if traits["phases"]:
		## Walls are not cover from this one, and it walks through them.
		set_deferred("collision_mask", 0)


## Takes away any skill this monster has no state node to perform.
##
## The generator picks the art uniformly and rolls the rung separately, so any
## scene can be handed any tier — a shambler can come up tier 6. Only the four
## duellist scenes carry block, draw and charge, and asking for a state that is
## not there logs an error and leaves current_state untouched, so the monster
## retries the same transition every frame: an error flood and a body that
## stands still instead of fighting.
##
## Trimming the traits is better than guarding each call site, because the
## traits are what every behaviour reads. One monster quietly fights a rung
## below its skill ceiling; nothing errors and nothing freezes.
func _drop_skills_without_states() -> void:
	if not is_instance_valid(state_machine):
		return
	if traits.get("duellist", false) and not state_machine.has_node("draw"):
		traits["duellist"] = false
	if traits.get("guards", false) and not state_machine.has_node("block"):
		traits["guards"] = false


## How far the wave scaling can push a monster. Past this the numbers stop
## meaning anything and a fight becomes a stalemate.
const WAVE_CAP: float = 2.5


func _ready() -> void:
	health = max_health
	_refresh_health_bar()


## The player's body. Resolved lazily because the monster is spawned from code
## and may enter the tree before the player does.
func player() -> CharacterBody2D:
	## The nearest living player, re-resolved each time rather than cached.
	##
	## It used to latch onto the first body in the group and keep it forever,
	## which with four players meant every monster on the floor hunted player one
	## and walked straight past the other three.
	var best: CharacterBody2D = null
	var best_distance: float = INF
	for node in get_tree().get_nodes_in_group("player"):
		## Her hitbox Area2D is in the group too; only the body can be chased.
		if not (node is CharacterBody2D):
			continue
		if node.get("is_dead") == true:
			continue
		var distance: float = global_position.distance_squared_to(
				(node as Node2D).global_position)
		if distance < best_distance:
			best_distance = distance
			best = node
	_player = best
	return best


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


## Stone blocks sight. Walls sit on physics layer 1, and the ray runs between
## the two feet positions, which after the y-sort fix are both on the ground —
## so it crosses the same floor the characters walk on.
const WALL_MASK: int = 1
## How long a monster keeps hunting after losing sight of her.
@export var memory_seconds: float = 3.0
## How wide a monster's view is, in degrees. Vision is a cone rather than a
## circle so that getting behind one is worth doing — which is the whole point
## of a stealth system.
@export var vision_arc_degrees: float = 130.0
## Inside this it notices her regardless of which way it is looking. Without it
## she could stand on a monster's toes unseen, which reads as broken rather than
## as stealthy.
@export var aware_radius: float = 95.0

var _last_seen_ms: int = -100000
var _sight_checked_ms: int = -100000
var _sight_cached: bool = false
## Where she was standing when last seen, so a monster can press on to it.
var last_known: Vector2 = Vector2.ZERO


## Can this monster actually see her? Range first because it is cheap, then a
## ray, and the answer is held briefly so a crowd of monsters does not each cast
## every frame.
func sees_player() -> bool:
	var now: int = Time.get_ticks_msec()
	if now - _sight_checked_ms < 120:
		return _sight_cached
	_sight_checked_ms = now
	_sight_cached = _look_for_player()
	if _sight_cached:
		_last_seen_ms = now
		var target := player()
		if target != null:
			last_known = target.global_position
	return _sight_cached


func _look_for_player() -> bool:
	var target := player()
	if target == null or is_dead:
		return false
	## effective_detection already scales with how hidden she is — crouched is
	## 0.3 of the range, katana drawn is 1.5.
	var distance: float = ground_distance_to(target.global_position)
	if distance > effective_detection():
		return false
	## Outside the close-range awareness she has to be in front of it.
	if distance > aware_radius and not _within_arc(target.global_position):
		return false
	var space := get_world_2d().direct_space_state
	var query := PhysicsRayQueryParameters2D.create(
			global_position, target.global_position, WALL_MASK)
	## Without excluding these two the ray stops on whoever cast it. Other
	## monsters are left in deliberately: one standing in a doorway blocks the
	## view through it, which is the same rule the walls follow.
	query.exclude = [get_rid(), target.get_rid()]
	## A phasing monster has no line of sight to break — stone is not cover from
	## something that walks through it.
	if traits.get("phases", false):
		return true
	return space.intersect_ray(query).is_empty()


## Is `point` inside the cone this monster is looking down?
func _within_arc(point: Vector2) -> bool:
	var facing: Vector2 = stateDirection(facing_dir)
	if facing == Vector2.ZERO:
		return true
	## Both vectors get the squash undone, or the cone would be far wider
	## looking up and down the screen than across it.
	var to_target: Vector2 = point - global_position
	to_target.y /= ISO_Y_SCALE
	facing.y /= ISO_Y_SCALE
	if to_target.length_squared() < 1.0:
		return true
	## angle_to is signed, so the magnitude is what matters — a target 90 degrees
	## to the left is as visible as one 90 degrees to the right.
	var half: float = deg_to_rad(vision_arc_degrees) * 0.5
	return absf(to_target.normalized().angle_to(facing.normalized())) <= half


## Seconds since she was last actually seen.
func seconds_since_seen() -> float:
	return float(Time.get_ticks_msec() - _last_seen_ms) / 1000.0


## detection_range scaled by how well hidden she is, so crouching, sneaking and
## drawing the katana each change the range a monster wakes up at.
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
## Close enough to swing. Used by the duellist states to decide whether to
## answer a guard with a strike or close the distance first.
func in_attack_range() -> bool:
	return distance_to_player() <= attack_range


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
func strike(reach: float = 1.35, damage_multiplier: float = 1.0) -> void:
	if is_dead:
		return
	var target := player()
	if target == null:
		return
	if ground_distance_to(target.global_position) > attack_range * reach:
		return
	if target.has_method("take_damage"):
		## Tells her guard where the blow came from.
		target.take_damage(attack_damage * damage_multiplier, global_position)
	_strike_breakables(reach, damage_multiplier)


## Enemy swings may smash props caught in the same attack radius. This query
## runs only on the attack animation's hit frame; walking into a prop cannot
## damage it.
func _strike_breakables(reach: float, damage_multiplier: float = 1.0) -> void:
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
			body.take_damage(attack_damage * damage_multiplier, global_position)


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




## Who struck the killing blow, so the score goes to the right player.
var _last_hit_by: int = -1


func take_damage(amount: float, from: Vector2 = Vector2.INF,
		_guardable: bool = true) -> void:
	## Credited by proximity to the source of the blow, which is the player's
	## own position for a swing and the arc's for a thrown one.
	if from != Vector2.INF:
		var striker := Roster.nearest_to(get_tree(), from)
		if striker != null and "slot" in striker:
			_last_hit_by = striker.slot
	if is_dead:
		return
	## Where the blade came through, so the spray throws the right way and the
	## arc points along the blow rather than at a fixed angle.
	var origin: Vector2 = from
	if origin == Vector2.INF:
		var target := player()
		origin = target.global_position if target != null else global_position
	HitEffects.blood(get_parent(), global_position + Vector2(0, -40), origin, amount)
	HitEffects.slash(get_parent(), global_position + Vector2(0, -40),
			global_position - origin, 1.0 + amount / 120.0)
	## A warden meets blows it is facing. A flat frontal soak rather than the
	## player's arc — a monster parrying that precisely would be unreadable in a
	## crowd.
	if traits.get("guards", false) and from != Vector2.INF:
		var facing: Vector2 = stateDirection(facing_dir)
		if facing != Vector2.ZERO:
			var toward: Vector2 = from - global_position
			toward.y /= 0.5
			facing.y /= 0.5
			if absf(toward.normalized().angle_to(facing.normalized())) < deg_to_rad(70.0):
				## A guard it chose to raise stops far more than merely facing
				## the right way does.
				amount *= 0.15 if guarding else 0.45
	## The boss never learned to watch its own back. This is the only way in.
	var weak: float = traits.get("stealth_weak", 1.0)
	if weak > 1.0 and _last_hit_by >= 0:
		var striker := _player_in_slot(_last_hit_by)
		if striker != null and (striker.get("stealthed") == true
				or striker.get("crouched") == true):
			amount *= weak
	health = maxf(health - amount, 0.0)
	_refresh_health_bar()
	## The killing blow gets the longer hold, so a one-shot does not look like
	## the monster was never hit at all.
	_flash(health <= 0.0)
	if health <= 0.0:
		_change_state("death")
		return
	_change_state("hurt")


## Drops the corpse out of collision immediately so it stops blocking movement
## and the player's ActionArea releases it as a target.
func begin_death() -> void:
	is_dead = true
	## Scored here rather than in the death state, so it lands the instant the
	## monster is out of the fight — the streak window has to open now, not when
	## the collapse animation finishes.
	if _last_hit_by >= 0:
		var killer := _player_in_slot(_last_hit_by)
		var unseen: bool = killer != null and (killer.get("stealthed") == true
				or killer.get("crouched") == true)
		Score.killed(_last_hit_by, tier, unseen)
	velocity = Vector2.ZERO
	set_deferred("collision_layer", 0)
	set_deferred("collision_mask", 0)
	if is_instance_valid(health_bar):
		health_bar.visible = false


## The body in a given slot, or null.
func _player_in_slot(slot: int) -> Node:
	for body in Roster.bodies(get_tree()):
		if body.get("slot") == slot:
			return body
	return null


## Called by the death state once the animation has played out.
func finish_death() -> void:
	var fade: Tween = create_tween()
	fade.tween_interval(1.0)
	fade.tween_property(animated_sprite, "modulate:a", 0.0, 0.8)
	fade.tween_callback(queue_free)


func _change_state(state_name: String) -> void:
	if is_instance_valid(state_machine):
		state_machine.change_state(state_name)


## Reaction to being hit: a blown-out flash, a recoil away from the blade, and a
## squash that springs back.
##
## A tint fading over 0.18s was all there used to be, which on a dark sprite in a
## dark dungeon is close to invisible — and a killing blow swapped straight to
## the death clip in the same frame, so a one-shot backstab read as the monster
## blinking out of existence. The recoil moves the sprite, not the body, so it
## cannot shove a monster through a wall.
const RECOIL_PIXELS: float = 22.0
const RECOIL_TIME: float = 0.13
## Well above white, so a hit reads even against lantern light.
const HIT_BLOWOUT: Color = Color(2.6, 1.5, 1.5, 1.0)


func _flash(fatal: bool = false) -> void:
	if is_instance_valid(_flash_tween):
		_flash_tween.kill()
	if not is_instance_valid(animated_sprite):
		return

	var rest_offset: Vector2 = animated_sprite.offset
	var rest_scale: Vector2 = animated_sprite.scale

	## Away from whoever is swinging, with the isometric squash applied so the
	## kick travels along the floor rather than straight across the screen.
	var away := Vector2(0.0, -1.0)
	var target := player()
	if target != null:
		var d: Vector2 = global_position - target.global_position
		if d.length_squared() > 0.001:
			away = d.normalized()
	away.y *= 0.5

	animated_sprite.modulate = HIT_BLOWOUT
	animated_sprite.offset = rest_offset + away * RECOIL_PIXELS
	animated_sprite.scale = rest_scale * Vector2(1.18, 0.86)

	_flash_tween = create_tween()
	_flash_tween.set_parallel(true)
	## A kill holds the white longer; the death clip takes over from there, and
	## the hold is what sells the moment.
	_flash_tween.tween_property(animated_sprite, "modulate", Color.WHITE,
			0.34 if fatal else 0.2)
	_flash_tween.tween_property(animated_sprite, "offset", rest_offset, RECOIL_TIME) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_flash_tween.tween_property(animated_sprite, "scale", rest_scale, RECOIL_TIME) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _refresh_health_bar() -> void:
	if is_instance_valid(health_bar):
		health_bar.max_value = max_health
		health_bar.value = health
